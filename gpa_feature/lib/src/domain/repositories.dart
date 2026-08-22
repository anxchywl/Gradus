import 'course.dart';
import 'grade.dart';

/// Implemented under `data/`. Nothing above this layer may name an
/// implementation; a boundary test enforces that.
abstract interface class CourseRepository {
  Future<List<Course>> load();

  Future<void> save(List<Course> courses);
}

abstract interface class GradeScaleRepository {
  Future<GradeScale> active();
}
