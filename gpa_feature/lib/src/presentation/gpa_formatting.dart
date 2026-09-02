import '../domain/course_grade.dart';
import '../domain/semester.dart';
import '../l10n/gpa_strings.dart';

// an em dash is the only honest rendering of a figure that is absent
String formatPercentage(GpaStrings strings, double? value) =>
    value == null ? strings.valueUnavailable : strings.percentValue(value);

String formatGpa(GpaStrings strings, double? value) =>
    value == null ? strings.valueUnavailable : strings.gpaNumber(value);

String formatLetter(GpaStrings strings, CourseGrade resolved) =>
    resolved.grade?.letter ?? strings.valueUnavailable;

// a pass counts as credit without a number behind it
String formatCourseGpa(GpaStrings strings, CourseGrade resolved) =>
    resolved.weighsOnGpa
    ? strings.gpaValue(resolved.grade!.qualityPoints)
    : strings.gpaNone;

// a term carried over from a store with no terms has no name to show
String formatSemester(GpaStrings strings, Semester semester) =>
    semester.hasName ? semester.name : strings.unnamedSemester;

// composites live here, so no screen holds a fragment the ARB files lack
const String _separator = '  ·  ';

String formatCumulativeLine(GpaStrings strings, double? value) =>
    '${strings.cumulativeGpa}  ${formatGpa(strings, value)}';

// each part is labelled, so a row of dashes still says what is missing
String formatCourseMeta(
  GpaStrings strings,
  double credits,
  CourseGrade resolved,
) => [
  strings.creditsValue(credits),
  formatPercentage(strings, resolved.currentPercentage),
  formatCourseGpa(strings, resolved),
].join(_separator);

String formatAssignmentProgress(GpaStrings strings, CourseGrade resolved) =>
    '${strings.assignmentProgress(resolved.gradedCount, resolved.assignmentCount)}'
    '$_separator${strings.gradedWeightLabel} '
    '${strings.weightPercent(resolved.gradedWeight)}';

String formatGradeSource(GpaStrings strings, CourseGrade resolved) =>
    switch (resolved.source) {
      GradeSource.assignments => strings.gradeFromAssignments,
      GradeSource.manual => strings.gradeFromManual,
      GradeSource.none => strings.gradeNotSet,
    };
