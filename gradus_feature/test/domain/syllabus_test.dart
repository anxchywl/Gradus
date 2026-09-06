import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/src/domain/syllabus.dart';

// a right-to-left override, a zero width space, an isolate and a byte order mark
const String hostile = '\u202e\u200b\u2066\ufeff';

void main() {
  group('sanitizeImported', () {
    test('strips controls, bidi overrides and zero-width characters', () {
      final cleaned = sanitizeImported('Linear$hostile Algebra', limit: 120);

      expect(cleaned, 'Linear Algebra');
      for (final rune in [0x202e, 0x200b, 0x2066, 0xfeff, 0x00, 0x1b, 0x9f]) {
        expect(cleaned!.runes.contains(rune), isFalse, reason: '$rune');
      }
    });

    test('collapses whitespace and caps the length', () {
      expect(
        sanitizeImported('  Linear  Algebra ', limit: 80),
        'Linear Algebra',
      );
      expect(sanitizeImported('x' * 500, limit: 10), 'x' * 10);
    });

    test('a string that is only noise becomes nothing', () {
      expect(sanitizeImported('', limit: 10), isNull);
      expect(sanitizeImported('   ', limit: 10), isNull);
      expect(sanitizeImported(hostile, limit: 10), isNull);
      expect(sanitizeImported(null, limit: 10), isNull);
    });
  });

  group('numbers', () {
    test('a weight outside the possible range is refused', () {
      for (final weight in [0.0, -1.0, 100.1, double.nan, double.infinity]) {
        expect(sanitizeWeight(weight), isNull, reason: '$weight');
      }
      expect(sanitizeWeight(40), 40);
    });

    test('credits outside the possible range are refused', () {
      for (final credits in [0.0, -1.0, 25.0, double.nan, double.infinity]) {
        expect(sanitizeCredits(credits), isNull, reason: '$credits');
      }
      expect(sanitizeCredits(8), 8);
    });
  });

  test('a draft with nothing in it knows it is empty', () {
    expect(const SyllabusDraft().isEmpty, isTrue);
    expect(const SyllabusDraft(code: 'MATH 273').isEmpty, isFalse);
  });

  test('the total weight is the sum of what was proposed', () {
    const draft = SyllabusDraft(
      assessments: [
        SyllabusAssessment(name: 'Midterm', weight: 40),
        SyllabusAssessment(name: 'Final', weight: 60),
      ],
    );

    expect(draft.totalWeight, 100);
  });
}
