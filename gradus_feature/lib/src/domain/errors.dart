sealed class GradusFailure implements Exception {
  const GradusFailure(this.code);

  final String code;
}

class InvalidCourseFailure extends GradusFailure {
  const InvalidCourseFailure(super.code);
}

class InvalidSemesterFailure extends GradusFailure {
  const InvalidSemesterFailure(super.code);
}

class InvalidAssignmentFailure extends GradusFailure {
  const InvalidAssignmentFailure(super.code);
}

// deleting a semester would take its courses with it
class SemesterNotEmptyFailure extends GradusFailure {
  const SemesterNotEmptyFailure() : super('semester_not_empty');
}

class UnknownGradeFailure extends GradusFailure {
  const UnknownGradeFailure(this.letter) : super('grade_unknown');

  final String letter;
}

// the student is told which of these happened, so a refusal is never silent
enum SyllabusImportProblem {
  notAPdf,
  tooLarge,
  encrypted,
  noText,
  nothingFound,
  rateLimited,
  unavailable,
  network,
}

class SyllabusImportFailure extends GradusFailure {
  const SyllabusImportFailure(this.problem) : super('syllabus_import_failed');

  final SyllabusImportProblem problem;
}
