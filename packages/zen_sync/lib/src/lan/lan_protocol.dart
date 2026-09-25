/// §11.6.4. The wire constants and refusal reasons of the LAN protocol.
///
/// Everything here is shared by the server and the client, and every value is
/// one the two ends must agree on exactly. They are in one file so that a
/// change to either end cannot silently disagree with the other.
library;

import 'package:meta/meta.dart';

/// §11.6.4. The protocol version, **not** §11.6.1's `formatVersion`.
///
/// "One governs the wire exchange, the other the snapshot document. It is
/// carried in `/hello`, in `/pair` and inside the `/sync` plaintext, and
/// checked at each, so a client that skips `/hello` is still refused rather
/// than half-understood."
const int lanProtocolVersion = 1;

/// §11.6.4. The service type the desktop registers and the phone browses for.
const String lanServiceType = '_zen-sync._tcp';

/// §11.8. The desktop's default listen port.
const int lanDefaultPort = 51789;

/// §11.6.4's endpoint paths.
abstract final class LanPaths {
  /// The unencrypted identity endpoint.
  static const String hello = '/zen/v1/hello';

  /// The pairing endpoint.
  static const String pair = '/zen/v1/pair';

  /// The encrypted snapshot exchange.
  static const String sync = '/zen/v1/sync';
}

/// §11.6.4's TXT record keys.
abstract final class LanTxtKeys {
  /// The desktop's `replicaId`.
  static const String replicaId = 'rid';

  /// The protocol version.
  static const String protocolVersion = 'pv';

  /// The desktop's device name.
  static const String deviceName = 'dn';
}

/// §11.6.4. "Bodies are capped before they are read into memory."
///
/// "Without a cap, anyone on the network can make the desktop buffer a gigabyte
/// before the first decryption attempt." Over-cap requests are refused with
/// 413, and the cap is enforced against `Content-Length` *and* against the
/// bytes actually read, because a hostile client may lie about the former or
/// send none at all.
abstract final class LanBodyLimits {
  /// §11.6.4's 1 KiB cap on `/pair`.
  static const int pair = 1024;

  /// §11.6.4's 16 MiB cap on `/sync`.
  static const int sync = 16 * 1024 * 1024;
}

/// §11.6.4. "Every client call is bounded by a timeout."
///
/// "The exchange runs inside the orchestrator's single-flight lock (§11.6.5
/// step 1), so a desktop that accepts a connection and then stops answering …
/// would otherwise hang the pass forever, and every later trigger would join
/// that dead future."
abstract final class LanTimeouts {
  /// Time allowed to establish the TCP connection.
  static const Duration connect = Duration(seconds: 3);

  /// Total time allowed for `/zen/v1/sync`, which carries the whole dataset.
  static const Duration sync = Duration(seconds: 30);

  /// Total time allowed for `/zen/v1/hello` and `/zen/v1/pair`, which are small
  /// and are waited on by a user looking at a pairing screen.
  static const Duration short = Duration(seconds: 4);
}

/// §11.6.4's pairing window rules.
abstract final class LanPairing {
  /// "Opens a 5-minute pairing window."
  static const Duration window = Duration(minutes: 5);

  /// "Five failed attempts close the window."
  static const int maxFailedAttempts = 5;

  /// The number of digits in the code. Six, per §11.6.4.
  static const int codeDigits = 6;
}

/// §11.6.4. "A skew over 5 minutes is rejected."
const Duration lanMaxClockSkew = Duration(minutes: 5);

/// §11.6.4. The JSON keys of the request and response bodies.
///
/// Named rather than spelled inline at both ends, because a typo in one of them
/// is a bug that only two devices on one network can find.
abstract final class LanFields {
  /// Both directions, and the `/hello` body.
  static const String protocolVersion = 'protocolVersion';

  /// `/hello` and `/pair`.
  static const String replicaId = 'replicaId';

  /// `/hello` and `/pair`.
  static const String deviceName = 'deviceName';

  /// `/hello` only.
  static const String appVersion = 'appVersion';

  /// `/pair` request.
  static const String code = 'code';

  /// `/pair` response. The pair's key, base64.
  static const String psk = 'psk';

  /// `/sync` plaintext: when the message was sent, for the skew check.
  static const String sentAt = 'sentAt';

  /// `/sync` plaintext: the §11.6.1 document.
  static const String document = 'document';
}

/// §11.6.4. Why a LAN exchange could not be completed.
///
/// A [SyncTransport.fetchPeerSnapshots] failure becomes a per-transport status
/// line (§11.6.5 step 3), so every one of these has to be a sentence a user can
/// act on rather than a status code. The clock-skew wording is specified
/// verbatim by §11.6.4 and is reproduced exactly.
@immutable
final class LanSyncFailure implements Exception {
  /// Records a refusal or a failure, described by [message].
  const LanSyncFailure(this.message);

  /// §11.6.4's mandated copy for the skew failure, which is otherwise silent.
  ///
  /// "What the check *does* break is two devices whose clocks differ by more
  /// than five minutes: they can never sync, and nothing about the failure says
  /// so. The status line for that case MUST name it."
  static const String clockSkewMessage =
      "These devices' clocks are more than 5 minutes apart. "
      'Check the date and time on both.';

  /// §11.6.4. "Document this in the UI."
  static const String desktopNotRunningMessage = 'Open Zen on your PC to sync.';

  /// What to show the user.
  final String message;

  @override
  String toString() => message;
}
