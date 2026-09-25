/// §11.6.4. The desktop's endpoints, against a real loopback server.
///
/// §11.13.1 puts "mDNS discovery across two hosts, Windows Firewall prompts,
/// Wi-Fi drop-outs, real QR scanning" in the hardware column and says "a
/// loopback HTTP server exercises the LAN protocol, crypto and merge exchange
/// without a second device". This is that server: `shelf_io.serve` on
/// `127.0.0.1`, reached with a real HTTP client, so the routing, the body caps
/// and the status codes are exercised rather than described.
///
/// **Every test here is an attacker's request unless it says otherwise.**
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:zen_domain/testing.dart';
import 'package:zen_domain/zen_domain.dart';
import 'package:zen_sync/zen_sync.dart';

import '../support/fixtures.dart';
import '../support/in_memory_repositories.dart';

void main() {
  late FakeClock clock;
  late InMemorySettings settings;
  late LanSyncServer server;
  late List<SnapshotEnvelope> merged;
  late List<String> warnings;
  late SnapshotEnvelope ours;
  late int port;

  Uri url(String path) => Uri.parse('http://127.0.0.1:$port$path');

  setUp(() async {
    clock = FakeClock(t0);
    settings = InMemorySettings();
    merged = <SnapshotEnvelope>[];
    warnings = <String>[];
    ours = SnapshotEnvelope(
      replicaId: 'replica-desktop',
      deviceName: 'Jordan PC',
      generatedAt: t0,
      appVersion: '1.0.0',
      snapshot: snapshot(
        'replica-desktop',
        ideas: <Idea>[idea('idea-desktop', 'Desktop idea')],
      ),
    );

    server = LanSyncServer(
      replicas: FakeReplicaRepository('replica-desktop', 'Jordan PC'),
      settings: settings,
      snapshotSource: () async => ours,
      inboundMerge: (SnapshotEnvelope peer) async => merged.add(peer),
      clock: clock,
      appVersion: '1.0.0',
      log: warnings.add,
    );
    await server.start(port: 0, address: InternetAddress.loopbackIPv4);
    port = server.boundPort!;
  });

  tearDown(() => server.stop());

  /// Pairs a phone the way the phone does, and returns its stored peer record.
  Future<LanPeer> pairPhone({
    String replicaId = 'replica-phone',
    String deviceName = 'Pixel',
  }) async {
    final PairingWindow window = server.openPairingWindow();
    final http.Response response = await http.post(
      url(LanPaths.pair),
      body: jsonEncode(<String, Object?>{
        LanFields.code: window.code,
        LanFields.replicaId: replicaId,
        LanFields.deviceName: deviceName,
        LanFields.protocolVersion: lanProtocolVersion,
      }),
    );
    expect(response.statusCode, 200);
    final Map<String, Object?> body =
        jsonDecode(response.body) as Map<String, Object?>;
    return LanPeer(
      replicaId: body[LanFields.replicaId]! as String,
      deviceName: body[LanFields.deviceName]! as String,
      host: '127.0.0.1',
      port: port,
      psk: body[LanFields.psk]! as String,
    );
  }

  Future<Uint8List> sealedSync(
    LanPeer peer, {
    SnapshotEnvelope? envelope,
    DateTime? sentAt,
    int protocolVersion = lanProtocolVersion,
    // A sentinel rather than null: `null` is itself a document a hostile peer
    // can send, and `?? default` would quietly turn that case into a valid one.
    Object? document = #unset,
  }) async {
    final LanCipher cipher = await LanCipher.forPairingKey(peer.psk);
    final SnapshotEnvelope body =
        envelope ??
        SnapshotEnvelope(
          replicaId: 'replica-phone',
          deviceName: 'Pixel',
          generatedAt: t0,
          appVersion: '1.0.0',
          snapshot: snapshot(
            'replica-phone',
            ideas: <Idea>[idea('idea-phone', 'Phone idea')],
          ),
        );
    return cipher.seal(
      protocolVersion == lanProtocolVersion
          ? LanMessage(
              sentAt: sentAt ?? clock.nowUtc(),
              document: document == #unset
                  ? const SnapshotCodec().toJson(body)
                  : document,
            ).toBytes()
          : utf8.encode(
              jsonEncode(<String, Object?>{
                LanFields.protocolVersion: protocolVersion,
                LanFields.sentAt: (sentAt ?? clock.nowUtc()).toIso8601String(),
                LanFields.document: document == #unset
                    ? const SnapshotCodec().toJson(body)
                    : document,
              }),
            ),
    );
  }

  Future<http.Response> postSync(List<int> body) => http.post(
    url(LanPaths.sync),
    headers: <String, String>{'content-type': 'application/octet-stream'},
    body: body,
  );

  group('§11.6.4 /hello', () {
    test('reports the protocol, identity and version', () async {
      final http.Response response = await http.get(url(LanPaths.hello));
      final Map<String, Object?> body =
          jsonDecode(response.body) as Map<String, Object?>;

      expect(response.statusCode, 200);
      expect(body[LanFields.protocolVersion], lanProtocolVersion);
      expect(body[LanFields.replicaId], 'replica-desktop');
      expect(body[LanFields.deviceName], 'Jordan PC');
      expect(body[LanFields.appVersion], '1.0.0');
    });

    test('answers before anything is paired', () async {
      // "`/hello` is the only unencrypted endpoint" — it is how a manually
      // typed host is confirmed to be a Zen PC before a code is sent.
      expect(
        settings.read().then((Settings s) => s.syncLanPeers),
        completion(isEmpty),
      );
      expect((await http.get(url(LanPaths.hello))).statusCode, 200);
    });

    test('an unknown path is not served', () async {
      expect((await http.get(url('/zen/v1/anything'))).statusCode, 404);
      expect((await http.get(url('/'))).statusCode, 404);
    });
  });

  group('§11.6.4 /pair', () {
    test('pairs, stores identity and key, and closes the window', () async {
      final LanPeer peer = await pairPhone();

      expect(peer.replicaId, 'replica-desktop');
      expect(base64Decode(peer.psk), hasLength(32));

      final List<LanPeer> stored = (await settings.read()).syncLanPeers;
      expect(stored.single.replicaId, 'replica-phone');
      expect(stored.single.deviceName, 'Pixel');
      // "`host` and `port` are the **client's** fields only."
      expect(stored.single.host, '');
      expect(stored.single.port, 0);
      expect(stored.single.psk, peer.psk);

      expect(server.pairingWindow, isNull, reason: 'the code is single-use');
    });

    test('each pairing gets its own key', () async {
      final LanPeer first = await pairPhone(replicaId: 'phone-1');
      final LanPeer second = await pairPhone(replicaId: 'phone-2');

      expect(first.psk, isNot(second.psk));
      final List<LanPeer> stored = (await settings.read()).syncLanPeers;
      expect(stored, hasLength(2));
      expect(stored[0].psk, isNot(stored[1].psk));
    });

    test('re-pairing the same device replaces its record', () async {
      await pairPhone(deviceName: 'Pixel');
      await pairPhone(deviceName: 'Pixel renamed');

      final List<LanPeer> stored = (await settings.read()).syncLanPeers;
      expect(stored, hasLength(1));
      expect(stored.single.deviceName, 'Pixel renamed');
    });

    Future<http.Response> attempt(String code) => http.post(
      url(LanPaths.pair),
      body: jsonEncode(<String, Object?>{
        LanFields.code: code,
        LanFields.replicaId: 'replica-phone',
        LanFields.deviceName: 'Pixel',
        LanFields.protocolVersion: lanProtocolVersion,
      }),
    );

    test('with no window open it is 403', () async {
      expect((await attempt('123456')).statusCode, 403);
    });

    test('an expired window is 403 and stores nothing', () async {
      server.openPairingWindow();
      clock.advance(const Duration(minutes: 5, seconds: 1));

      expect((await attempt('123456')).statusCode, 403);
      expect((await settings.read()).syncLanPeers, isEmpty);
    });

    test('a wrong code is 403 and the fifth closes the window', () async {
      final PairingWindow window = server.openPairingWindow();
      final String wrong = window.code == '000000' ? '111111' : '000000';

      for (int i = 1; i <= LanPairing.maxFailedAttempts; i++) {
        expect((await attempt(wrong)).statusCode, 403, reason: 'attempt $i');
      }
      // §11.6.4: "429 after the fifth failed attempt."
      expect((await attempt(wrong)).statusCode, 429);
      // And the right code no longer works either — the window is closed.
      expect((await attempt(window.code)).statusCode, 429);
      expect((await settings.read()).syncLanPeers, isEmpty);
    });

    test('a correct code after four failures still pairs', () async {
      final PairingWindow window = server.openPairingWindow();
      final String wrong = window.code == '000000' ? '111111' : '000000';

      for (int i = 0; i < 4; i++) {
        await attempt(wrong);
      }
      expect((await attempt(window.code)).statusCode, 200);
    });

    test('opening a second window replaces the first code', () async {
      final PairingWindow first = server.openPairingWindow();
      final PairingWindow second = server.openPairingWindow();

      expect((await attempt(first.code)).statusCode, 403);
      expect((await attempt(second.code)).statusCode, 200);
    });

    test('a different protocol version is refused with 400', () async {
      server.openPairingWindow();
      final http.Response response = await http.post(
        url(LanPaths.pair),
        body: jsonEncode(<String, Object?>{
          LanFields.code: '123456',
          LanFields.replicaId: 'replica-phone',
          LanFields.deviceName: 'Pixel',
          LanFields.protocolVersion: 2,
        }),
      );
      expect(response.statusCode, 400);
      expect(response.body, contains('different sync protocols'));
    });

    test('a malformed body is 400 and does not burn an attempt', () async {
      final PairingWindow window = server.openPairingWindow();
      for (final Object? body in <Object?>['not json', '[]', '"s"', '']) {
        expect(
          (await http.post(url(LanPaths.pair), body: body)).statusCode,
          400,
        );
      }
      expect(window.failures, 0);
      expect((await attempt(window.code)).statusCode, 200);
    });

    test('an identity Zen will not store is refused with 400', () async {
      for (final Map<String, Object?> identity in <Map<String, Object?>>[
        <String, Object?>{'replicaId': 'has space', 'deviceName': 'Pixel'},
        <String, Object?>{'replicaId': 'r', 'deviceName': ''},
        <String, Object?>{'replicaId': 'r', 'deviceName': 'a' * 65},
        <String, Object?>{'replicaId': 'r', 'deviceName': 'Pix\u202Eel'},
        <String, Object?>{'replicaId': 42, 'deviceName': 'Pixel'},
        <String, Object?>{'deviceName': 'Pixel'},
      ]) {
        final PairingWindow window = server.openPairingWindow();
        final http.Response response = await http.post(
          url(LanPaths.pair),
          body: jsonEncode(<String, Object?>{
            LanFields.code: window.code,
            LanFields.protocolVersion: lanProtocolVersion,
            ...identity,
          }),
        );
        expect(response.statusCode, 400, reason: '$identity');
      }
      expect((await settings.read()).syncLanPeers, isEmpty);
    });

    test('a body over 1 KiB is refused with 413, unread', () async {
      server.openPairingWindow();
      final http.Response response = await http.post(
        url(LanPaths.pair),
        body: jsonEncode(<String, Object?>{
          LanFields.code: '123456',
          LanFields.replicaId: 'r',
          LanFields.deviceName: 'a' * 2048,
          LanFields.protocolVersion: lanProtocolVersion,
        }),
      );
      expect(response.statusCode, 413);
    });
  });

  group('§11.6.4 /sync', () {
    test('returns the server snapshot and merges the client one', () async {
      final LanPeer peer = await pairPhone();
      final http.Response response = await postSync(await sealedSync(peer));

      expect(response.statusCode, 200);

      final LanCipher cipher = await LanCipher.forPairingKey(peer.psk);
      final Uint8List plaintext = (await cipher.openOrNull(
        response.bodyBytes,
      ))!;
      final SnapshotEnvelope returned = const SnapshotCodec()
          .fromJson(LanMessage.parse(plaintext, clock).document)
          .unwrap();

      // "encrypted **server's own** §11.6.1 document, as captured when the
      // request arrived" — not a merged one.
      expect(returned.replicaId, 'replica-desktop');
      expect(returned.snapshot, ours.snapshot);

      // And the client's went to the merge entry point, once.
      expect(merged.single.replicaId, 'replica-phone');
      expect(merged.single.snapshot.ideas.single.id, 'idea-phone');
    });

    test('the snapshot returned is captured before the merge', () async {
      // The ordering §11.6.4 requires: if the capture ran after the merge, the
      // response would carry the phone's idea back to the phone.
      final LanPeer peer = await pairPhone();
      final http.Response response = await postSync(await sealedSync(peer));
      final LanCipher cipher = await LanCipher.forPairingKey(peer.psk);
      final SnapshotEnvelope returned = const SnapshotCodec()
          .fromJson(
            LanMessage.parse(
              (await cipher.openOrNull(response.bodyBytes))!,
              clock,
            ).document,
          )
          .unwrap();

      expect(returned.snapshot.ideas.map((Idea i) => i.id), <String>[
        'idea-desktop',
      ]);
    });

    test('an unpaired caller is 401 and merges nothing', () async {
      final LanPeer stranger = LanPeer(
        replicaId: 'replica-stranger',
        deviceName: 'Attacker',
        host: '127.0.0.1',
        port: port,
        psk: newPairingKey(),
      );
      final http.Response response = await postSync(await sealedSync(stranger));

      expect(response.statusCode, 401);
      expect(merged, isEmpty);
    });

    test('another paired device cannot read this one traffic', () async {
      // The reason §11.6.4 requires a per-pairing key: with one shared key this
      // would succeed.
      final LanPeer first = await pairPhone(replicaId: 'phone-1');
      final LanPeer second = await pairPhone(replicaId: 'phone-2');

      final http.Response response = await postSync(await sealedSync(first));
      final LanCipher eavesdropper = await LanCipher.forPairingKey(second.psk);

      expect(response.statusCode, 200);
      expect(await eavesdropper.openOrNull(response.bodyBytes), isNull);
    });

    test('the right key is found whichever peer sends', () async {
      await pairPhone(replicaId: 'phone-1');
      await pairPhone(replicaId: 'phone-2');
      final LanPeer third = await pairPhone(replicaId: 'phone-3');

      // Third in the list: trial decryption has to reach past two wrong keys.
      expect((await postSync(await sealedSync(third))).statusCode, 200);
      expect(merged, hasLength(1));
    });

    test('random bytes are 401, not a crash', () async {
      await pairPhone();
      for (final int length in <int>[0, 1, 12, 27, 28, 4096]) {
        final http.Response response = await postSync(
          secureRandomBytes(length),
        );
        expect(response.statusCode, 401, reason: '$length bytes');
      }
      expect(merged, isEmpty);
    });

    test('a tampered body is 401', () async {
      final LanPeer peer = await pairPhone();
      final Uint8List sealed = await sealedSync(peer);
      sealed[sealed.length - 1] ^= 0x01;

      expect((await postSync(sealed)).statusCode, 401);
      expect(merged, isEmpty);
    });

    test('a stale message is refused with the clock-skew copy', () async {
      final LanPeer peer = await pairPhone();
      final http.Response response = await postSync(
        await sealedSync(peer, sentAt: t0.subtract(const Duration(minutes: 6))),
      );

      expect(response.statusCode, 400);
      expect(merged, isEmpty);

      // The refusal is sealed, because the peer is entitled to read it and the
      // copy is the point.
      final LanCipher cipher = await LanCipher.forPairingKey(peer.psk);
      final Uint8List plaintext = (await cipher.openOrNull(
        response.bodyBytes,
      ))!;
      expect(jsonDecode(utf8.decode(plaintext)), <String, Object?>{
        'problem': LanSyncFailure.clockSkewMessage,
      });
    });

    test('a different protocol version inside the body is refused', () async {
      final LanPeer peer = await pairPhone();
      final http.Response response = await postSync(
        await sealedSync(peer, protocolVersion: 2),
      );

      expect(response.statusCode, 400);
      expect(merged, isEmpty);
    });

    test('a snapshot with one bad record is refused whole', () async {
      // §11.6.1's all-or-nothing rule, reaching LAN input for free because the
      // payload is the document the codec already reads.
      final LanPeer peer = await pairPhone();
      final Map<String, Object?> document = const SnapshotCodec().toJson(
        SnapshotEnvelope(
          replicaId: 'replica-phone',
          deviceName: 'Pixel',
          generatedAt: t0,
          appVersion: '1.0.0',
          snapshot: snapshot(
            'replica-phone',
            ideas: <Idea>[idea('a', 'Fine'), idea('b', 'Also fine')],
          ),
        ),
      );
      (document['ideas']! as List<Object?>)[1] = <String, Object?>{
        ...(document['ideas']! as List<Object?>)[1]! as Map<String, Object?>,
        'name': '',
      };

      expect(
        (await postSync(await sealedSync(peer, document: document))).statusCode,
        400,
      );
      expect(
        merged,
        isEmpty,
        reason: 'the whole file is skipped, not one record',
      );
    });

    test('a future formatVersion is refused', () async {
      final LanPeer peer = await pairPhone();
      final Map<String, Object?> document = const SnapshotCodec().toJson(ours);
      document['formatVersion'] = 99;

      expect(
        (await postSync(await sealedSync(peer, document: document))).statusCode,
        400,
      );
      expect(merged, isEmpty);
    });

    test('a body that is not a document at all is refused', () async {
      final LanPeer peer = await pairPhone();
      for (final Object? document in <Object?>[
        null,
        'a string',
        <int>[1, 2],
      ]) {
        expect(
          (await postSync(await sealedSync(peer, document: document)))
              .statusCode,
          400,
          reason: '$document',
        );
      }
      expect(merged, isEmpty);
    });

    test('a body over 16 MiB is refused with 413, unread', () async {
      await pairPhone();
      final http.Response response = await postSync(
        Uint8List(LanBodyLimits.sync + 1),
      );

      expect(response.statusCode, 413);
      expect(merged, isEmpty);
    });

    test('a peer sending another replicaId is logged, not refused', () async {
      final LanPeer peer = await pairPhone();
      await postSync(
        await sealedSync(
          peer,
          envelope: SnapshotEnvelope(
            replicaId: 'someone-else',
            deviceName: 'Pixel',
            generatedAt: t0,
            appVersion: '1.0.0',
            snapshot: snapshot('someone-else'),
          ),
        ),
      );

      expect(merged, hasLength(1));
      expect(warnings.join('\n'), contains('someone-else'));
    });
  });

  group('§11.6.4 the listener', () {
    test('a port already in use is reported, not retried elsewhere', () async {
      final LanSyncServer second = LanSyncServer(
        replicas: FakeReplicaRepository('replica-other', 'Other'),
        settings: InMemorySettings(),
        snapshotSource: () async => ours,
        inboundMerge: (SnapshotEnvelope _) async {},
        clock: clock,
        appVersion: '1.0.0',
      );
      addTearDown(second.stop);
      await second.start(port: port, address: InternetAddress.loopbackIPv4);

      expect(second.isRunning, isFalse);
      expect((await second.state()).error, contains('$port'));
    });

    test('stopping closes the pairing window', () async {
      server.openPairingWindow();
      await server.stop();

      expect(server.pairingWindow, isNull);
      expect(server.isRunning, isFalse);
    });

    test('the state reports the paired count', () async {
      expect((await server.state()).pairedDevices, 0);
      await pairPhone();
      expect((await server.state()).pairedDevices, 1);
      expect((await server.state()).running, isTrue);
    });
  });
}
