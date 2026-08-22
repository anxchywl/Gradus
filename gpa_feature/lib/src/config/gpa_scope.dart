import 'package:flutter/widgets.dart';

import '../application/gpa_controller.dart';
import '../data/in_memory_course_repository.dart';
import '../data/preferences_course_repository.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';
import 'gpa_session.dart';

/// Everything the feature needs from the outside, assembled once.
///
/// This is the only place that knows both a controller and an implementation.
class GpaDependencies {
  const GpaDependencies({required this.courses, required this.scales});

  final CourseRepository courses;
  final GradeScaleRepository scales;
}

/// In-memory only. For tests and for previewing without touching the device.
GpaDependencies createSampleDependencies() => GpaDependencies(
  courses: InMemoryCourseRepository(),
  scales: const StaticGradeScaleRepository(),
);

/// Courses persisted on this device, namespaced to one account.
GpaDependencies createLocalDependencies({
  required String accountId,
  GradeScale scale = const FourPointScale(),
}) => GpaDependencies(
  courses: PreferencesCourseRepository(accountId: accountId, scale: scale),
  scales: StaticGradeScaleRepository(scale),
);

/// Owns the controllers for one mounted session. A new token builds a new
/// scope, so state from one account cannot structurally survive into the next.
class GpaScope extends InheritedWidget {
  GpaScope({
    super.key,
    required this.session,
    required GpaDependencies dependencies,
    required super.child,
  }) : gpa = GpaController(
         courses: dependencies.courses,
         scales: dependencies.scales,
       );

  final GpaSession session;
  final GpaController gpa;

  static GpaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GpaScope>();
    assert(scope != null, 'GpaScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(GpaScope oldWidget) =>
      oldWidget.session.accessToken != session.accessToken;
}
