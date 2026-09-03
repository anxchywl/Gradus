import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';

const _scale = FourPointScale();
const _a = Grade(letter: 'A', qualityPoints: 4);
const _b = Grade(letter: 'B', qualityPoints: 3);
const _pass = Grade(letter: 'P', qualityPoints: 0, countsTowardGpa: false);

Course _course(
  String id,
  double credits,
  Grade? grade, {
  String semesterId = 'fall',
}) => Course(
  id: id,
  semesterId: semesterId,
  title: 'Course $id',
  credits: credits,
  grade: grade,
);

void main() {
  group('calculateGpa', () {
    test('weights each course by its credits', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course('2', 1, _b),
      ], _scale);
      expect(result.value, closeTo(3.75, 1e-9));
      expect(result.qualityCredits, 4);
    });

    test('is undefined rather than zero when nothing counts', () {
      final result = calculateGpa([_course('1', 3, null)], _scale);
      expect(result.isDefined, isFalse);
      expect(result.value, isNull);
    });

    test('excludes a pass grade from the average but not from attempted', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course('2', 3, _pass),
      ], _scale);
      expect(result.value, 4.0);
      expect(result.qualityCredits, 3);
      expect(result.attemptedCredits, 6);
    });

    test('a letter carrying no points counts as attempted, never toward the '
        'average', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course(
          '2',
          4,
          const Grade(letter: 'P', qualityPoints: 0, countsTowardGpa: false),
        ),
      ], _scale);
      expect(result.value, 4.0, reason: 'the P must not move the average');
      expect(result.qualityCredits, 3);
      expect(result.attemptedCredits, 7);
    });

    test('an ungraded course adds no credits at all', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course('2', 3, null),
      ], _scale);
      expect(result.attemptedCredits, 3);
    });

    test('an empty transcript is undefined, not an error', () {
      expect(calculateGpa(const [], _scale).isDefined, isFalse);
    });

    test('a failing grade lowers the average rather than being skipped', () {
      final result = calculateGpa([
        _course('1', 3, _a),
        _course('2', 3, const Grade(letter: 'F', qualityPoints: 0)),
      ], _scale);
      expect(result.value, 2.0);
      expect(result.qualityCredits, 6);
    });

    test('a grade derived from assignments carries the same weight', () {
      final course = Course(
        id: '1',
        semesterId: 'fall',
        title: 'Derived',
        credits: 3,
        assignments: [
          Assignment(
            id: 'a1',
            courseId: '1',
            name: 'Final',
            weight: 100,
            maximumScore: 100,
            earnedScore: 95,
          ),
        ],
      );

      final result = calculateGpa([course], _scale);

      expect(result.value, 4.0, reason: '95% is an A on this scale');
      expect(result.qualityCredits, 3);
    });

    test('a cumulative average spans every semester', () {
      final result = calculateGpa([
        _course('1', 4, _a, semesterId: 'fall'),
        _course('2', 4, _b, semesterId: 'spring'),
      ], _scale);

      expect(result.value, 3.5);
      expect(result.qualityCredits, 8);
    });
  });

  group('Course', () {
    test('rejects credits outside the allowed range', () {
      expect(() => _course('1', 0, _a), throwsA(isA<InvalidCourseFailure>()));
      expect(() => _course('1', 25, _a), throwsA(isA<InvalidCourseFailure>()));
    });

    test('rejects a blank title', () {
      expect(
        () => Course(id: '1', semesterId: 'fall', title: '   ', credits: 3),
        throwsA(isA<InvalidCourseFailure>()),
      );
    });

    test('rejects a course with no semester to belong to', () {
      expect(
        () => Course(id: '1', semesterId: '', title: 'Orphan', credits: 3),
        throwsA(isA<InvalidCourseFailure>()),
      );
    });

    test('refuses an assignment that belongs to another course', () {
      expect(
        () => Course(
          id: '1',
          semesterId: 'fall',
          title: 'Host',
          credits: 3,
          assignments: [
            Assignment(
              id: 'a1',
              courseId: 'somewhere-else',
              name: 'Foreign',
              weight: 10,
              maximumScore: 10,
            ),
          ],
        ),
        throwsA(isA<InvalidCourseFailure>()),
      );
    });

    test('refuses two assignments sharing one identifier', () {
      Assignment duplicate(String id) => Assignment(
        id: id,
        courseId: '1',
        name: 'Quiz',
        weight: 10,
        maximumScore: 10,
      );

      expect(
        () => Course(
          id: '1',
          semesterId: 'fall',
          title: 'Host',
          credits: 3,
          assignments: [duplicate('a1'), duplicate('a1')],
        ),
        throwsA(isA<InvalidCourseFailure>()),
      );
    });

    test('refuses a grading setup adding up to more than 100', () {
      Assignment half(String id) => Assignment(
        id: id,
        courseId: '1',
        name: 'Half',
        weight: 60,
        maximumScore: 100,
      );

      expect(
        () => Course(
          id: '1',
          semesterId: 'fall',
          title: 'Over budget',
          credits: 3,
          assignments: [half('a1'), half('a2')],
        ),
        throwsA(isA<InvalidCourseFailure>()),
      );
    });

    test('accepts a setup that reads as exactly 100', () {
      Assignment third(String id, double weight) => Assignment(
        id: id,
        courseId: '1',
        name: 'Third',
        weight: weight,
        maximumScore: 100,
      );

      expect(
        () => Course(
          id: '1',
          semesterId: 'fall',
          title: 'Exact',
          credits: 3,
          assignments: [
            third('a1', 33.34),
            third('a2', 33.33),
            third('a3', 33.33),
          ],
        ),
        returnsNormally,
        reason: 'weights are compared as integers, not as binary fractions',
      );
    });
  });

  group('Semester', () {
    test('rejects an empty identifier', () {
      expect(
        () => Semester(id: '', name: 'Fall 2026'),
        throwsA(isA<InvalidSemesterFailure>()),
      );
    });

    test('a blank name is allowed and reported as unnamed', () {
      expect(Semester(id: 's1', name: '  ').hasName, isFalse);
      expect(Semester(id: 's1', name: 'Fall 2026').hasName, isTrue);
    });

    test('orders newest first', () {
      final transcript = Transcript(
        semesters: [
          Semester(id: 'old', name: 'Fall 2025', position: 1),
          Semester(id: 'new', name: 'Fall 2026', position: 2),
        ],
      );

      expect(transcript.orderedSemesters.first.id, 'new');
    });
  });

  group('FourPointScale', () {
    test('rejects a letter it does not define', () {
      expect(() => _scale.byLetter('Z'), throwsA(isA<UnknownGradeFailure>()));
    });

    test('pass does not count toward the average', () {
      expect(_scale.byLetter('P').countsTowardGpa, isFalse);
    });

    test('turns a percentage into the letter its band earns', () {
      expect(_scale.forPercentage(95)!.letter, 'A');
      expect(_scale.forPercentage(90)!.letter, 'A');
      expect(_scale.forPercentage(89.9)!.letter, 'A-');
      expect(_scale.forPercentage(70)!.letter, 'C');
      expect(_scale.forPercentage(0)!.letter, 'F');
    });
  });
}
