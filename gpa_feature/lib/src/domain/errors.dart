sealed class GpaFailure implements Exception {
  const GpaFailure(this.code);

  final String code;
}

class InvalidCourseFailure extends GpaFailure {
  const InvalidCourseFailure(super.code);
}

class InvalidSemesterFailure extends GpaFailure {
  const InvalidSemesterFailure(super.code);
}

class InvalidAssignmentFailure extends GpaFailure {
  const InvalidAssignmentFailure(super.code);
}

// deleting a semester would take its courses with it
class SemesterNotEmptyFailure extends GpaFailure {
  const SemesterNotEmptyFailure() : super('semester_not_empty');
}

class UnknownGradeFailure extends GpaFailure {
  const UnknownGradeFailure(this.letter) : super('grade_unknown');

  final String letter;
}
