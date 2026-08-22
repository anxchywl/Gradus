import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The token surface is a contract shared with the other two projects that use
/// this kit. Drift is what made the previous copy diverge unnoticed, so a
/// change here has to be a visible diff in this file rather than a silent one.
List<String> _publicMembersOf(String path) {
  final declaration = RegExp(
    r'static\s+(?:const\s+|final\s+)?[\w<>, ?]+\s+(?:get\s+)?(\w+)',
  );
  return File(path)
      .readAsLinesSync()
      .map((line) => declaration.firstMatch(line)?.group(1))
      .whereType<String>()
      .where((name) => !name.startsWith('_'))
      .toList()
    ..sort();
}

void main() {
  test('spacing scale is the one documented scale', () {
    final spacing = _publicMembersOf('lib/tokens/app_spacing.dart');
    expect(spacing, contains('df'));
    expect(spacing, contains('radiusDf'));
    // a second scale is what the fork removed; it must not come back
    expect(
      File('lib/tokens/app_spacing.dart').readAsStringSync(),
      isNot(contains('HomeSpacing')),
    );
  });

  test('no compatibility aliases in the colour tokens', () {
    final source = File('lib/tokens/app_colors.dart').readAsStringSync();
    expect(source, isNot(contains('backward compatibility')));
    expect(source, isNot(contains('balanceCardBackground')));
  });

  test('kit carries no product concepts', () {
    final forbidden = [
      'bank',
      'job',
      'premium',
      'reward',
      'level_ring',
      'gpa',
      'course',
      'grade',
      'transcript',
    ];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final name = file.path.toLowerCase();
      for (final word in forbidden) {
        expect(
          name.contains(word),
          isFalse,
          reason: '${file.path} names a product concept; the kit stays generic',
        );
      }
    }
  });
}
