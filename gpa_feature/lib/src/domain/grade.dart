import 'errors.dart';

/// A grade as the institution records it, paired with the quality points it is
/// worth on a given scale.
class Grade {
  const Grade({
    required this.letter,
    required this.qualityPoints,
    this.countsTowardGpa = true,
  });

  final String letter;
  final double qualityPoints;

  /// Pass/fail and transfer credit sit on a transcript but not in the average.
  final bool countsTowardGpa;

  @override
  bool operator ==(Object other) =>
      other is Grade &&
      other.letter == letter &&
      other.qualityPoints == qualityPoints &&
      other.countsTowardGpa == countsTowardGpa;

  @override
  int get hashCode => Object.hash(letter, qualityPoints, countsTowardGpa);
}

/// The mapping from a letter to quality points.
///
/// This is deliberately an interface. The exact table is an institutional rule
/// that is not settled yet, and hardcoding one would bury a product decision in
/// the domain. See docs/PRODUCT.md.
abstract interface class GradeScale {
  String get id;

  List<Grade> get grades;

  Grade byLetter(String letter);
}

/// A four-point scale, present so the domain is testable and the application
/// layer has something to resolve. It is an example, not a ruling.
class FourPointScale implements GradeScale {
  const FourPointScale();

  @override
  String get id => 'four_point';

  @override
  List<Grade> get grades => const [
    Grade(letter: 'A', qualityPoints: 4.0),
    Grade(letter: 'A-', qualityPoints: 3.67),
    Grade(letter: 'B+', qualityPoints: 3.33),
    Grade(letter: 'B', qualityPoints: 3.0),
    Grade(letter: 'B-', qualityPoints: 2.67),
    Grade(letter: 'C+', qualityPoints: 2.33),
    Grade(letter: 'C', qualityPoints: 2.0),
    Grade(letter: 'C-', qualityPoints: 1.67),
    Grade(letter: 'D+', qualityPoints: 1.33),
    Grade(letter: 'D', qualityPoints: 1.0),
    Grade(letter: 'F', qualityPoints: 0.0),
    Grade(letter: 'P', qualityPoints: 0.0, countsTowardGpa: false),
  ];

  @override
  Grade byLetter(String letter) {
    for (final grade in grades) {
      if (grade.letter == letter) return grade;
    }
    throw UnknownGradeFailure(letter);
  }
}
