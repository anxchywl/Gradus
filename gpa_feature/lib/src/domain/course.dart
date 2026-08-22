import 'errors.dart';
import 'grade.dart';

/// One enrolled course. Credits are the weight; a course without a grade is
/// in progress and carries no weight yet.
class Course {
  Course({
    required this.id,
    required this.title,
    required this.credits,
    this.grade,
  }) {
    if (id.isEmpty) {
      throw const InvalidCourseFailure('course_id_empty');
    }
    if (title.trim().isEmpty) {
      throw const InvalidCourseFailure('course_title_empty');
    }
    if (credits <= 0 || credits > maximumCredits) {
      throw const InvalidCourseFailure('course_credits_out_of_range');
    }
  }

  static const double maximumCredits = 24;

  final String id;
  final String title;
  final double credits;
  final Grade? grade;

  bool get isGraded => grade != null;

  /// In progress, pass/fail and transfer credit are all on the transcript but
  /// outside the average.
  bool get weighsOnGpa => grade?.countsTowardGpa ?? false;

  Course copyWith({String? title, double? credits, Grade? grade}) => Course(
    id: id,
    title: title ?? this.title,
    credits: credits ?? this.credits,
    grade: grade ?? this.grade,
  );
}
