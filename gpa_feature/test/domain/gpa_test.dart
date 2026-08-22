import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_feature/gpa_feature.dart';

Course _course(String id, double credits, Grade? grade) =>
    Course(id: id, title: 'Course $id', credits: credits, grade: grade);

const _a = Grade(letter: 'A', qualityPoints: 4);
const _b = Grade(letter: 'B', qualityPoints: 3);
const _pass = Grade(letter: 'P', qualityPoints: 0, countsTowardGpa: false);

void main() {
  group('calculateGpa', () {
    test('weights each course by its credits', () {
      final result = calculateGpa([_course('1', 3, _a), _course('2', 1, _b)]);
      expect(result.value, closeTo(3.75, 1e-9));
      expect(result.qualityCredits, 4);
    });

    test('is undefined rather than zero when nothing counts', () {
      final result = calculateGpa([_course('1', 3, null)]);
      expect(result.isDefined, isFalse);
      expect(result.value, isNull);
    });

    test('excludes a pass grade from the average but not from attempted', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course('2', 3, _pass),
      ]);
      expect(result.value, 4.0);
      expect(result.qualityCredits, 3);
      expect(result.attemptedCredits, 6);
    });

    test('an ungraded course adds no credits at all', () {
      final result = calculateGpa([_course('1', 3, _a), _course('2', 3, null)]);
      expect(result.attemptedCredits, 3);
    });

    test('an empty transcript is undefined, not an error', () {
      expect(calculateGpa(const []).isDefined, isFalse);
    });

    test('a failing grade lowers the average rather than being skipped', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course('2', 3, const Grade(letter: 'F', qualityPoints: 0)),
      ]);
      expect(result.value, 2.0);
      expect(result.qualityCredits, 6);
    });
  });

  group('Course', () {
    test('rejects credits outside the allowed range', () {
      expect(() => _course('1', 0, _a), throwsA(isA<InvalidCourseFailure>()));
      expect(() => _course('1', 25, _a), throwsA(isA<InvalidCourseFailure>()));
    });

    test('rejects a blank title', () {
      expect(
        () => Course(id: '1', title: '   ', credits: 3),
        throwsA(isA<InvalidCourseFailure>()),
      );
    });
  });

  group('FourPointScale', () {
    test('rejects a letter it does not define', () {
      expect(
        () => const FourPointScale().byLetter('Z'),
        throwsA(isA<UnknownGradeFailure>()),
      );
    });

    test('pass does not count toward the average', () {
      expect(const FourPointScale().byLetter('P').countsTowardGpa, isFalse);
    });
  });
}
