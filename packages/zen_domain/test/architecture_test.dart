import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// §11.1, §11.11. The architecture of this project is enforced by the
/// compiler, and this file is what stops that enforcement from being quietly
/// removed. `zen_domain` must stay pure Dart with no route to IO, and no code
/// outside `zen_app` may read the wall clock directly.
///
/// If a change here is deliberate, update the allow-list *and* record the
/// reason in DECISIONS.md (§0.1).
void main() {
  final Directory packageRoot = _packageRoot();

  group('§11.1: zen_domain depends on nothing that touches IO', () {
    /// Every runtime dependency zen_domain is permitted. Deliberately an
    /// allow-list rather than a deny-list: a new dependency fails this test
    /// until someone justifies it.
    const Set<String> allowedDependencies = <String>{
      'characters',
      'collection',
      'meta',
      'unorm_dart',
      'uuid',
    };

    /// Named explicitly by §11.1, plus the rest of the stack that would drag
    /// IO in transitively.
    const Set<String> bannedAnywhere = <String>{
      'flutter',
      'flutter_test',
      'drift',
      'drift_flutter',
      'drift_dev',
      'sqlite3',
      'sqlite3_flutter_libs',
      'shelf',
      'shelf_router',
      'http',
      'path_provider',
      'file_selector',
      'timezone',
      'zen_data',
      'zen_sync',
      'zen_app',
    };

    late final YamlMap pubspec;

    setUpAll(() {
      pubspec = loadYaml(
        File('${packageRoot.path}/pubspec.yaml').readAsStringSync(),
      ) as YamlMap;
    });

    test('runtime dependencies are exactly the allow-list', () {
      final Set<String> declared =
          (pubspec['dependencies'] as YamlMap? ?? YamlMap()).keys
              .cast<String>()
              .toSet();

      expect(
        declared.difference(allowedDependencies),
        isEmpty,
        reason:
            'zen_domain gained an unvetted dependency. §11.1 forbids '
            'anything that touches IO; justify it in DECISIONS.md and add it '
            'to allowedDependencies if it is genuinely pure.',
      );
    });

    test('no banned package appears as a dependency or dev_dependency', () {
      const List<String> sections = <String>[
        'dependencies',
        'dev_dependencies',
      ];

      for (final String section in sections) {
        final Set<String> declared = (pubspec[section] as YamlMap? ?? YamlMap())
            .keys
            .cast<String>()
            .toSet();

        expect(
          declared.intersection(bannedAnywhere),
          isEmpty,
          reason: '$section contains a package §11.1 forbids in zen_domain.',
        );
      }
    });
  });

  group('§11.1, §11.11: lib/ source constraints', () {
    /// Import prefixes that would give this package a route to IO, a UI
    /// toolkit, or the platform.
    const List<String> bannedImports = <String>[
      "dart:io",
      "dart:ui",
      "dart:html",
      "dart:isolate",
      "dart:ffi",
      "package:flutter/",
      "package:drift/",
      "package:zen_data/",
      "package:zen_sync/",
      "package:zen_app/",
    ];

    late final List<File> sources;

    setUpAll(() {
      sources = Directory('${packageRoot.path}/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList(growable: false);
    });

    test('lib/ contains at least one Dart source to check', () {
      expect(sources, isNotEmpty);
    });

    test('no source imports Flutter, IO or a downstream package', () {
      final List<String> offences = <String>[];

      for (final File source in sources) {
        final String text = _stripComments(source.readAsStringSync());
        for (final String banned in bannedImports) {
          if (text.contains("import '$banned") ||
              text.contains('import "$banned') ||
              text.contains("export '$banned") ||
              text.contains('export "$banned')) {
            offences.add('${source.path}: $banned');
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason: '§11.1 violated:\n${offences.join('\n')}',
      );
    });

    test('§11.11: DateTime.now() does not appear outside zen_app', () {
      final List<String> offences = <String>[
        for (final File source in sources)
          if (_stripComments(source.readAsStringSync())
              .contains('DateTime.now()'))
            source.path,
      ];

      expect(
        offences,
        isEmpty,
        reason:
            '§11.11 bans DateTime.now() here. Take the instant as a '
            'parameter, or inject a Clock (§11.4.3):\n${offences.join('\n')}',
      );
    });
  });
}

/// Strips `//` line comments and block comments so that prose about a banned
/// construct is not mistaken for the construct itself. The first run of these
/// checks flagged `zen_domain.dart`'s own doc comment, which names the rule it
/// documents.
///
/// This also strips `//` inside string literals. That can only ever cause a
/// false negative, and only for a string that contains `//` followed by a
/// banned construct, so it is not worth a real parser here.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp('//[^\n]*'), '');

/// Resolves the package root whether tests are run from the package directory
/// or from the repository root.
Directory _packageRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail(
        'Could not locate zen_domain/pubspec.yaml from ${Directory.current}',
      );
    }
    dir = parent;
  }
  return dir;
}
