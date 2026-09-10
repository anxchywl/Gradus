import 'errors.dart';

class Grade {
  const Grade({
    required this.letter,
    required this.qualityPoints,
    this.countsTowardGpa = true,
    this.countsAsAttemptedCredit = true,
  });

  final String letter;
  final double qualityPoints;

  // pass/fail and transfer credit sit on a transcript but not in the average
  final bool countsTowardGpa;

  // an audit, an incomplete and a withdrawal are not credit the student
  // attempted either, so they sit outside both figures rather than only the
  // average
  final bool countsAsAttemptedCredit;

  @override
  bool operator ==(Object other) =>
      other is Grade &&
      other.letter == letter &&
      other.qualityPoints == qualityPoints &&
      other.countsTowardGpa == countsTowardGpa &&
      other.countsAsAttemptedCredit == countsAsAttemptedCredit;

  @override
  int get hashCode => Object.hash(
    letter,
    qualityPoints,
    countsTowardGpa,
    countsAsAttemptedCredit,
  );
}

class GradeBand {
  const GradeBand({required this.grade, required this.minimumPercentage});

  final Grade grade;
  final double minimumPercentage;
}

// an interface because a second institution would bring a second table, and
// because a scale that declines to map percentages must stay expressible
abstract interface class GradeScale {
  String get id;

  List<Grade> get grades;

  // empty when the scale cannot turn a percentage into a letter
  List<GradeBand> get bands;

  Grade byLetter(String letter);

  Grade? forPercentage(double percentage);
}

// nu's common grading scale: the points are the registrar's, and the bands are
// the ones the course specification form prints, agreeing across every syllabus
// in backend/evals. see docs/PRODUCT.md for what is still faculty discretion
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
    // a pass is credit earned, it just carries no points into the average
    Grade(letter: 'P', qualityPoints: 0.0, countsTowardGpa: false),
    // nu's administrative grades: no points, and no attempted credit either
    Grade(
      letter: 'AU',
      qualityPoints: 0.0,
      countsTowardGpa: false,
      countsAsAttemptedCredit: false,
    ),
    Grade(
      letter: 'I',
      qualityPoints: 0.0,
      countsTowardGpa: false,
      countsAsAttemptedCredit: false,
    ),
    Grade(
      letter: 'IP',
      qualityPoints: 0.0,
      countsTowardGpa: false,
      countsAsAttemptedCredit: false,
    ),
    Grade(
      letter: 'W',
      qualityPoints: 0.0,
      countsTowardGpa: false,
      countsAsAttemptedCredit: false,
    ),
    Grade(
      letter: 'AW',
      qualityPoints: 0.0,
      countsTowardGpa: false,
      countsAsAttemptedCredit: false,
    ),
  ];

  @override
  List<GradeBand> get bands => const [
    GradeBand(
      grade: Grade(letter: 'A', qualityPoints: 4.0),
      minimumPercentage: 95,
    ),
    GradeBand(
      grade: Grade(letter: 'A-', qualityPoints: 3.67),
      minimumPercentage: 90,
    ),
    GradeBand(
      grade: Grade(letter: 'B+', qualityPoints: 3.33),
      minimumPercentage: 85,
    ),
    GradeBand(
      grade: Grade(letter: 'B', qualityPoints: 3.0),
      minimumPercentage: 80,
    ),
    GradeBand(
      grade: Grade(letter: 'B-', qualityPoints: 2.67),
      minimumPercentage: 75,
    ),
    GradeBand(
      grade: Grade(letter: 'C+', qualityPoints: 2.33),
      minimumPercentage: 70,
    ),
    GradeBand(
      grade: Grade(letter: 'C', qualityPoints: 2.0),
      minimumPercentage: 65,
    ),
    GradeBand(
      grade: Grade(letter: 'C-', qualityPoints: 1.67),
      minimumPercentage: 60,
    ),
    GradeBand(
      grade: Grade(letter: 'D+', qualityPoints: 1.33),
      minimumPercentage: 55,
    ),
    GradeBand(
      grade: Grade(letter: 'D', qualityPoints: 1.0),
      minimumPercentage: 50,
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
