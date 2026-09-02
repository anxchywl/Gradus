import 'errors.dart';

// earnedScore is null until marked, an unmarked item is left out, not zeroed
class Assignment {
  Assignment({
    required this.id,
    required this.courseId,
    required this.name,
    required this.weight,
    required this.maximumScore,
    this.earnedScore,
  }) {
    if (id.isEmpty) {
      throw const InvalidAssignmentFailure('assignment_id_empty');
    }
    if (courseId.isEmpty) {
      throw const InvalidAssignmentFailure('assignment_course_empty');
    }
    if (name.trim().isEmpty) {
      throw const InvalidAssignmentFailure('assignment_name_empty');
    }
    if (weight <= 0 || weight > maximumWeight) {
      throw const InvalidAssignmentFailure('assignment_weight_out_of_range');
    }
    if (maximumScore <= 0) {
      throw const InvalidAssignmentFailure('assignment_maximum_out_of_range');
    }
    final earned = earnedScore;
    if (earned != null && (earned < 0 || earned > maximumScore)) {
      throw const InvalidAssignmentFailure('assignment_earned_out_of_range');
    }
  }

  static const double maximumWeight = 100;

  final String id;
  final String courseId;
  final String name;

  final double weight;
  final double maximumScore;
  final double? earnedScore;

  bool get isGraded => earnedScore != null;

  double? get percentage => isGraded ? earnedScore! / maximumScore * 100 : null;

  double? get weightedContribution =>
      isGraded ? percentage! * weight / 100 : null;
}
