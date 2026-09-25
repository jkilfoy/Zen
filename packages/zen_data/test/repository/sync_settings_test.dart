/// §11.8. The sync settings, through the key-value settings table.
///
/// §11.5.1 chose a key-value table over a column-per-setting one precisely so
/// these could join "in M6 without a migration". That claim is what the first
/// group checks.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zen_domain/zen_domain.dart';

import '../support/harness.dart';

void main() {
  late TestRepositories repos;

  setUp(() => repos = TestRepositories());

  group('§11.8 factory defaults', () {
    test('a fresh replica reads every default the table specifies', () async {
      final Settings settings = await repos.settings.read();

      expect(settings.syncFolderEnabled, isFalse);
      expect(settings.syncFolderLocation, isNull);
      expect(settings.syncLanEnabled, isFalse);
      expect(settings.syncLanPort, 51789);
      expect(settings.syncLanPeers, isEmpty);
      expect(settings.syncOnForeground, isTrue);
      expect(settings.syncIntervalMinutes, 15);
      expect(settings.lastSyncAt, isNull);
    });

    test('they arrive without a schema migration', () async {
      // The v1 schema has no sync columns; these keys are rows. If this ever
      // needs a migration, §11.5.1's reasoning has been undone.
      expect(repos.db.schemaVersion, 1);
      expect((await repos.settings.read()).syncLanPort, 51789);
    });
  });

  group('§11.8 round trip', () {
    test('every sync setting survives a write and a read', () async {
      final Settings written = Settings(
        syncFolderEnabled: true,
        syncFolderLocation: r'D:\Sync\Zen',
        syncLanEnabled: true,
        syncLanPort: 9000,
        syncLanPeers: <LanPeer>[
          const LanPeer(
            replicaId: 'replica-b',
            deviceName: 'Jordan, phone',
            host: '192.168.1.5',
            port: 51789,
            psk: 'c2VjcmV0',
          ),
        ],
        syncOnForeground: false,
        syncIntervalMinutes: 30,
        lastSyncAt: at(5),
      );

      await repos.settings.write(written);

      expect(await repos.settings.read(), written);
    });

    test('an Android SAF tree URI survives unchanged', () async {
      // §11.6.3: the location is a path on Windows and a URI on Android, and
      // the column has to hold either without interpreting it.
      const String uri =
          'content://com.android.externalstorage.documents/tree/primary%3ASync%2FZen';
      await repos.settings.write(Settings(syncFolderLocation: uri));

      expect((await repos.settings.read()).syncFolderLocation, uri);
    });

    test(
      'a device name with a comma survives, which JSON is here for',
      () async {
        await repos.settings.write(
          Settings(
            syncLanPeers: <LanPeer>[
              const LanPeer(
                replicaId: 'replica-b',
                deviceName: 'Kitchen, upstairs',
                host: 'zen.local',
                port: 51789,
                psk: 'a2V5',
              ),
            ],
          ),
        );

        expect(
          (await repos.settings.read()).syncLanPeers.single.deviceName,
          'Kitchen, upstairs',
        );
      },
    );

    test(
      'clearing the folder location stores null, not the empty string',
      () async {
        await repos.settings.write(
          Settings(syncFolderLocation: r'D:\Sync\Zen'),
        );

        await repos.settings.write(
          (await repos.settings.read()).withoutSyncFolder(),
        );

        expect((await repos.settings.read()).syncFolderLocation, isNull);
      },
    );

    test('§3.6 settings are untouched by a sync setting changing', () async {
      await repos.settings.write(Settings(endOfDay: const LocalTime(4, 30)));

      await repos.settings.write(
        (await repos.settings.read()).copyWith(syncIntervalMinutes: 60),
      );

      final Settings after = await repos.settings.read();
      expect(after.endOfDay, const LocalTime(4, 30));
      expect(after.syncIntervalMinutes, 60);
    });
  });

  group('§11.5.5: a malformed value falls back to its factory default', () {
    /// Writes [value] under [key] with raw SQL, bypassing the encoder.
    ///
    /// The encoder can only produce well-formed values, so a test that went
    /// through it could not reach the fallbacks §11.5.5 asks for. The rows a
    /// real device has to survive come from an older build, a hand-edited file
    /// or a partial write — none of which the encoder ever made either.
    Future<Settings> readWith(String key, String value) async {
      await repos.settings.write(Settings());
      await repos.db.customStatement(
        'INSERT INTO settings (setting_key, setting_value) VALUES (?, ?) '
        'ON CONFLICT (setting_key) DO UPDATE SET setting_value = excluded.setting_value',
        <Object?>[key, value],
      );
      return repos.settings.read();
    }

    test('a port outside the TCP range', () async {
      // Neither 0 nor 70000 is a preference the app can honour.
      expect((await readWith('syncLanPort', '0')).syncLanPort, 51789);
      expect((await readWith('syncLanPort', '70000')).syncLanPort, 51789);
      expect((await readWith('syncLanPort', 'nine')).syncLanPort, 51789);
    });

    test('a negative interval, while zero is a real value', () async {
      expect(
        (await readWith('syncIntervalMinutes', '-5')).syncIntervalMinutes,
        15,
      );
      // §11.8: "`0` disables." Not malformed.
      final Settings disabled = await readWith('syncIntervalMinutes', '0');
      expect(disabled.syncIntervalMinutes, 0);
      expect(disabled.syncTimerEnabled, isFalse);
    });

    test('unreadable peer JSON', () async {
      expect((await readWith('syncLanPeers', '{oops')).syncLanPeers, isEmpty);
      expect(
        (await readWith('syncLanPeers', '"a string"')).syncLanPeers,
        isEmpty,
      );
    });

    test('a peer entry missing a field is dropped, not half-built', () async {
      // M7 dials these. "A peer with no host is a connection attempt that can
      // only fail."
      final Settings settings = await readWith(
        'syncLanPeers',
        '[{"replicaId":"replica-b","deviceName":"phone","port":51789,'
            '"psk":"a2V5"},'
            '{"replicaId":"replica-c","deviceName":"pc","host":"zen.local",'
            '"port":51789,"psk":"a2V5"}]',
      );

      expect(settings.syncLanPeers.map((LanPeer p) => p.replicaId), <String>[
        'replica-c',
      ]);
    });

    test('a malformed lastSyncAt reads as never synced', () async {
      expect((await readWith('lastSyncAt', 'yesterday')).lastSyncAt, isNull);
    });
  });

  group('SET-2: changes apply immediately', () {
    test('the stream sees a sync setting change', () async {
      final Future<Settings> next = repos.settings.watch().firstWhere(
        (Settings s) => s.syncFolderEnabled,
      );

      await repos.settings.write(Settings(syncFolderEnabled: true));

      expect((await next).syncFolderEnabled, isTrue);
    });
  });
}
