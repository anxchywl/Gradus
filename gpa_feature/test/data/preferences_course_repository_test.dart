import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_feature/gpa_feature.dart';
import 'package:gpa_feature/src/data/preferences_course_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

PreferencesCourseRepository _repository(String accountId) =>
    PreferencesCourseRepository(
      accountId: accountId,
      scale: const FourPointScale(),
    );

Course _course(String id) => Course(
  id: id,
  title: 'Course $id',
  credits: 3,
  grade: const Grade(letter: 'A', qualityPoints: 4),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a saved transcript comes back intact', () async {
    final repository = _repository('student-1');
    await repository.save([_course('1'), _course('2')]);

    final loaded = await repository.load();

    expect(loaded, hasLength(2));
    expect(loaded.first.title, 'Course 1');
    expect(loaded.first.grade!.letter, 'A');
    expect(loaded.first.credits, 3);
  });

  test('an empty store is empty, not an error', () async {
    expect(await _repository('student-1').load(), isEmpty);
  });

  test('an ungraded course survives the round trip', () async {
    final repository = _repository('student-1');
    await repository.save([Course(id: '1', title: 'In progress', credits: 4)]);

    final loaded = await repository.load();

    expect(loaded.single.grade, isNull);
    expect(loaded.single.isGraded, isFalse);
  });

  test('one account never sees another account\'s courses', () async {
    await _repository('student-1').save([_course('1')]);

    expect(await _repository('student-2').load(), isEmpty);
  });

  test('a corrupt entry is skipped without losing the rest', () async {
    SharedPreferences.setMockInitialValues({
      'gpa_v1_student-1_courses':
          '[{"id":"1","title":"Good","credits":3,"grade":"A"},'
          '{"id":"2","credits":"not a number"},'
          '{"nonsense":true}]',
    });

    final loaded = await _repository('student-1').load();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Good');
  });

  test(
    'a grade the scale no longer defines drops the grade, not the course',
    () async {
      SharedPreferences.setMockInitialValues({
        'gpa_v1_student-1_courses':
            '[{"id":"1","title":"Retired scale","credits":3,"grade":"Z"}]',
      });

      final loaded = await _repository('student-1').load();

      expect(loaded, hasLength(1));
      expect(loaded.single.grade, isNull);
    },
  );

  test('malformed stored json is treated as empty', () async {
    SharedPreferences.setMockInitialValues({
      'gpa_v1_student-1_courses': '{"not":"a list"}',
    });

    expect(await _repository('student-1').load(), isEmpty);
  });

  test('no stored key contains the access token', () async {
    final repository = _repository('student-1');
    await repository.save([_course('1')]);
    final preferences = await SharedPreferences.getInstance();

    // the key is namespaced by account, never by the credential
    expect(preferences.getKeys().single, 'gpa_v1_student-1_courses');
  });
}
