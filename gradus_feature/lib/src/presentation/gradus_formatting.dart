import '../domain/course_grade.dart';
import '../domain/semester.dart';
import '../l10n/gradus_strings.dart';

// an em dash is the only honest rendering of a figure that is absent
String formatPercentage(GradusStrings strings, double? value) =>
    value == null ? strings.valueUnavailable : strings.percentValue(value);

String formatGpa(GradusStrings strings, double? value) =>
    value == null ? strings.valueUnavailable : strings.gpaNumber(value);

String formatLetter(GradusStrings strings, CourseGrade resolved) =>
    resolved.grade?.letter ?? strings.valueUnavailable;

// a pass counts as credit without a number behind it
String formatCourseGpa(GradusStrings strings, CourseGrade resolved) =>
    resolved.weighsOnGpa
    ? strings.gpaValue(resolved.grade!.qualityPoints)
    : strings.gpaNone;

// a term carried over from a store with no terms has no name to show
String formatSemester(GradusStrings strings, Semester semester) =>
    semester.hasName ? semester.name : strings.unnamedSemester;

// composites live here, so no screen holds a fragment the ARB files lack
const String _separator = '  ·  ';

String formatCumulativeLine(GradusStrings strings, double? value) =>
    '${strings.cumulativeGpa}  ${formatGpa(strings, value)}';

// each part is labelled, so a row of dashes still says what is missing
String formatCourseMeta(
  GradusStrings strings,
  double credits,
  CourseGrade resolved,
) => [
  strings.creditsValue(credits),
  formatPercentage(strings, resolved.currentPercentage),
  formatCourseGpa(strings, resolved),
].join(_separator);

String formatAssignmentProgress(GradusStrings strings, CourseGrade resolved) =>
    '${strings.assignmentProgress(resolved.gradedCount, resolved.assignmentCount)}'
    '$_separator${strings.gradedWeightLabel} '
    '${strings.weightPercent(resolved.gradedWeight)}';

String formatGradeSource(GradusStrings strings, CourseGrade resolved) =>
    switch (resolved.source) {
      GradeSource.assignments => strings.gradeFromAssignments,
      GradeSource.manual => strings.gradeFromManual,
      GradeSource.none => strings.gradeNotSet,
    };
