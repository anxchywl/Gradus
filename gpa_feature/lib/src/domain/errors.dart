/// Failures the domain can describe without knowing how they are shown.
sealed class GpaFailure implements Exception {
  const GpaFailure(this.code);

  final String code;
}

class InvalidCourseFailure extends GpaFailure {
  const InvalidCourseFailure(super.code);
}

class UnknownGradeFailure extends GpaFailure {
  const UnknownGradeFailure(this.letter) : super('grade_unknown');

  final String letter;
}
