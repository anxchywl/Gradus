import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';

const _scale = FourPointScale();

Assignment _assignment({
  required String id,
  required double weight,
  double maximumScore = 100,
  double? earnedScore,
}) => Assignment(
  id: id,
  courseId: 'c1',
  name: 'Item $id',
  weight: weight,
  maximumScore: maximumScore,
  earnedScore: earnedScore,
);

Course _course(List<Assignment> assignments, {Grade? grade}) => Course(
  id: 'c1',
  semesterId: 'fall',
  title: 'Programming Languages',
  credits: 3,
  grade: grade,
  assignments: assignments,
);

void main() {
  group('assignment arithmetic', () {
    test('a percentage is what was scored out of what could be', () {
      expect(
        _assignment(
          id: 'a',
          weight: 25,
          maximumScore: 40,
          earnedScore: 30,
        ).percentage,
        75,
      );
    });

    test('a contribution is the percentage scaled by the weight', () {
      expect(
        _assignment(
          id: 'a',
          weight: 25,
          maximumScore: 100,
          earnedScore: 80,
        ).weightedContribution,
        20,
      );
    });

    test('an unmarked assignment has neither', () {
      final assignment = _assignment(id: 'a', weight: 25);
      expect(assignment.isGraded, isFalse);
      expect(assignment.percentage, isNull);
      expect(assignment.weightedContribution, isNull);
    });
  });

  group('assignment validation', () {
    test('rejects a weight of zero or below', () {
      expect(
        () => _assignment(id: 'a', weight: 0),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
      expect(
        () => _assignment(id: 'a', weight: -5),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
    });

    test('rejects a weight above 100', () {
      expect(
        () => _assignment(id: 'a', weight: 101),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
    });

    test('rejects a maximum score of zero or below', () {
      expect(
        () => _assignment(id: 'a', weight: 10, maximumScore: 0),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
      expect(
        () => _assignment(id: 'a', weight: 10, maximumScore: -1),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
    });

    test('rejects an earned score below zero', () {
      expect(
        () => _assignment(id: 'a', weight: 10, earnedScore: -1),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
    });

    test('rejects an earned score above the maximum', () {
      expect(
        () =>
            _assignment(id: 'a', weight: 10, maximumScore: 50, earnedScore: 51),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
    });

    test('accepts the two ends of the range', () {
      expect(
        () =>
            _assignment(id: 'a', weight: 10, maximumScore: 50, earnedScore: 0),
        returnsNormally,
      );
      expect(
        () =>
            _assignment(id: 'a', weight: 10, maximumScore: 50, earnedScore: 50),
        returnsNormally,
      );
    });

    test('rejects a blank name', () {
      expect(
        () => Assignment(
          id: 'a',
          courseId: 'c1',
          name: '  ',
          weight: 10,
          maximumScore: 10,
        ),
        throwsA(isA<InvalidAssignmentFailure>()),
      );
    });
  });

  group('calculateCourseGrade', () {
    test('a course with no assignments has no percentage', () {
      final resolved = calculateCourseGrade(_course(const []), _scale);
      expect(resolved.currentPercentage, isNull);
      expect(resolved.maximumPossiblePercentage, isNull);
      expect(resolved.hasGradedWork, isFalse);
      expect(resolved.isSetupComplete, isFalse);
    });

    test('assignments with no marks yet give no percentage, not a zero', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 50),
          _assignment(id: 'b', weight: 50),
        ]),
        _scale,
      );

      expect(resolved.currentPercentage, isNull);
      expect(resolved.earnedPercentage, 0);
      expect(resolved.gradedWeight, 0);
      expect(resolved.grade, isNull);
      expect(resolved.source, GradeSource.none);
    });

    test('a partially marked course averages only what was marked', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 25, earnedScore: 80),
          _assignment(id: 'b', weight: 75),
        ]),
        _scale,
      );

      expect(
        resolved.currentPercentage,
        80,
        reason: 'the unmarked 75% must not drag the average to 20',
      );
      expect(resolved.earnedPercentage, 20);
      expect(resolved.gradedWeight, 25);
      expect(resolved.gradedCount, 1);
      expect(resolved.assignmentCount, 2);
    });

    test('a fully marked course banks its whole grade', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 40, earnedScore: 90),
          _assignment(id: 'b', weight: 60, earnedScore: 80),
        ]),
        _scale,
      );

      expect(resolved.currentPercentage, closeTo(84, 1e-9));
      expect(resolved.earnedPercentage, closeTo(84, 1e-9));
      expect(resolved.isSetupComplete, isTrue);
      expect(resolved.unallocatedWeight, 0);
      expect(resolved.grade!.letter, 'B');
      expect(resolved.source, GradeSource.assignments);
    });

    test('an incomplete setup reports what is unallocated', () {
      final resolved = calculateCourseGrade(
        _course([_assignment(id: 'a', weight: 70, earnedScore: 90)]),
        _scale,
      );

      expect(resolved.configuredWeight, 70);
      expect(resolved.unallocatedWeight, 30);
      expect(resolved.isSetupComplete, isFalse);
    });

    test('a setup that reads as 100 is complete despite the fractions', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 33.34),
          _assignment(id: 'b', weight: 33.33),
          _assignment(id: 'c', weight: 33.33),
        ]),
        _scale,
      );

      expect(resolved.isSetupComplete, isTrue);
      expect(resolved.unallocatedWeight, 0);
    });

    test('the maximum possible assumes full marks on the rest', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 30, earnedScore: 50),
          _assignment(id: 'b', weight: 70),
        ]),
        _scale,
      );

      expect(resolved.earnedPercentage, 15);
      expect(resolved.maximumPossiblePercentage, 85);
    });

    test('an unallocated remainder still counts toward the maximum', () {
      final resolved = calculateCourseGrade(
        _course([_assignment(id: 'a', weight: 40, earnedScore: 100)]),
        _scale,
      );

      expect(resolved.earnedPercentage, 40);
      expect(
        resolved.maximumPossiblePercentage,
        100,
        reason: 'the 60 that was never allocated is still winnable',
      );
    });

    test('a marked assignment overrides a letter typed by hand', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 100, earnedScore: 65),
        ], grade: const Grade(letter: 'A', qualityPoints: 4)),
        _scale,
      );

      expect(resolved.grade!.letter, 'C');
      expect(resolved.source, GradeSource.assignments);
    });

    test('a withdrawal stands over work that was marked before it', () {
      final resolved = calculateCourseGrade(
        _course(
          [_assignment(id: 'a', weight: 100, earnedScore: 65)],
          grade: const Grade(
            letter: 'W',
            qualityPoints: 0,
            countsTowardGpa: false,
            countsAsAttemptedCredit: false,
          ),
        ),
        _scale,
      );

      // a student who sat a midterm and then withdrew has a W, not a C+
      expect(resolved.grade!.letter, 'W');
      expect(resolved.source, GradeSource.manual);
      expect(resolved.isAttempted, isFalse);
      expect(resolved.weighsOnGpa, isFalse);
    });

    test('a pass stands over the percentage that would have been a letter', () {
      final resolved = calculateCourseGrade(
        _course(
          [_assignment(id: 'a', weight: 100, earnedScore: 88)],
          grade: const Grade(
            letter: 'P',
            qualityPoints: 0,
            countsTowardGpa: false,
          ),
        ),
        _scale,
      );

      // a pass/fail course reports a pass whatever the percentage came to
      expect(resolved.grade!.letter, 'P');
      expect(resolved.isAttempted, isTrue, reason: 'a pass is still credit');
      expect(resolved.weighsOnGpa, isFalse);
      expect(resolved.currentPercentage, 88);
    });

    test('a letter typed by hand stands when nothing is marked', () {
      final resolved = calculateCourseGrade(
        _course([
          _assignment(id: 'a', weight: 100),
        ], grade: const Grade(letter: 'A', qualityPoints: 4)),
        _scale,
      );

      expect(resolved.grade!.letter, 'A');
      expect(resolved.source, GradeSource.manual);
      expect(resolved.weighsOnGpa, isTrue);
    });

    test('a manual pass counts as attempted, exactly as it always did', () {
      final resolved = calculateCourseGrade(
        _course(
          const [],
          grade: const Grade(
            letter: 'P',
            qualityPoints: 0,
            countsTowardGpa: false,
          ),
        ),
        _scale,
      );

      expect(resolved.isAttempted, isTrue);
      expect(resolved.weighsOnGpa, isFalse);
    });

    test('a zero mark is a real result, not an absent one', () {
      final resolved = calculateCourseGrade(
        _course([_assignment(id: 'a', weight: 100, earnedScore: 0)]),
        _scale,
      );

      expect(resolved.currentPercentage, 0);
      expect(resolved.grade!.letter, 'F');
      expect(resolved.weighsOnGpa, isTrue);
    });
  });
}
