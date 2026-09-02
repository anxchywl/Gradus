import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:gradus_feature/src/application/gradus_controller.dart';
import 'package:gradus_feature/src/domain/repositories.dart';

class _FakeTranscriptRepository implements TranscriptRepository {
  _FakeTranscriptRepository({Transcript? transcript, this.failure})
    : transcript = transcript ?? Transcript.empty;

  Transcript transcript;
  Object? failure;
  Object? saveFailure;
  Completer<void>? gate;
  int saveCount = 0;

  @override
  Future<Transcript> load() async {
    if (gate != null) await gate!.future;
    if (failure != null) throw Exception(failure.toString());
    return transcript;
  }

  @override
  Future<void> save(Transcript next) async {
    saveCount++;
    if (saveFailure != null) throw Exception(saveFailure.toString());
    transcript = next;
  }
}

class _FakeScales implements GradeScaleRepository {
  const _FakeScales();

  @override
  Future<GradeScale> active() async => const FourPointScale();
}

const _a = Grade(letter: 'A', qualityPoints: 4);
const _b = Grade(letter: 'B', qualityPoints: 3);

Semester _semester(String id, {int position = 0}) =>
    Semester(id: id, name: 'Term $id', position: position);

Course _course(
  String id,
  double credits, {
  String semesterId = 'fall',
  Grade? grade,
  List<Assignment> assignments = const [],
}) => Course(
  id: id,
  semesterId: semesterId,
  title: 'Course $id',
  credits: credits,
  grade: grade ?? (assignments.isEmpty ? _a : null),
  assignments: assignments,
);

Assignment _assignment(
  String id,
  String courseId, {
  double weight = 50,
  double? earnedScore,
}) => Assignment(
  id: id,
  courseId: courseId,
  name: 'Item $id',
  weight: weight,
  maximumScore: 100,
  earnedScore: earnedScore,
);

GradusController _controller(_FakeTranscriptRepository repository) =>
    GradusController(transcript: repository, scales: const _FakeScales());

Transcript _oneTerm(List<Course> courses) =>
    Transcript(semesters: [_semester('fall')], courses: courses);

void main() {
  group('load', () {
    test('computes the average from what came back', () async {
      final controller = _controller(
        _FakeTranscriptRepository(transcript: _oneTerm([_course('1', 3)])),
      );

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.result.value, 4.0);
      expect(controller.entries, hasLength(1));
      expect(controller.scale, isNotNull);
    });

    test('lands on the newest semester', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: Transcript(
            semesters: [
              _semester('fall2025', position: 1),
              _semester('fall2026', position: 2),
            ],
          ),
        ),
      );

      await controller.load();

      expect(controller.selectedSemesterId, 'fall2026');
    });

    test('surfaces a failure rather than swallowing it', () async {
      final controller = _controller(
        _FakeTranscriptRepository(failure: 'network down'),
      );

      await controller.load();

      expect(controller.failure, isNotNull);
      expect(controller.result.isDefined, isFalse);
    });

    test('a result in flight when the account changed is discarded', () async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
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

  group('semesters', () {
    test('adding one selects it', () async {
      final controller = _controller(_FakeTranscriptRepository());
      await controller.load();

      await controller.addSemester(_semester('fall', position: 1));

      expect(controller.semesters, hasLength(1));
      expect(controller.selectedSemesterId, 'fall');
    });

    test('renaming one keeps its courses', () async {
      final controller = _controller(
        _FakeTranscriptRepository(transcript: _oneTerm([_course('1', 3)])),
      );
      await controller.load();

      await controller.updateSemester(
        Semester(id: 'fall', name: 'Fall 2026', position: 3),
      );

      expect(controller.semesters.single.name, 'Fall 2026');
      expect(controller.entries, hasLength(1));
    });

    test('one still holding courses is not deleted', () async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
      final controller = _controller(repository);
      await controller.load();

      expect(controller.canRemoveSemester('fall'), isFalse);
      await controller.removeSemester('fall');

      expect(controller.semesters, hasLength(1));
      expect(controller.entries, hasLength(1));
      expect(controller.failure, isA<SemesterNotEmptyFailure>());
    });

    test('an empty one is deleted and the view falls back to all', () async {
      final controller = _controller(
        _FakeTranscriptRepository(transcript: _oneTerm(const [])),
      );
      await controller.load();

      expect(controller.canRemoveSemester('fall'), isTrue);
      await controller.removeSemester('fall');

      expect(controller.semesters, isEmpty);
      expect(controller.isAllSemestersSelected, isTrue);
    });

    test('switching semesters never shows the other one\'s courses', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: Transcript(
            semesters: [
              _semester('fall', position: 2),
              _semester('spring', position: 1),
            ],
            courses: [
              _course('1', 4, semesterId: 'fall'),
              _course('2', 4, semesterId: 'spring', grade: _b),
            ],
          ),
        ),
      );
      await controller.load();

      expect(controller.entries.single.id, '1');
      expect(controller.semesterResult.value, 4.0);

      controller.selectSemester('spring');

      expect(controller.entries.single.id, '2');
      expect(controller.semesterResult.value, 3.0);
    });

    test('semester and cumulative averages are reported separately', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: Transcript(
            semesters: [
              _semester('fall', position: 2),
              _semester('spring', position: 1),
            ],
            courses: [
              _course('1', 4, semesterId: 'fall'),
              _course('2', 4, semesterId: 'spring', grade: _b),
            ],
          ),
        ),
      );
      await controller.load();

      expect(controller.semesterResult.value, 4.0);
      expect(controller.cumulativeResult.value, 3.5);
    });

    test('the all-semesters view leads with the cumulative figure', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: Transcript(
            semesters: [_semester('fall'), _semester('spring')],
            courses: [
              _course('1', 4, semesterId: 'fall'),
              _course('2', 4, semesterId: 'spring', grade: _b),
            ],
          ),
        ),
      );
      await controller.load();

      controller.selectSemester(null);

      expect(controller.isAllSemestersSelected, isTrue);
      expect(controller.result.value, 3.5);
      expect(controller.entries, hasLength(2));
      expect(controller.semesterResult.isDefined, isFalse);
    });
  });

  group('courses', () {
    test('adding one persists it and updates the average', () async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm(const []),
      );
      final controller = _controller(repository);
      await controller.load();

      await controller.addCourse(_course('1', 3));

      expect(controller.entries, hasLength(1));
      expect(controller.result.value, 4.0);
      expect(repository.transcript.courses, hasLength(1));
      expect(repository.saveCount, 1);
    });

    test('editing one replaces it in place', () async {
      final controller = _controller(
        _FakeTranscriptRepository(transcript: _oneTerm([_course('1', 3)])),
      );
      await controller.load();

      await controller.updateCourse(_course('1', 3, grade: _b));

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.grade, _b);
      expect(controller.result.value, 3.0);
    });

    test('editing an absent one changes nothing', () async {
      final controller = _controller(
        _FakeTranscriptRepository(transcript: _oneTerm([_course('1', 3)])),
      );
      await controller.load();

      await controller.updateCourse(_course('missing', 3, grade: _b));

      expect(controller.entries.single.id, '1');
      expect(controller.result.value, 4.0);
    });

    test('removing one drops it and recomputes', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: _oneTerm([_course('1', 3), _course('2', 3, grade: _b)]),
        ),
      );
      await controller.load();

      await controller.removeCourse('1');

      expect(controller.entries.single.id, '2');
      expect(controller.result.value, 3.0);
    });

    test('a failed write is rolled back rather than left on screen', () async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
      final controller = _controller(repository);
      await controller.load();
      repository.saveFailure = 'disk full';

      await controller.addCourse(_course('2', 3, grade: _b));

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

  group('assignments', () {
    test('adding one attaches it to its own course only', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: _oneTerm([
            _course('1', 3, assignments: [_assignment('a1', '1')]),
            _course('2', 3),
          ]),
        ),
      );
      await controller.load();

      await controller.addAssignment(
        _assignment('a2', '1', weight: 50, earnedScore: 90),
      );

      expect(controller.courseById('1')!.assignments, hasLength(2));
      expect(
        controller.courseById('2')!.assignments,
        isEmpty,
        reason: 'work added to one course must not appear in another',
      );
    });

    test('editing one changes that assignment and nothing else', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: _oneTerm([
            _course(
              '1',
              3,
              assignments: [_assignment('a1', '1'), _assignment('a2', '1')],
            ),
          ]),
        ),
      );
      await controller.load();

      await controller.updateAssignment(
        _assignment('a1', '1', earnedScore: 80),
      );

      final assignments = controller.courseById('1')!.assignments;
      expect(assignments.first.earnedScore, 80);
      expect(assignments.last.earnedScore, isNull);
    });

    test('deleting one leaves its siblings alone', () async {
      final controller = _controller(
        _FakeTranscriptRepository(
          transcript: _oneTerm([
            _course(
              '1',
              3,
              assignments: [_assignment('a1', '1'), _assignment('a2', '1')],
            ),
          ]),
        ),
      );
      await controller.load();

      await controller.removeAssignment('1', 'a1');

      expect(controller.courseById('1')!.assignments.single.id, 'a2');
    });

    test(
      'marking work moves the average without a letter being typed',
      () async {
        final repository = _FakeTranscriptRepository(
          transcript: _oneTerm([
            _course('1', 3, assignments: [_assignment('a1', '1', weight: 100)]),
          ]),
        );
        final controller = _controller(repository);
        await controller.load();
        expect(controller.result.isDefined, isFalse);

        await controller.updateAssignment(
          _assignment('a1', '1', weight: 100, earnedScore: 95),
        );

        expect(controller.result.value, 4.0);
        expect(
          repository.transcript.courses.single.assignments.single.earnedScore,
          95,
        );
      },
    );

    test('work aimed at a course that is gone changes nothing', () async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm(const []),
      );
      final controller = _controller(repository);
      await controller.load();

      await controller.addAssignment(_assignment('a1', 'missing'));

      expect(repository.saveCount, 0);
    });
  });

  test('entries cannot be mutated through the getter', () {
    final controller = _controller(_FakeTranscriptRepository());
    expect(
      () => controller.entries.add(_course('1', 3)),
      throwsUnsupportedError,
    );
  });

  test('reset discards everything belonging to the previous account', () async {
    final controller = _controller(
      _FakeTranscriptRepository(transcript: _oneTerm([_course('1', 3)])),
    );
    await controller.load();

    controller.reset();

    expect(controller.entries, isEmpty);
    expect(controller.semesters, isEmpty);
    expect(controller.selectedSemesterId, isNull);
    expect(controller.result.isDefined, isFalse);
    expect(controller.failure, isNull);
  });

  test('a load still in flight cannot notify a disposed controller', () async {
    final repository = _FakeTranscriptRepository(
      transcript: _oneTerm([_course('1', 3)]),
    );
    repository.gate = Completer<void>();
    final controller = _controller(repository);

    final pending = controller.load();
    controller.dispose();
    repository.gate!.complete();

    await expectLater(pending, completes);
  });
}
