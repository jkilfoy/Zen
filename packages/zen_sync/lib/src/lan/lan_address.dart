/// §11.6.4. Choosing which of this device's addresses to offer a phone.
///
/// The desktop has to put *an* address in its QR code and its on-screen text,
/// and it cannot know which one the phone can reach — only the phone can. What
/// it can do is rank its own addresses so the default is usually right, and
/// show the rest so a wrong default is correctable without leaving the app.
///
/// Pure, and deliberately here rather than in the provider that calls it:
/// §11.7 says "if a decision needs a test, it belongs" somewhere testable, and
/// `NetworkInterface.list()` is the untestable part. `zen_app` does the
/// enumerating and passes the results in.
library;

import 'package:meta/meta.dart';

import 'lan_peer_input.dart';

/// One address this device might be reachable at.
@immutable
final class LanAddressCandidate {
  /// Records [address], found on the interface named [interfaceName].
  const LanAddressCandidate({
    required this.address,
    required this.interfaceName,
  });

  /// The IPv4 address, as text.
  final String address;

  /// The platform's name for the interface it was found on — `"Wi-Fi 2"`,
  /// `"vEthernet (WSL)"`. Shown to the user beside the address, because the
  /// name is often the only way they can tell which one is their Wi-Fi.
  final String interfaceName;

  @override
  bool operator ==(Object other) =>
      other is LanAddressCandidate &&
      other.address == address &&
      other.interfaceName == interfaceName;

  @override
  int get hashCode => Object.hash(address, interfaceName);

  @override
  String toString() => '$address ($interfaceName)';
}

/// Interface names that are virtual and therefore unreachable from a phone.
///
/// **Checked before [_physicalHints], and that order is load-bearing:**
/// `vEthernet (WSL)` contains `ethernet`, so a physical-first check would rank
/// WSL's host-only adapter as a real network card. That is exactly the defect
/// this file exists to fix (D-M7-15).
const List<String> _virtualHints = <String>[
  'vethernet',
  'wsl',
  'hyper-v',
  'hyperv',
  'default switch',
  'virtualbox',
  'vmware',
  'docker',
  'tap-windows',
  'tailscale',
  'zerotier',
  'openvpn',
  'wireguard',
  'vpn',
  'virtual',
  'loopback',
];

/// Interface names that look like real network hardware.
const List<String> _physicalHints = <String>[
  'wi-fi',
  'wifi',
  'wireless',
  'wlan',
  'ethernet',
  'eth0',
  'en0',
];

/// §11.6.4. Ranks [candidates] best-first, dropping the unusable ones.
///
/// Dropped: loopback and link-local, neither of which a phone can reach, and
/// anything [isValidHost] refuses.
///
/// Ranked, in three tiers: interfaces that look like real hardware, then ones
/// whose names say nothing either way, then ones that look virtual. **The name
/// is a ranking signal and never an exclusion.** A heuristic that excluded
/// would eventually hide the only address that works on somebody's machine,
/// and a wrong guess the user can correct is recoverable where a hidden address
/// is not.
///
/// Ordering is stable within a tier, so the platform's own order survives where
/// this function has no opinion.
List<LanAddressCandidate> rankLanAddresses(
  Iterable<LanAddressCandidate> candidates,
) {
  final List<LanAddressCandidate> usable = <LanAddressCandidate>[
    for (final LanAddressCandidate candidate in candidates)
      if (isReachableLanAddress(candidate.address)) candidate,
  ];

  // A stable sort on the tier alone: `List.sort` is not stable, so the index is
  // folded into the comparison to keep equal tiers in their original order.
  final List<({int index, int tier, LanAddressCandidate candidate})> ranked =
      <({int index, int tier, LanAddressCandidate candidate})>[
        for (final (int index, LanAddressCandidate candidate) entry
            in usable.indexed)
          (
            index: entry.$1,
            tier: _tierOf(entry.$2.interfaceName),
            candidate: entry.$2,
          ),
      ]..sort(
        (
          ({int index, int tier, LanAddressCandidate candidate}) a,
          ({int index, int tier, LanAddressCandidate candidate}) b,
        ) => a.tier == b.tier
            ? a.index.compareTo(b.index)
            : a.tier.compareTo(b.tier),
      );

  return <LanAddressCandidate>[
    for (final ({int index, int tier, LanAddressCandidate candidate}) entry
        in ranked)
      entry.candidate,
  ];
}

/// Whether [address] is one a phone on the same Wi-Fi could reach.
///
/// Excludes loopback and link-local. `169.254.x.x` is what Windows assigns to
/// an adapter that never got a DHCP lease — a cable that is plugged into
/// nothing — and it is never routable from another device.
bool isReachableLanAddress(String address) =>
    isValidHost(address) &&
    !address.startsWith('127.') &&
    !address.startsWith('169.254.') &&
    address != '0.0.0.0';

/// 0 for hardware, 1 for unknown, 2 for virtual.
int _tierOf(String interfaceName) {
  final String name = interfaceName.toLowerCase();
  for (final String hint in _virtualHints) {
    if (name.contains(hint)) {
      return 2;
    }
  }
  for (final String hint in _physicalHints) {
    if (name.contains(hint)) {
      return 0;
    }
  }
  return 1;
}
