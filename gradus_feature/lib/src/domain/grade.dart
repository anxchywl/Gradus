import 'errors.dart';

class Grade {
  const Grade({
    required this.letter,
    required this.qualityPoints,
    this.countsTowardGpa = true,
  });

  final String letter;
  final double qualityPoints;

  // pass/fail and transfer credit sit on a transcript but not in the average
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

class GradeBand {
  const GradeBand({required this.grade, required this.minimumPercentage});

  final Grade grade;
  final double minimumPercentage;
}

// an interface because neither table is settled, see docs/PRODUCT.md
abstract interface class GradeScale {
  String get id;

  List<Grade> get grades;

  // empty when the scale cannot turn a percentage into a letter
  List<GradeBand> get bands;

  Grade byLetter(String letter);

  Grade? forPercentage(double percentage);
}

// an example so the domain is testable, not a ruling on any real scale
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
  List<GradeBand> get bands => const [
    GradeBand(
      grade: Grade(letter: 'A', qualityPoints: 4.0),
      minimumPercentage: 90,
    ),
    GradeBand(
      grade: Grade(letter: 'A-', qualityPoints: 3.67),
      minimumPercentage: 87,
    ),
    GradeBand(
      grade: Grade(letter: 'B+', qualityPoints: 3.33),
      minimumPercentage: 83,
    ),
    GradeBand(
      grade: Grade(letter: 'B', qualityPoints: 3.0),
      minimumPercentage: 80,
    ),
    GradeBand(
      grade: Grade(letter: 'B-', qualityPoints: 2.67),
      minimumPercentage: 77,
    ),
    GradeBand(
      grade: Grade(letter: 'C+', qualityPoints: 2.33),
      minimumPercentage: 73,
    ),
    GradeBand(
      grade: Grade(letter: 'C', qualityPoints: 2.0),
      minimumPercentage: 70,
    ),
    GradeBand(
      grade: Grade(letter: 'C-', qualityPoints: 1.67),
      minimumPercentage: 67,
    ),
    GradeBand(
      grade: Grade(letter: 'D+', qualityPoints: 1.33),
      minimumPercentage: 63,
    ),
    GradeBand(
      grade: Grade(letter: 'D', qualityPoints: 1.0),
      minimumPercentage: 60,
    ),
    GradeBand(
      grade: Grade(letter: 'F', qualityPoints: 0.0),
      minimumPercentage: 0,
    ),
  ];

  @override
  Grade byLetter(String letter) {
    for (final grade in grades) {
      if (grade.letter == letter) return grade;
    }
    throw UnknownGradeFailure(letter);
  }

  @override
  Grade? forPercentage(double percentage) {
    for (final band in bands) {
      if (percentage >= band.minimumPercentage) return band.grade;
    }
    return null;
  }
}
