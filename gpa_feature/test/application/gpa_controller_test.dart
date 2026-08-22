import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_feature/gpa_feature.dart';
import 'package:gpa_feature/src/application/gpa_controller.dart';
import 'package:gpa_feature/src/domain/repositories.dart';

class _FakeCourseRepository implements CourseRepository {
  _FakeCourseRepository({this.courses = const [], this.failure});

  List<Course> courses;
  Object? failure;
  Object? saveFailure;
  Completer<void>? gate;
  int saveCount = 0;

  @override
  Future<List<Course>> load() async {
    if (gate != null) await gate!.future;
    if (failure != null) throw Exception(failure.toString());
    return courses;
  }

  @override
  Future<void> save(List<Course> next) async {
    saveCount++;
    if (saveFailure != null) throw Exception(saveFailure.toString());
    courses = next;
  }
}

class _FakeScales implements GradeScaleRepository {
  const _FakeScales();

  @override
  Future<GradeScale> active() async => const FourPointScale();
}

Course _course(String id, double credits, [Grade? grade]) =>
    Course(id: id, title: 'Course $id', credits: credits, grade: grade ?? _a);

const _a = Grade(letter: 'A', qualityPoints: 4);
const _b = Grade(letter: 'B', qualityPoints: 3);

GpaController _controller(_FakeCourseRepository repository) =>
    GpaController(courses: repository, scales: const _FakeScales());

void main() {
  group('load', () {
    test('computes the average from what came back', () async {
      final controller = _controller(
        _FakeCourseRepository(courses: [_course('1', 3)]),
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.result.value, 4.0);
      expect(controller.entries, hasLength(1));
      expect(controller.scale, isNotNull);
    });

    test('surfaces a failure rather than swallowing it', () async {
      final controller = _controller(
        _FakeCourseRepository(failure: 'network down'),
      );

      await controller.load();

      expect(controller.failure, isNotNull);
      expect(controller.result.isDefined, isFalse);
    });

    test('a result in flight when the account changed is discarded', () async {
      final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
      repository.gate = Completer<void>();
      final controller = _controller(repository);

      final pending = controller.load();
      controller.reset();
      repository.gate!.complete();
      await pending;

      expect(
        controller.entries,
        isEmpty,
        reason: 'a superseded response must not write into the new account',
      );
    });
  });

  group('mutations', () {
    test('adding a course persists it and updates the average', () async {
      final repository = _FakeCourseRepository();
      final controller = _controller(repository);
      await controller.load();

      await controller.add(_course('1', 3));

      expect(controller.entries, hasLength(1));
      expect(controller.result.value, 4.0);
      expect(repository.courses, hasLength(1));
      expect(repository.saveCount, 1);
    });

    test('editing a course replaces it in place', () async {
      final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
      final controller = _controller(repository);
      await controller.load();

      await controller.update(_course('1', 3, _b));

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.grade, _b);
      expect(controller.result.value, 3.0);
    });

    test('editing an absent course changes nothing', () async {
      final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
      final controller = _controller(repository);
      await controller.load();

      await controller.update(_course('missing', 3, _b));

      expect(controller.entries.single.id, '1');
      expect(controller.result.value, 4.0);
    });

    test('removing a course drops it and recomputes', () async {
      final repository = _FakeCourseRepository(
        courses: [_course('1', 3), _course('2', 3, _b)],
      );
      final controller = _controller(repository);
      await controller.load();

      await controller.remove('1');

      expect(controller.entries.single.id, '2');
      expect(controller.result.value, 3.0);
    });

    test('a failed write is rolled back rather than left on screen', () async {
      final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
      final controller = _controller(repository);
      await controller.load();
      repository.saveFailure = 'disk full';

      await controller.add(_course('2', 3, _b));

      expect(
        controller.entries,
        hasLength(1),
        reason: 'what is displayed must match what was actually stored',
      );
      expect(controller.entries.single.id, '1');
      expect(controller.result.value, 4.0);
      expect(controller.failure, isNotNull);
    });
  });

  test('entries cannot be mutated through the getter', () {
    final controller = _controller(_FakeCourseRepository());
    expect(
      () => controller.entries.add(_course('1', 3)),
      throwsUnsupportedError,
    );
  });

  test('reset discards everything belonging to the previous account', () async {
    final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
    final controller = _controller(repository);
    await controller.load();

    controller.reset();

    expect(controller.entries, isEmpty);
    expect(controller.result.isDefined, isFalse);
    expect(controller.failure, isNull);
  });
}
