import 'course.dart';
import 'course_grade.dart';
import 'grade.dart';

// attempted counts every result, quality only what the average uses
class GpaResult {
  const GpaResult({
    required this.value,
    required this.qualityCredits,
    required this.attemptedCredits,
  });

  static const GpaResult empty = GpaResult(
    value: null,
    qualityCredits: 0,
    attemptedCredits: 0,
  );

  // zero is a real gpa, absence is not
  final double? value;
  final double qualityCredits;
  final double attemptedCredits;

  bool get isDefined => value != null;
}

// a course may reach its letter through assignments, hence the scale
GpaResult calculateGpa(Iterable<Course> courses, GradeScale scale) {
  var weightedPoints = 0.0;
  var qualityCredits = 0.0;
  var attemptedCredits = 0.0;

  for (final course in courses) {
    final resolved = calculateCourseGrade(course, scale);
    if (!resolved.isAttempted) continue;
    attemptedCredits += course.credits;
    if (!resolved.weighsOnGpa) continue;
    weightedPoints += course.credits * resolved.grade!.qualityPoints;
    qualityCredits += course.credits;
  }

  if (qualityCredits == 0) {
    return GpaResult(
      value: null,
      qualityCredits: 0,
      attemptedCredits: attemptedCredits,
    );
  }

  return GpaResult(
    value: weightedPoints / qualityCredits,
    qualityCredits: qualityCredits,
    attemptedCredits: attemptedCredits,
  );
}
