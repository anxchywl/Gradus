import 'course.dart';
import 'grade.dart';
import 'weights.dart';

// shown rather than hidden, a student should see which grade the average uses
enum GradeSource { none, manual, assignments }

// current is over marked work, earned is how much of the final grade is held
class CourseGrade {
  const CourseGrade({
    required this.grade,
    required this.source,
    required this.currentPercentage,
    required this.earnedPercentage,
    required this.gradedWeight,
    required this.configuredWeight,
    required this.assignmentCount,
    required this.gradedCount,
    required this.weighsOnGpa,
    required this.isAttempted,
  });

  final Grade? grade;
  final GradeSource source;

  final double? currentPercentage;

  final double earnedPercentage;

  final double gradedWeight;

  final double configuredWeight;

  final int assignmentCount;
  final int gradedCount;

  final bool weighsOnGpa;

  final bool isAttempted;

  double get remainingWeight => configuredWeight - gradedWeight;

  // a setup that adds up to 70 leaves 30 unexplained, and saying so matters
  double get unallocatedWeight =>
      fromHundredths(completeWeight - toHundredths(configuredWeight));

  bool get isSetupComplete =>
      assignmentCount > 0 && toHundredths(configuredWeight) == completeWeight;

  bool get hasGradedWork => gradedCount > 0;

  double? get maximumPossiblePercentage => assignmentCount == 0
      ? null
      : earnedPercentage +
            fromHundredths(completeWeight - toHundredths(gradedWeight));
}

// the only place a course turns into a letter, so the rules live in one spot
CourseGrade calculateCourseGrade(Course course, GradeScale scale) {
  var earnedPercentage = 0.0;
  var gradedHundredths = 0;
  var gradedCount = 0;

  for (final assignment in course.assignments) {
    if (!assignment.isGraded) continue;
    earnedPercentage += assignment.weightedContribution!;
    gradedHundredths += toHundredths(assignment.weight);
    gradedCount++;
  }

  final gradedWeight = fromHundredths(gradedHundredths);
  final configuredWeight = fromHundredths(
    sumHundredths(course.assignments.map((a) => a.weight)),
  );

  // unmarked work is out of the denominator, so it neither helps nor hurts
  final currentPercentage = gradedCount == 0
      ? null
      : earnedPercentage / gradedWeight * 100;

  var source = GradeSource.none;
  Grade? grade;
  if (currentPercentage != null) {
    grade = scale.forPercentage(currentPercentage);
    if (grade != null) source = GradeSource.assignments;
  }
  if (grade == null && course.grade != null) {
    grade = course.grade;
    source = GradeSource.manual;
  }

  final hasOutcome = grade != null || gradedCount > 0;
  final isAttempted = course.includeInGpa && hasOutcome;
  final weighsOnGpa =
      isAttempted &&
      course.isEligibleForGpa &&
      (grade?.countsTowardGpa ?? false);

  return CourseGrade(
    grade: grade,
    source: source,
    currentPercentage: currentPercentage,
    earnedPercentage: earnedPercentage,
    gradedWeight: gradedWeight,
    configuredWeight: configuredWeight,
    assignmentCount: course.assignments.length,
    gradedCount: gradedCount,
    weighsOnGpa: weighsOnGpa,
    isAttempted: isAttempted,
  );
}
