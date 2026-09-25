/// §11.6.4. Parsing the things another device tells us about itself.
///
/// Everything in this file arrives from off the device — a `/pair` body sent by
/// anyone on the Wi-Fi, or a QR code the camera happened to see — and every
/// value in it is either stored in the database or rendered in the UI. So each
/// one is validated on the way in, and a value that does not fit is refused
/// rather than sanitised: a name that has had characters removed is a name the
/// user cannot match against what the other device shows.
library;

import 'package:meta/meta.dart';

import 'lan_protocol.dart';

/// The longest QR payload worth parsing at all.
///
/// A QR code can carry a few kilobytes, and the payload below is under a
/// hundred bytes. Anything larger is not a Zen invitation.
const int _maxQrPayloadLength = 512;

/// A `replicaId` is a UUID (§11.5.1), so this is generous rather than tight.
final RegExp _replicaIdShape = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// Hostnames, IPv4 and IPv6 literals, including a zone index. Deliberately
/// excludes `/`, `@`, `?` and whitespace, so a host can never carry a path, a
/// userinfo section or a second URL inside it.
final RegExp _hostShape = RegExp(r'^[A-Za-z0-9._:%\[\]-]{1,255}$');

/// Exactly six digits, leading zeros included (§11.6.4 step 1).
final RegExp _codeShape = RegExp(r'^[0-9]{6}$');

/// Unicode control and format characters.
///
/// Rejected in a device name because it is shown in a list beside other
/// devices': a name carrying a bidirectional override can make itself render as
/// another device's, which is a spoof the user has no way to see.
final RegExp _unsafeInName = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
);

/// §11.6.4 step 3. How a peer identifies itself in `/pair`.
@immutable
final class LanPeerIdentity {
  /// Records a validated identity.
  const LanPeerIdentity({required this.replicaId, required this.deviceName});

  /// The peer's replica id.
  final String replicaId;

  /// The peer's device name, as the paired-device list will show it (§11.8).
  final String deviceName;

  /// Validates a `replicaId` and `deviceName` that came off the network.
  ///
  /// Returns `null` if either is missing, the wrong type, too long, or — for
  /// the name — carries characters that would let it misrepresent itself in the
  /// device list.
  static LanPeerIdentity? parse({
    required Object? replicaId,
    required Object? deviceName,
  }) {
    if (replicaId is! String || !_replicaIdShape.hasMatch(replicaId)) {
      return null;
    }
    final String? name = parseDeviceName(deviceName);
    return name == null
        ? null
        : LanPeerIdentity(replicaId: replicaId, deviceName: name);
  }

  /// Validates a device name from off the device, trimmed.
  static String? parseDeviceName(Object? value) {
    if (value is! String) {
      return null;
    }
    final String name = value.trim();
    if (name.isEmpty || name.length > 64 || _unsafeInName.hasMatch(name)) {
      return null;
    }
    return name;
  }
}

/// §11.6.4. What the desktop's QR code carries, and what the phone reads.
///
/// "**The QR payload is attacker-controlled input, and it decides where every
/// future snapshot goes.** A QR naming an attacker's host yields a code, an
/// attacker-chosen key, and the phone posting its entire dataset there on every
/// pass." Strict parsing is the first of §11.6.4's two defences; the second —
/// showing the user the host and device name and requiring a confirmation
/// before the code is sent — is the pairing screen's, and is the one that
/// matters.
@immutable
final class LanPairingInvitation {
  /// Records a validated invitation.
  const LanPairingInvitation({
    required this.host,
    required this.port,
    required this.code,
    required this.replicaId,
    required this.deviceName,
  });

  /// The URI scheme the payload uses.
  static const String scheme = 'zen-pair';

  /// The payload version, in the path. Bumped if the shape ever changes.
  static const String version = 'v1';

  /// The desktop's address.
  final String host;

  /// The desktop's port.
  final int port;

  /// The single-use pairing code.
  final String code;

  /// The desktop's replica id.
  final String replicaId;

  /// The desktop's device name, shown in the confirmation.
  final String deviceName;

  /// Returns a copy naming [host] instead, with everything else unchanged.
  ///
  /// §11.6.4, D-M7-15. The desktop offers every address it might be reachable
  /// at and lets the user switch between them. **The code must survive the
  /// switch**: a new one would invalidate whatever the user has already typed
  /// into the phone, and would mean the act of correcting a wrong address
  /// silently broke the pairing it was meant to fix.
  ///
  /// The same shape as `SnapshotEnvelope.withGeneratedAt`, and for the same
  /// reason — one field replaced without restating the rest.
  LanPairingInvitation withHost(String host) => LanPairingInvitation(
    host: host,
    port: port,
    code: code,
    replicaId: replicaId,
    deviceName: deviceName,
  );

  /// The payload the desktop renders as a QR code.
  String toPayload() => Uri(
    scheme: scheme,
    path: version,
    queryParameters: <String, String>{
      'host': host,
      'port': '$port',
      'code': code,
      'rid': replicaId,
      'dn': deviceName,
    },
  ).toString();

  /// Parses a scanned payload, or returns `null`.
  ///
  /// **Unknown query keys are refused**, not ignored. A payload carrying
  /// anything this version does not understand is not one this version should
  /// act on, and refusing is the behaviour that stays safe if the format ever
  /// grows a field that changes what pairing means.
  static LanPairingInvitation? parse(String payload) {
    if (payload.length > _maxQrPayloadLength) {
      return null;
    }
    final Uri uri;
    try {
      uri = Uri.parse(payload);
    } on FormatException {
      return null;
    }
    if (uri.scheme != scheme || uri.path != version) {
      return null;
    }

    const Set<String> known = <String>{'host', 'port', 'code', 'rid', 'dn'};
    final Map<String, String> query = uri.queryParameters;
    if (query.keys.toSet().difference(known).isNotEmpty) {
      return null;
    }

    final String host = query['host'] ?? '';
    final int port = int.tryParse(query['port'] ?? '') ?? -1;
    final String code = query['code'] ?? '';
    final LanPeerIdentity? identity = LanPeerIdentity.parse(
      replicaId: query['rid'],
      deviceName: query['dn'],
    );
    if (identity == null ||
        !isValidHost(host) ||
        !isValidPort(port) ||
        !_codeShape.hasMatch(code)) {
      return null;
    }

    return LanPairingInvitation(
      host: host,
      port: port,
      code: code,
      replicaId: identity.replicaId,
      deviceName: identity.deviceName,
    );
  }
}

/// §11.6.4. Whether [host] is something this app will dial.
///
/// Used for the manual host entry as well as the QR payload — "a manual
/// host:port entry is mandatory, not optional", and a typed host is no more
/// trustworthy than a scanned one.
bool isValidHost(String host) => _hostShape.hasMatch(host);

/// Whether [port] is a legal TCP port.
bool isValidPort(int port) => port > 0 && port <= 65535;

/// Whether [code] is six digits (§11.6.4 step 1).
bool isValidPairingCode(String code) => _codeShape.hasMatch(code);

/// The default port, re-exported so the pairing screen need not reach into
/// `lan_protocol.dart` for one constant.
const int defaultLanPort = lanDefaultPort;
