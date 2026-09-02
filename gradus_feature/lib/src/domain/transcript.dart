import 'course.dart';
import 'semester.dart';

// loaded and written whole, so a delete cannot leave a dangling semester
class Transcript {
  const Transcript({this.semesters = const [], this.courses = const []});

  static const Transcript empty = Transcript();

  final List<Semester> semesters;
  final List<Course> courses;

  List<Course> coursesIn(String semesterId) => [
    for (final course in courses)
      if (course.semesterId == semesterId) course,
  ];

  List<Semester> get orderedSemesters =>
      [...semesters]..sort((a, b) => b.position.compareTo(a.position));

  Transcript copyWith({List<Semester>? semesters, List<Course>? courses}) =>
      Transcript(
        semesters: semesters ?? this.semesters,
        courses: courses ?? this.courses,
      );
}
