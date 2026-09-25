/// §11.6.4. The crypto envelope, the freshness check, and the two parsers that
/// stand between this app and anything on the Wi-Fi.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_sync/zen_sync.dart';

import '../support/fixtures.dart';

void main() {
  group('§11.6.4 key derivation and sealing', () {
    late String psk;

    setUp(() => psk = newPairingKey());

    test('a pairing key is 32 bytes, base64', () {
      expect(base64Decode(psk), hasLength(32));
    });

    test('two pairings never share a key', () {
      final Set<String> keys = <String>{
        for (int i = 0; i < 200; i++) newPairingKey(),
      };
      expect(keys, hasLength(200));
    });

    test('a sealed message round-trips under the same pairing key', () async {
      final LanCipher sender = await LanCipher.forPairingKey(psk);
      final LanCipher receiver = await LanCipher.forPairingKey(psk);
      final Uint8List sealed = await sender.seal(utf8.encode('hello'));

      expect(utf8.decode((await receiver.openOrNull(sealed))!), 'hello');
    });

    test('the same pairing key derives the same message key', () async {
      // The point of pinning the salt, the info and the output length: two
      // devices that derive differently would fail with no clue why.
      final LanCipher a = await LanCipher.forPairingKey(psk);
      final LanCipher b = await LanCipher.forPairingKey(psk);
      expect(await b.openOrNull(await a.seal(utf8.encode('x'))), isNotNull);
    });

    test('another pairing key does not open it', () async {
      final LanCipher ours = await LanCipher.forPairingKey(psk);
      final LanCipher theirs = await LanCipher.forPairingKey(newPairingKey());

      expect(
        await theirs.openOrNull(await ours.seal(utf8.encode('x'))),
        isNull,
      );
    });

    test('a tampered byte fails the tag rather than decrypting', () async {
      final LanCipher cipher = await LanCipher.forPairingKey(psk);
      final Uint8List sealed = await cipher.seal(utf8.encode('hello'));
      sealed[sealed.length - 1] ^= 0x01;

      expect(await cipher.openOrNull(sealed), isNull);
    });

    test('a tampered nonce fails too', () async {
      final LanCipher cipher = await LanCipher.forPairingKey(psk);
      final Uint8List sealed = await cipher.seal(utf8.encode('hello'));
      sealed[0] ^= 0x01;

      expect(await cipher.openOrNull(sealed), isNull);
    });

    test('a truncated body is refused rather than throwing', () async {
      final LanCipher cipher = await LanCipher.forPairingKey(psk);
      for (final int length in <int>[0, 1, lanNonceBytes, 27]) {
        expect(
          await cipher.openOrNull(Uint8List(length)),
          isNull,
          reason: 'a $length-byte body came off the network',
        );
      }
    });

    /// §11.6.4: "reusing a nonce under one AES-GCM key is a total break …
    /// and it is invisible to any test that does not look for it." This is the
    /// test that looks for it.
    test('every seal under one key uses a fresh nonce', () async {
      final LanCipher cipher = await LanCipher.forPairingKey(psk);
      final Set<String> nonces = <String>{};

      for (int i = 0; i < 500; i++) {
        final Uint8List sealed = await cipher.seal(utf8.encode('same'));
        nonces.add(base64Encode(sealed.sublist(0, lanNonceBytes)));
      }

      expect(nonces, hasLength(500));
    });

    test('identical plaintexts seal to different ciphertexts', () async {
      // The observable consequence of the nonce being fresh: a peer watching
      // the wire cannot tell that this device sent the same thing twice.
      final LanCipher cipher = await LanCipher.forPairingKey(psk);
      final Uint8List a = await cipher.seal(utf8.encode('same'));
      final Uint8List b = await cipher.seal(utf8.encode('same'));

      expect(a, isNot(b));
    });

    test('an unreadable stored key is reported, not treated as wrong', () {
      expect(
        () => LanCipher.forPairingKey('not base64 at all!!'),
        throwsA(isA<LanSyncFailure>()),
      );
    });
  });

  group('§11.6.4 the pairing code', () {
    test('is six digits and keeps its leading zeros', () {
      for (int i = 0; i < 500; i++) {
        expect(newPairingCode(), matches(RegExp(r'^[0-9]{6}$')));
      }
    });

    test('is not a counter', () {
      final Set<String> codes = <String>{
        for (int i = 0; i < 200; i++) newPairingCode(),
      };
      // 200 draws from a million: a counter or a fixed value would collapse.
      expect(codes.length, greaterThan(190));
    });

    test('comparison is length-safe and value-correct', () {
      expect(constantTimeEquals('000123', '000123'), isTrue);
      expect(constantTimeEquals('000123', '000124'), isFalse);
      expect(constantTimeEquals('000123', '00012'), isFalse);
      expect(constantTimeEquals('', ''), isTrue);
    });
  });

  group('§11.6.4 freshness and protocol version', () {
    final FakeClock clock = FakeClock(t0);

    List<int> plaintext({
      required DateTime sentAt,
      int protocolVersion = lanProtocolVersion,
      Object? document = const <String, Object?>{'ok': true},
    }) => utf8.encode(
      jsonEncode(<String, Object?>{
        LanFields.protocolVersion: protocolVersion,
        LanFields.sentAt: sentAt.toIso8601String(),
        LanFields.document: document,
      }),
    );

    setUp(() => clock.set(t0));

    test('a message inside the skew window is accepted', () {
      final LanMessage message = LanMessage.parse(
        plaintext(sentAt: t0.subtract(const Duration(minutes: 4, seconds: 59))),
        clock,
      );
      expect(message.document, <String, Object?>{'ok': true});
    });

    test('a message from the future inside the window is accepted', () {
      expect(
        () => LanMessage.parse(plaintext(sentAt: at(4)), clock),
        returnsNormally,
      );
    });

    test('a stale message is refused with the copy §11.6.4 mandates', () {
      expect(
        () => LanMessage.parse(
          plaintext(
            sentAt: t0.subtract(const Duration(minutes: 5, seconds: 1)),
          ),
          clock,
        ),
        throwsA(
          isA<LanSyncFailure>().having(
            (LanSyncFailure f) => f.message,
            'message',
            "These devices' clocks are more than 5 minutes apart. "
                'Check the date and time on both.',
          ),
        ),
      );
    });

    test('a message from too far in the future is refused the same way', () {
      expect(
        () => LanMessage.parse(plaintext(sentAt: at(6)), clock),
        throwsA(
          isA<LanSyncFailure>().having(
            (LanSyncFailure f) => f.message,
            'message',
            LanSyncFailure.clockSkewMessage,
          ),
        ),
      );
    });

    test('a different protocol version is refused before anything else', () {
      // Checked before `sentAt`, so a v2 message with an unparseable timestamp
      // still reports the version rather than the timestamp.
      expect(
        () =>
            LanMessage.parse(plaintext(sentAt: t0, protocolVersion: 2), clock),
        throwsA(
          isA<LanSyncFailure>().having(
            (LanSyncFailure f) => f.message,
            'message',
            contains('different sync protocols'),
          ),
        ),
      );
    });

    test('a round trip through toBytes carries the document', () {
      final LanMessage sent = LanMessage(
        sentAt: t0,
        document: <String, Object?>{'formatVersion': 1},
      );
      expect(
        LanMessage.parse(sent.toBytes(), clock).document,
        <String, Object?>{'formatVersion': 1},
      );
    });

    test('plaintext that is not JSON, or not an object, is refused', () {
      for (final List<int> body in <List<int>>[
        utf8.encode('not json'),
        utf8.encode('[1, 2, 3]'),
        utf8.encode('"a string"'),
        <int>[0xC3, 0x28],
      ]) {
        expect(
          () => LanMessage.parse(body, clock),
          throwsA(isA<LanSyncFailure>()),
        );
      }
    });

    test('a missing or malformed sentAt is refused', () {
      for (final Object? sentAt in <Object?>[null, 42, 'yesterday', '']) {
        expect(
          () => LanMessage.parse(
            utf8.encode(
              jsonEncode(<String, Object?>{
                LanFields.protocolVersion: lanProtocolVersion,
                LanFields.sentAt: sentAt,
              }),
            ),
            clock,
          ),
          throwsA(isA<LanSyncFailure>()),
        );
      }
    });
  });

  group('§11.6.4 peer identity, which arrives off the network', () {
    test('an ordinary identity parses', () {
      final LanPeerIdentity? identity = LanPeerIdentity.parse(
        replicaId: '0190f3a1-1111-7000-8000-000000000001',
        deviceName: 'Jordan PC',
      );
      expect(identity?.deviceName, 'Jordan PC');
    });

    test('a name is trimmed', () {
      expect(LanPeerIdentity.parseDeviceName('  Pixel  '), 'Pixel');
    });

    test('a leading byte-order mark is whitespace, and trims away', () {
      // Not a refusal: `trim` treats U+FEFF as whitespace, so the name that
      // reaches the device list is already clean. The refusal below is for a
      // mark *inside* the name, which trimming cannot reach and which is the
      // shape that could misrepresent one device as another.
      expect(LanPeerIdentity.parseDeviceName('﻿Pixel'), 'Pixel');
    });

    test('a name that could misrepresent itself is refused', () {
      for (final String name in <String>[
        'PC\u202Ekcatta', // a bidi override reversing what follows
        'PC\u0000',
        'PC\nSecond line',
        'PC​Zero width',
        'PC﻿hidden',
      ]) {
        expect(
          LanPeerIdentity.parseDeviceName(name),
          isNull,
          reason: 'accepted a name carrying a control or format character',
        );
      }
    });

    test('an empty, over-long or non-string name is refused', () {
      expect(LanPeerIdentity.parseDeviceName('   '), isNull);
      expect(LanPeerIdentity.parseDeviceName('n' * 65), isNull);
      expect(LanPeerIdentity.parseDeviceName(42), isNull);
      expect(LanPeerIdentity.parseDeviceName(null), isNull);
    });

    test('a replicaId that is not a plain identifier is refused', () {
      for (final Object? id in <Object?>[
        '',
        'a' * 65,
        'has space',
        '../../etc/passwd',
        "'; DROP TABLE ideas; --",
        42,
        null,
      ]) {
        expect(
          LanPeerIdentity.parse(replicaId: id, deviceName: 'PC'),
          isNull,
          reason: 'accepted $id as a replicaId',
        );
      }
    });
  });

  group('§11.6.4 the QR payload, which is attacker-controlled', () {
    const LanPairingInvitation invitation = LanPairingInvitation(
      host: '192.168.1.20',
      port: 51789,
      code: '004321',
      replicaId: 'replica-desktop',
      deviceName: 'Jordan PC',
    );

    test('round-trips through the payload the desktop renders', () {
      final LanPairingInvitation? parsed = LanPairingInvitation.parse(
        invitation.toPayload(),
      );
      expect(parsed?.host, '192.168.1.20');
      expect(parsed?.port, 51789);
      expect(parsed?.code, '004321');
      expect(parsed?.deviceName, 'Jordan PC');
    });

    test('unknown keys are refused rather than ignored', () {
      expect(
        LanPairingInvitation.parse('${invitation.toPayload()}&extra=1'),
        isNull,
      );
    });

    test('another scheme or version is refused', () {
      expect(LanPairingInvitation.parse('https://example.com/'), isNull);
      expect(
        LanPairingInvitation.parse(
          invitation.toPayload().replaceFirst('zen-pair:v1', 'zen-pair:v2'),
        ),
        isNull,
      );
    });

    test('a host that smuggles a second destination is refused', () {
      for (final String host in <String>[
        'evil.example.com/path',
        'user@evil.example.com',
        '192.168.1.20 evil',
        'a' * 256,
        '',
      ]) {
        expect(
          LanPairingInvitation.parse(
            Uri(
              scheme: 'zen-pair',
              path: 'v1',
              queryParameters: <String, String>{
                'host': host,
                'port': '51789',
                'code': '004321',
                'rid': 'r',
                'dn': 'PC',
              },
            ).toString(),
          ),
          isNull,
          reason: 'accepted the host "$host"',
        );
      }
    });

    test('a bad port or code is refused', () {
      expect(isValidPort(0), isFalse);
      expect(isValidPort(65536), isFalse);
      expect(isValidPort(51789), isTrue);
      expect(isValidPairingCode('12345'), isFalse);
      expect(isValidPairingCode('abcdef'), isFalse);
      expect(isValidPairingCode('000000'), isTrue);
    });

    test('an oversized payload is refused before it is parsed', () {
      expect(LanPairingInvitation.parse('zen-pair:v1?dn=${'a' * 600}'), isNull);
    });
  });
}
