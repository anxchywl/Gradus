import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer rules are a build-time promise, not a review convention. This
/// scans the source so a violation fails the suite rather than surviving to the
/// next reader.
Iterable<File> _dartFilesIn(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

List<String> _importsOf(File file) => file
    .readAsLinesSync()
    .map((line) => line.trim())
    .where((line) => line.startsWith('import ') || line.startsWith('export '))
    .toList();

void _expectNoImportMatching(
  String directory,
  Pattern forbidden, {
  required String because,
}) {
  final offenders = <String>[];
  for (final file in _dartFilesIn(directory)) {
    for (final line in _importsOf(file)) {
      if (line.contains(forbidden)) offenders.add('${file.path}: $line');
    }
  }
  expect(offenders, isEmpty, reason: because);
}

void main() {
  group('domain purity', () {
    test('domain does not import Flutter', () {
      _expectNoImportMatching(
        'lib/src/domain',
        'package:flutter/',
        because:
            'domain is pure Dart so its rules can be tested and reused '
            'without a widget binding',
      );
    });

    test('domain does not import networking, storage or the UI kit', () {
      for (final package in const [
        'package:http/',
        'package:shared_preferences/',
        'package:app_ui/',
      ]) {
        _expectNoImportMatching(
          'lib/src/domain',
          package,
          because: 'domain describes rules, not how they travel or are shown',
        );
      }
    });
  });

  group('dependency direction', () {
    test('application does not import data', () {
      _expectNoImportMatching(
        'lib/src/application',
        RegExp(r'''['"](?:\.\./)*data/'''),
        because:
            'controllers depend on domain interfaces, so an implementation '
            'can be swapped without touching them',
      );
    });

    test('presentation does not import data', () {
      _expectNoImportMatching(
        'lib/src/presentation',
        RegExp(r'''['"](?:\.\./)*data/'''),
        because:
            'a screen that names a repository implementation has taken a '
            'wiring decision that belongs in GpaScope',
      );
    });

    test('domain imports nothing from the layers above it', () {
      for (final layer in const ['application/', 'data/', 'presentation/']) {
        _expectNoImportMatching(
          'lib/src/domain',
          RegExp('''['"](?:\\.\\./)*$layer'''),
          because: 'dependencies point one way',
        );
      }
    });
  });

  test('only the scope wires an implementation to a controller', () {
    final offenders = <String>[];
    for (final file in _dartFilesIn('lib/src')) {
      if (file.path.contains('config/gpa_scope.dart')) continue;
      if (file.path.contains('/data/')) continue;
      for (final line in _importsOf(file)) {
        if (line.contains('in_memory_course_repository')) {
          offenders.add('${file.path}: $line');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'wiring happens once, where both sides are already known',
    );
  });

  test('no literal user-facing text outside the localizations', () {
    final offenders = <String>[];
    final textWidget = RegExp(r'''(?:Text|SelectableText)\(\s*['"][^'"]{3,}''');
    for (final file in _dartFilesIn('lib/src/presentation')) {
      final source = file.readAsStringSync();
      if (textWidget.hasMatch(source)) offenders.add(file.path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'every string comes from the ARB files, in all three languages',
    );
  });
}
