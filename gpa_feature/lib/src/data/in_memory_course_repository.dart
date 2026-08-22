import '../domain/course.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';

/// Development and test double. Selected by configuration, never the default in
/// a build that leaves a development machine.
class InMemoryCourseRepository implements CourseRepository {
  InMemoryCourseRepository([List<Course>? seed]) : _courses = seed ?? const [];

  List<Course> _courses;

  @override
  Future<List<Course>> load() async => _courses;

  @override
  Future<void> save(List<Course> courses) async => _courses = courses;
}

class StaticGradeScaleRepository implements GradeScaleRepository {
  const StaticGradeScaleRepository([this._scale = const FourPointScale()]);

  final GradeScale _scale;

  @override
  Future<GradeScale> active() async => _scale;
}
