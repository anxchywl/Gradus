import '../domain/assignment.dart';
import '../domain/course_grade.dart';
import '../domain/gpa.dart';
import '../domain/semester.dart';
import '../l10n/gradus_strings.dart';

// an em dash is the only honest rendering of a figure that is absent
String formatPercentage(GradusStrings strings, double? value) =>
    value == null ? strings.valueUnavailable : strings.percentValue(value);

String formatGpa(GradusStrings strings, double? value) =>
    value == null ? strings.valueUnavailable : strings.gpaNumber(value);

String formatLetter(GradusStrings strings, CourseGrade resolved) =>
    resolved.grade?.letter ?? strings.valueUnavailable;

// a term carried over from a store with no terms has no name to show
String formatSemester(GradusStrings strings, Semester semester) =>
    semester.hasName ? semester.name : strings.unnamedSemester;

// a term header carries the two figures the summary card would show for it
String formatSemesterTotals(GradusStrings strings, GpaResult result) => [
  if (result.isDefined) strings.gpaValue(result.value!),
  strings.creditsCount(result.attemptedCredits),
].join('  |  ');

// the mark beside the percentage, so a reader sees what produced it
String formatAssignmentScore(GradusStrings strings, Assignment assignment) =>
    assignment.isGraded
    ? strings.scoreOutOf(assignment.earnedScore!, assignment.maximumScore)
    : strings.valueUnavailable;

// a syllabus states weights, never a maximum score, so every imported entry
// starts out of one hundred and unmarked
const double importedMaximumScore = 100;

// the credits field is typed into, so an imported value arrives as text the
// student can correct, without a trailing zero they did not write
String formatImportedCredits(double credits) =>
    credits == credits.roundToDouble()
    ? credits.toStringAsFixed(0)
    : credits.toString();
