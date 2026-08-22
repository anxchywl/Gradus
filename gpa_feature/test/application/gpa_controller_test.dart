import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_feature/gpa_feature.dart';
import 'package:gpa_feature/src/application/gpa_controller.dart';
import 'package:gpa_feature/src/domain/repositories.dart';

class _FakeCourseRepository implements CourseRepository {
  _FakeCourseRepository({this.courses = const [], this.failure});

  List<Course> courses;
  Object? failure;
  Completer<void>? gate;

  @override
  Future<List<Course>> load() async {
    if (gate != null) await gate!.future;
    if (failure != null) throw Exception(failure.toString());
    return courses;
  }

  @override
  Future<void> save(List<Course> next) async => courses = next;
}

Course _course(String id, double credits, Grade grade) =>
    Course(id: id, title: 'Course $id', credits: credits, grade: grade);

const _a = Grade(letter: 'A', qualityPoints: 4);

void main() {
  test('a load computes the average from what came back', () async {
    final controller = GpaController(
      courses: _FakeCourseRepository(courses: [_course('1', 3, _a)]),
    );

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.result.value, 4.0);
    expect(controller.entries, hasLength(1));
  });

  test('a failure is surfaced rather than swallowed', () async {
    final controller = GpaController(
      courses: _FakeCourseRepository(failure: 'network down'),
    );

    await controller.load();

    expect(controller.failure, isNotNull);
    expect(controller.isLoading, isFalse);
    expect(controller.result.isDefined, isFalse);
  });

  test('entries cannot be mutated through the getter', () {
    final controller = GpaController(courses: _FakeCourseRepository());
    expect(
      () => controller.entries.add(_course('1', 3, _a)),
      throwsUnsupportedError,
    );
  });

  test('reset discards everything belonging to the previous account', () async {
    final controller = GpaController(
      courses: _FakeCourseRepository(courses: [_course('1', 3, _a)]),
    );
    await controller.load();
    expect(controller.entries, isNotEmpty);

    controller.reset();

    expect(controller.entries, isEmpty);
    expect(controller.result.isDefined, isFalse);
    expect(controller.failure, isNull);
  });

  test('a result in flight when the account changed is discarded', () async {
    final repository = _FakeCourseRepository(courses: [_course('1', 3, _a)]);
    repository.gate = Completer<void>();
    final controller = GpaController(courses: repository);

    final pending = controller.load();
    // the account changes while the first load is still outstanding
    controller.reset();
    repository.gate!.complete();
    await pending;

    expect(
      controller.entries,
      isEmpty,
      reason: 'a superseded response must not write into the new account',
    );
    expect(controller.result.isDefined, isFalse);
  });

  test('a failure in flight when the account changed is discarded', () async {
    final repository = _FakeCourseRepository(failure: 'network down');
    repository.gate = Completer<void>();
    final controller = GpaController(courses: repository);

    final pending = controller.load();
    controller.reset();
    repository.gate!.complete();
    await pending;

    expect(controller.failure, isNull);
  });
}
