import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:gradus_feature/src/data/preferences_transcript_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

PreferencesTranscriptRepository _repository(String accountId) =>
    PreferencesTranscriptRepository(
      accountId: accountId,
      scale: const FourPointScale(),
    );

Semester _semester([String id = 'fall']) =>
    Semester(id: id, name: 'Fall 2026', position: 1);

Course _course(
  String id, {
  String semesterId = 'fall',
  List<Assignment> assignments = const [],
  GradingMode gradingMode = GradingMode.graded,
  bool includeInGpa = true,
}) => Course(
  id: id,
  semesterId: semesterId,
  code: 'CSCI 23$id',
  title: 'Course $id',
  credits: 3,
  grade: const Grade(letter: 'A', qualityPoints: 4),
  gradingMode: gradingMode,
  includeInGpa: includeInGpa,
  assignments: assignments,
);

Assignment _assignment(String id, String courseId, {double? earnedScore}) =>
    Assignment(
      id: id,
      courseId: courseId,
      name: 'Midterm',
      weight: 25,
      maximumScore: 100,
      earnedScore: earnedScore,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a saved transcript comes back intact', () async {
    final repository = _repository('student-1');
    await repository.save(
      Transcript(
        semesters: [_semester()],
        courses: [_course('1'), _course('2')],
      ),
    );

    final loaded = await repository.load();

    expect(loaded.semesters.single.name, 'Fall 2026');
    expect(loaded.courses, hasLength(2));
    expect(loaded.courses.first.title, 'Course 1');
    expect(loaded.courses.first.code, 'CSCI 231');
    expect(loaded.courses.first.grade!.letter, 'A');
    expect(loaded.courses.first.credits, 3);
  });

  test('assignments survive the round trip', () async {
    final repository = _repository('student-1');
    await repository.save(
      Transcript(
        semesters: [_semester()],
        courses: [
          _course(
            '1',
            assignments: [
              _assignment('a1', '1', earnedScore: 85),
              _assignment('a2', '1'),
            ],
          ),
        ],
      ),
    );

    final assignments = (await repository.load()).courses.single.assignments;

    expect(assignments, hasLength(2));
    expect(assignments.first.earnedScore, 85);
    expect(assignments.first.weight, 25);
    expect(assignments.first.maximumScore, 100);
    expect(
      assignments.last.earnedScore,
      isNull,
      reason: 'unmarked work must not come back as a zero',
    );
  });

  test('grading mode and exclusion survive the round trip', () async {
    final repository = _repository('student-1');
    await repository.save(
      Transcript(
        semesters: [_semester()],
        courses: [
          _course('1', gradingMode: GradingMode.passFail),
          _course('2', includeInGpa: false),
        ],
      ),
    );

    final loaded = await repository.load();

    expect(loaded.courses.first.gradingMode, GradingMode.passFail);
    expect(loaded.courses.last.includeInGpa, isFalse);
  });

  test('an empty store is empty, not an error', () async {
    final loaded = await _repository('student-1').load();
    expect(loaded.semesters, isEmpty);
    expect(loaded.courses, isEmpty);
  });

  test('one account never sees another account\'s transcript', () async {
    await _repository(
      'student-1',
    ).save(Transcript(semesters: [_semester()], courses: [_course('1')]));

    final other = await _repository('student-2').load();

    expect(other.courses, isEmpty);
    expect(other.semesters, isEmpty);
  });

  test('a corrupt course is skipped without losing the rest', () async {
    SharedPreferences.setMockInitialValues({
      'gpa_v2_student-1_transcript': jsonEncode({
        'semesters': [
          {'id': 'fall', 'name': 'Fall 2026', 'position': 1},
        ],
        'courses': [
          {'id': '1', 'semesterId': 'fall', 'title': 'Good', 'credits': 3},
          {'id': '2', 'semesterId': 'fall', 'credits': 'not a number'},
          {'nonsense': true},
        ],
      }),
    });

    final loaded = await _repository('student-1').load();

    expect(loaded.courses, hasLength(1));
    expect(loaded.courses.single.title, 'Good');
  });

  test('a corrupt assignment is skipped without losing the course', () async {
    SharedPreferences.setMockInitialValues({
      'gpa_v2_student-1_transcript': jsonEncode({
        'semesters': [
          {'id': 'fall', 'name': '', 'position': 0},
        ],
        'courses': [
          {
            'id': '1',
            'semesterId': 'fall',
            'title': 'Good',
            'credits': 3,
            'assignments': [
              {'id': 'a1', 'name': 'Fine', 'weight': 25, 'maximumScore': 100},
              {'id': 'a2', 'name': 'Broken', 'weight': 0, 'maximumScore': 100},
              {'nonsense': true},
            ],
          },
        ],
      }),
    });

    final loaded = await _repository('student-1').load();

    expect(loaded.courses.single.assignments, hasLength(1));
    expect(loaded.courses.single.assignments.single.id, 'a1');
  });

  test(
    'an assignment cannot be reattached to another course on disk',
    () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v2_student-1_transcript': jsonEncode({
          'semesters': [
            {'id': 'fall', 'name': '', 'position': 0},
          ],
          'courses': [
            {
              'id': '1',
              'semesterId': 'fall',
              'title': 'Host',
              'credits': 3,
              'assignments': [
                {
                  'id': 'a1',
                  'courseId': 'somewhere-else',
                  'name': 'Foreign',
                  'weight': 25,
                  'maximumScore': 100,
                },
              ],
            },
          ],
        }),
      });

      final loaded = await _repository('student-1').load();

      expect(loaded.courses.single.assignments.single.courseId, '1');
    },
  );

  test('a course whose semester is gone is not loaded orphaned', () async {
    SharedPreferences.setMockInitialValues({
      'gpa_v2_student-1_transcript': jsonEncode({
        'semesters': <Object>[],
        'courses': [
          {
            'id': '1',
            'semesterId': 'vanished',
            'title': 'Orphan',
            'credits': 3,
          },
        ],
      }),
    });

    expect((await _repository('student-1').load()).courses, isEmpty);
  });

  test(
    'a grade the scale no longer defines drops the grade, not the course',
    () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v2_student-1_transcript': jsonEncode({
          'semesters': [
            {'id': 'fall', 'name': '', 'position': 0},
          ],
          'courses': [
            {
              'id': '1',
              'semesterId': 'fall',
              'title': 'Retired scale',
              'credits': 3,
              'grade': 'Z',
            },
          ],
        }),
      });

      final loaded = await _repository('student-1').load();

      expect(loaded.courses, hasLength(1));
      expect(loaded.courses.single.grade, isNull);
    },
  );

  test('malformed stored json is treated as empty', () async {
    SharedPreferences.setMockInitialValues({
      'gpa_v2_student-1_transcript': '["not","a","map"]',
    });

    expect((await _repository('student-1').load()).courses, isEmpty);
  });

  test('no stored key contains the access token', () async {
    final repository = _repository('student-1');
    await repository.save(
      Transcript(semesters: [_semester()], courses: [_course('1')]),
    );
    final preferences = await SharedPreferences.getInstance();

    // the key is namespaced by account, never by the credential
    expect(preferences.getKeys().single, 'gpa_v2_student-1_transcript');
  });

  group('migration from the course-only layout', () {
    test('existing courses survive and land in one unnamed semester', () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses':
            '[{"id":"1","title":"Discrete Mathematics","credits":3,"grade":"A"},'
            '{"id":"2","title":"In progress","credits":4}]',
      });

      final loaded = await _repository('student-1').load();

      expect(loaded.courses, hasLength(2));
      expect(loaded.courses.first.title, 'Discrete Mathematics');
      expect(loaded.courses.first.grade!.letter, 'A');
      expect(loaded.courses.last.grade, isNull);
      expect(loaded.semesters, hasLength(1));
      expect(
        loaded.semesters.single.hasName,
        isFalse,
        reason: 'the old store recorded no term, so none is invented',
      );
      expect(
        loaded.courses.every((c) => c.semesterId == loaded.semesters.single.id),
        isTrue,
      );
    });

    test('the migrated transcript is written under the new key', () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses':
            '[{"id":"1","title":"Kept","credits":3,"grade":"A"}]',
      });

      await _repository('student-1').load();
      final preferences = await SharedPreferences.getInstance();

      expect(preferences.getString('gpa_v2_student-1_transcript'), isNotNull);
      expect(
        preferences.getString('gpa_v1_student-1_courses'),
        isNotNull,
        reason: 'the old key is read, never destroyed',
      );
    });

    test('the migration runs once and does not run over newer data', () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses':
            '[{"id":"1","title":"Old","credits":3,"grade":"A"}]',
      });
      final repository = _repository('student-1');

      final first = await repository.load();
      await repository.save(
        first.copyWith(
          courses: [
            ...first.courses,
            Course(
              id: '2',
              semesterId: first.semesters.single.id,
              title: 'New',
              credits: 3,
            ),
          ],
        ),
      );

      final second = await repository.load();

      expect(second.courses, hasLength(2));
    });

    test('a migrated course keeps its average', () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses':
            '[{"id":"1","title":"A course","credits":3,"grade":"A"},'
            '{"id":"2","title":"Pass/fail","credits":3,"grade":"P"}]',
      });

      final loaded = await _repository('student-1').load();
      final result = calculateGpa(loaded.courses, const FourPointScale());

      expect(result.value, 4.0);
      expect(result.qualityCredits, 3);
      expect(result.attemptedCredits, 6);
    });

    test('an empty old store migrates to an empty transcript', () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses': '[]',
      });

      final loaded = await _repository('student-1').load();

      expect(loaded.semesters, isEmpty);
      expect(loaded.courses, isEmpty);
    });

    test('one account\'s old data never migrates into another', () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses':
            '[{"id":"1","title":"Private","credits":3,"grade":"A"}]',
      });

      expect((await _repository('student-2').load()).courses, isEmpty);
    });
  });
}
