/// §11.6.4, D-M7-15. Which address the desktop offers a phone.
///
/// The bug these tests exist for: `localAddress()` took the *first*
/// non-loopback address `NetworkInterface.list()` returned, and on a Windows
/// machine with WSL installed that is the host-only `vEthernet (WSL)` adapter.
/// The QR code and the on-screen address both named `172.26.240.1`, which no
/// phone can ever route to, and pairing failed on both the scan and the typed
/// path with a three-second connect timeout.
library;

import 'package:test/test.dart';
import 'package:zen_sync/zen_sync.dart';

void main() {
  LanAddressCandidate on(String interfaceName, String address) =>
      LanAddressCandidate(address: address, interfaceName: interfaceName);

  List<String> addressesOf(List<LanAddressCandidate> ranked) =>
      ranked.map((LanAddressCandidate c) => c.address).toList();

  group('D-M7-15: ranking the addresses this device could be reached at', () {
    test('the machine that found this bug now picks its Wi-Fi', () {
      // Verbatim from the reported failure: `NetworkInterface.list()` returned
      // the WSL adapter first and the Wi-Fi second, and the first won.
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('vEthernet (WSL)', '172.26.240.1'),
          on('Wi-Fi 2', '192.168.0.228'),
        ],
      );

      expect(addressesOf(ranked), <String>['192.168.0.228', '172.26.240.1']);
    });

    test('"vEthernet" is virtual even though it contains "ethernet"', () {
      // The trap that made the original heuristic worth writing down: a
      // physical-first check matches `ethernet` inside `vEthernet` and ranks
      // WSL's adapter as real hardware.
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('vEthernet (Default Switch)', '172.17.0.1'),
          on('Ethernet', '10.0.0.5'),
        ],
      );

      expect(addressesOf(ranked), <String>['10.0.0.5', '172.17.0.1']);
    });

    test('other virtual adapters rank below real ones', () {
      for (final String virtual in <String>[
        'vEthernet (WSL)',
        'Hyper-V Virtual Ethernet Adapter',
        'VirtualBox Host-Only Network',
        'VMware Network Adapter VMnet8',
        'Docker Desktop Bridge',
        'Tailscale',
        'ZeroTier One',
        'OpenVPN TAP-Windows6',
        'WireGuard Tunnel',
      ]) {
        final List<LanAddressCandidate> ranked = rankLanAddresses(
          <LanAddressCandidate>[
            on(virtual, '172.30.0.1'),
            on('Wi-Fi', '192.168.1.50'),
          ],
        );
        expect(
          ranked.first.address,
          '192.168.1.50',
          reason: '"$virtual" outranked a real Wi-Fi adapter',
        );
      }
    });

    test('a virtual adapter is ranked down, never hidden', () {
      // "The name is a ranking signal and never an exclusion." A machine whose
      // only reachable address sits on an oddly named adapter must still be
      // able to pair.
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[on('vEthernet (WSL)', '172.26.240.1')],
      );

      expect(addressesOf(ranked), <String>['172.26.240.1']);
    });

    test('an unknown adapter name outranks a virtual one', () {
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('vEthernet (WSL)', '172.26.240.1'),
          on('Local Area Connection 3', '10.1.2.3'),
        ],
      );

      expect(addressesOf(ranked), <String>['10.1.2.3', '172.26.240.1']);
    });

    test('a real adapter outranks an unknown one', () {
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('Local Area Connection 3', '10.1.2.3'),
          on('Wi-Fi 2', '192.168.0.228'),
        ],
      );

      expect(addressesOf(ranked), <String>['192.168.0.228', '10.1.2.3']);
    });

    test('order is stable within a tier', () {
      // Two Wi-Fi adapters: this function has no opinion, so the platform's
      // order survives rather than being shuffled.
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('Wi-Fi', '192.168.1.10'),
          on('Wi-Fi 2', '192.168.1.11'),
          on('Wireless LAN', '192.168.1.12'),
        ],
      );

      expect(addressesOf(ranked), <String>[
        '192.168.1.10',
        '192.168.1.11',
        '192.168.1.12',
      ]);
    });

    test('loopback and link-local are dropped, not ranked', () {
      // 169.254 is what Windows assigns an adapter that never got a lease — a
      // cable plugged into nothing. The reporting machine had three of them.
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('Loopback Pseudo-Interface 1', '127.0.0.1'),
          on('Ethernet', '169.254.146.3'),
          on('Local Area Connection* 11', '169.254.125.107'),
          on('Wi-Fi 2', '192.168.0.228'),
        ],
      );

      expect(addressesOf(ranked), <String>['192.168.0.228']);
    });

    test('nonsense is dropped rather than offered', () {
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[
          on('Wi-Fi', '0.0.0.0'),
          on('Wi-Fi', ''),
          on('Wi-Fi', 'not an address at all'),
        ],
      );

      expect(ranked, isEmpty);
    });

    test('no usable address is an empty list, not a throw', () {
      expect(rankLanAddresses(const <LanAddressCandidate>[]), isEmpty);
    });

    test('the interface name is carried through for the user to read', () {
      // The address alone does not tell anyone which one is their Wi-Fi.
      final List<LanAddressCandidate> ranked = rankLanAddresses(
        <LanAddressCandidate>[on('Wi-Fi 2', '192.168.0.228')],
      );

      expect(ranked.single.interfaceName, 'Wi-Fi 2');
      expect(ranked.single.toString(), '192.168.0.228 (Wi-Fi 2)');
    });
  });

  group('D-M7-17: a failure carries what kind it is', () {
    test('kinds are distinct values callers can branch on', () {
      // The pairing screens re-word an unreachable host; matching on message
      // text would break silently the first time the copy changed.
      const LanSyncFailure unreachable = LanSyncFailure(
        LanSyncFailure.desktopNotRunningMessage,
        kind: LanFailureKind.unreachable,
      );

      expect(unreachable.kind, LanFailureKind.unreachable);
      expect(unreachable.message, 'Open Zen on your PC to sync.');
      expect(
        const LanSyncFailure('refused').kind,
        LanFailureKind.refused,
        reason: 'the default kind is the one that needs no special wording',
      );
    });
  });
}
