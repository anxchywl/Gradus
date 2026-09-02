import 'assignment.dart';
import 'errors.dart';
import 'grade.dart';
import 'weights.dart';

// a pass/fail course says it about itself, so it needs no letter to be honest
enum GradingMode { graded, passFail }

class Course {
  Course({
    required this.id,
    required this.semesterId,
    required this.title,
    required this.credits,
    this.code = '',
    this.grade,
    this.gradingMode = GradingMode.graded,
    this.includeInGpa = true,
    this.assignments = const [],
  }) {
    if (id.isEmpty) {
      throw const InvalidCourseFailure('course_id_empty');
    }
    if (semesterId.isEmpty) {
      throw const InvalidCourseFailure('course_semester_empty');
    }
    if (title.trim().isEmpty) {
      throw const InvalidCourseFailure('course_title_empty');
    }
    if (credits <= 0 || credits > maximumCredits) {
      throw const InvalidCourseFailure('course_credits_out_of_range');
    }

    final seen = <String>{};
    for (final assignment in assignments) {
      // two courses reaching one assignment would let an edit cross over
      if (assignment.courseId != id) {
        throw const InvalidCourseFailure('course_assignment_foreign');
      }
      if (!seen.add(assignment.id)) {
        throw const InvalidCourseFailure('course_assignment_duplicate');
      }
    }

    if (sumHundredths(assignments.map((a) => a.weight)) > completeWeight) {
      throw const InvalidCourseFailure('course_weight_over_budget');
    }
  }

  static const double maximumCredits = 24;

  final String id;
  final String semesterId;

  final String code;
  final String title;
  final double credits;

  // still the source for courses entered before assignments existed
  final Grade? grade;
  final GradingMode gradingMode;

  final bool includeInGpa;
  final List<Assignment> assignments;

  bool get isEligibleForGpa =>
      includeInGpa && gradingMode == GradingMode.graded;

  Course copyWith({
    String? semesterId,
    String? code,
    String? title,
    double? credits,
    Grade? grade,
    GradingMode? gradingMode,
    bool? includeInGpa,
    List<Assignment>? assignments,
  }) => Course(
    id: id,
    semesterId: semesterId ?? this.semesterId,
    code: code ?? this.code,
    title: title ?? this.title,
    credits: credits ?? this.credits,
    grade: grade ?? this.grade,
    gradingMode: gradingMode ?? this.gradingMode,
    includeInGpa: includeInGpa ?? this.includeInGpa,
    assignments: assignments ?? this.assignments,
  );
}
