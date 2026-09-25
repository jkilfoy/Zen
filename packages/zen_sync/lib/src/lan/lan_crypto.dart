/// §11.6.4. The AES-GCM-256 envelope every LAN message but `/hello` travels in.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:zen_domain/zen_domain.dart';

import 'lan_protocol.dart';

/// §11.6.4. AES-GCM-256, 12-byte nonce, 16-byte tag.
final AesGcm _aesGcm = AesGcm.with256bits();

/// §11.6.4. "HKDF-SHA256 over the pair's key, **empty salt** (RFC 5869's
/// zero-filled default), `info` = the UTF-8 bytes of `zen-sync-v1`, **32
/// bytes** of output."
final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// §11.6.4's `info`, exactly.
final List<int> _hkdfInfo = utf8.encode('zen-sync-v1');

/// §11.6.4. The nonce length AES-GCM uses here, in bytes.
const int lanNonceBytes = 12;

/// §11.6.4. The GCM authentication tag length, in bytes.
const int lanTagBytes = 16;

/// The one source of randomness in this package, and deliberately not
/// injectable.
///
/// §11.6.4: the nonce "MUST come from a cryptographically secure random source
/// and MUST NOT be derived from a counter, a timestamp, or anything else that
/// can repeat after a restart or a database restore: **reusing a nonce under
/// one AES-GCM key is a total break** … and it is invisible to any test that
/// does not look for it."
///
/// A seam here would let a test — or a future convenience — substitute a seeded
/// `Random`, which is precisely the failure the rule forbids and precisely the
/// one no test would notice. So the seam does not exist. `lan_crypto_test.dart`
/// tests the property instead: many seals under one key, all nonces distinct.
final Random _csprng = Random.secure();

/// Returns [count] cryptographically secure random bytes.
Uint8List secureRandomBytes(int count) {
  final Uint8List bytes = Uint8List(count);
  for (int i = 0; i < count; i++) {
    bytes[i] = _csprng.nextInt(256);
  }
  return bytes;
}

/// §11.6.4 step 1. A single-use pairing code.
///
/// "The code comes from a CSPRNG, **keeps its leading zeros**" — hence the pad
/// rather than a bare integer, which would silently render `000123` as `123`
/// and make a sixth of all codes untypeable as displayed.
String newPairingCode() {
  final StringBuffer digits = StringBuffer();
  for (int i = 0; i < LanPairing.codeDigits; i++) {
    digits.write(_csprng.nextInt(10));
  }
  return digits.toString();
}

/// §11.6.4. A fresh 32-byte pairing key, base64 for storage in §11.8's peer
/// record.
///
/// "A pre-shared key, 32 bytes from a CSPRNG, **generated afresh for each
/// pairing** — never one key reused across devices."
String newPairingKey() => base64Encode(secureRandomBytes(32));

/// §11.6.4. Compares two pairing codes without leaking where they differ.
///
/// "Compared in **constant time** — six digits is short enough for a timing
/// oracle to matter." Length is compared first and separately, which does leak
/// the length; that is not a secret, because §11.6.4 fixes it at six.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) {
    return false;
  }
  int difference = 0;
  for (int i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

/// §11.6.4. One pairing's key, ready to seal and open messages.
///
/// Holds the *derived* key rather than the pairing key, so the HKDF pass
/// happens once per peer rather than once per message — which matters on the
/// server, where "tries each paired peer's key in turn" would otherwise derive
/// a key per peer per request.
final class LanCipher {
  const LanCipher._(this._key);

  final SecretKey _key;

  /// Derives the message key from [pskBase64], per §11.6.4's key derivation.
  ///
  /// Throws [LanSyncFailure] if the stored key is not decodable base64 — a
  /// peer record that has been corrupted, which is better reported than
  /// treated as a wrong key and silently unable to sync.
  static Future<LanCipher> forPairingKey(String pskBase64) async {
    final List<int> psk;
    try {
      psk = base64Decode(pskBase64);
    } on FormatException {
      throw const LanSyncFailure(
        'This device\'s pairing key is unreadable. Unpair and pair again.',
      );
    }
    return LanCipher._(
      await _hkdf.deriveKey(
        secretKey: SecretKey(psk),
        // `nonce` is HKDF's *salt* in this package's naming. §11.6.4 fixes it
        // empty, which RFC 5869 defines as a zero-filled block of the hash
        // length — not as "no salt".
        nonce: const <int>[],
        info: _hkdfInfo,
      ),
    );
  }

  /// §11.6.4. Seals [plaintext] as `nonce || ciphertext || tag`.
  Future<Uint8List> seal(List<int> plaintext) async {
    final Uint8List nonce = secureRandomBytes(lanNonceBytes);
    final SecretBox box = await _aesGcm.encrypt(
      plaintext,
      secretKey: _key,
      nonce: nonce,
    );
    final BytesBuilder body = BytesBuilder(copy: false)
      ..add(nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return body.takeBytes();
  }

  /// §11.6.4. Opens a `nonce || ciphertext || tag` body, or returns `null`.
  ///
  /// Null rather than a throw, because the server "tries each paired peer's
  /// key in turn" and every wrong key failing is the ordinary path, not an
  /// error. "AES-GCM's tag makes the right one unambiguous and every wrong one
  /// fail cleanly."
  ///
  /// A body too short to hold a nonce and a tag is refused here rather than
  /// left to throw out of the cipher: the length arrives from the network and
  /// is therefore attacker-chosen.
  Future<Uint8List?> openOrNull(List<int> body) async {
    if (body.length < lanNonceBytes + lanTagBytes) {
      return null;
    }
    final SecretBox box = SecretBox(
      body.sublist(lanNonceBytes, body.length - lanTagBytes),
      nonce: body.sublist(0, lanNonceBytes),
      mac: Mac(body.sublist(body.length - lanTagBytes)),
    );
    try {
      return Uint8List.fromList(await _aesGcm.decrypt(box, secretKey: _key));
    } on SecretBoxAuthenticationError {
      return null;
    }
  }
}

/// §11.6.4. The plaintext carried inside the sealed body.
///
/// "encrypted §11.6.1 document + `sentAt` + `protocolVersion`". The document is
/// left as an already-parsed JSON value: `SnapshotCodec.fromJson` takes it from
/// here, so §11.6.1's all-or-nothing parsing, `formatVersion` refusal and
/// `nameNormalized` warning apply to LAN input without this file knowing
/// anything about the snapshot format.
final class LanMessage {
  /// Wraps a snapshot [document] sent at [sentAt].
  const LanMessage({required this.sentAt, required this.document});

  /// When the sender sealed it, for §11.6.4's skew check.
  final DateTime sentAt;

  /// The §11.6.1 document, as decoded JSON.
  final Object? document;

  /// Encodes this message as the plaintext bytes to seal.
  List<int> toBytes() => utf8.encode(
    jsonEncode(<String, Object?>{
      LanFields.protocolVersion: lanProtocolVersion,
      LanFields.sentAt: sentAt.toUtc().toIso8601String(),
      LanFields.document: document,
    }),
  );

  /// Parses and validates plaintext [bytes] that came off the network.
  ///
  /// Every failure here is hostile input by assumption, so each is refused with
  /// a message rather than allowed to throw something shaped like a bug.
  /// §11.6.4's two checks — the protocol version and the five-minute skew —
  /// both live here, so that neither end can perform one and forget the other.
  static LanMessage parse(List<int> bytes, Clock clock) {
    final Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const LanSyncFailure('The other device sent something unreadable.');
    }
    if (parsed is! Map<String, Object?>) {
      throw const LanSyncFailure('The other device sent something unreadable.');
    }

    if (parsed[LanFields.protocolVersion] != lanProtocolVersion) {
      throw LanSyncFailure(
        'These copies of Zen speak different sync protocols '
        '(this one v$lanProtocolVersion, the other '
        '${parsed[LanFields.protocolVersion]}). Update both.',
        kind: LanFailureKind.protocolMismatch,
      );
    }

    final Object? rawSentAt = parsed[LanFields.sentAt];
    final DateTime? sentAt = rawSentAt is String
        ? DateTime.tryParse(rawSentAt)
        : null;
    if (sentAt == null) {
      throw const LanSyncFailure('The other device sent something unreadable.');
    }
    if (clock.nowUtc().difference(sentAt.toUtc()).abs() > lanMaxClockSkew) {
      throw const LanSyncFailure(LanSyncFailure.clockSkewMessage);
    }

    return LanMessage(
      sentAt: sentAt.toUtc(),
      document: parsed[LanFields.document],
    );
  }
}
