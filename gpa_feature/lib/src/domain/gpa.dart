import 'course.dart';

/// The result of averaging a set of courses.
///
/// [attemptedCredits] counts everything with a grade; [qualityCredits] counts
/// only what the average is actually computed over. They differ whenever a
/// pass/fail course is present, and showing both is what stops a student
/// thinking the calculator lost their credits.
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

  /// Null when nothing counts yet. Zero is a real GPA; absence is not.
  final double? value;
  final double qualityCredits;
  final double attemptedCredits;

  bool get isDefined => value != null;
}

/// Credit-weighted average over the courses that count.
GpaResult calculateGpa(Iterable<Course> courses) {
  var weightedPoints = 0.0;
  var qualityCredits = 0.0;
  var attemptedCredits = 0.0;

  for (final course in courses) {
    if (!course.isGraded) continue;
    attemptedCredits += course.credits;
    if (!course.weighsOnGpa) continue;
    weightedPoints += course.credits * course.grade!.qualityPoints;
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
