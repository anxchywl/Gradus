import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_feature/gpa_feature.dart';
import 'package:gpa_feature/src/domain/repositories.dart';

class _FakeCourseRepository implements CourseRepository {
  _FakeCourseRepository({this.courses = const [], this.shouldFail = false});

  List<Course> courses;
  bool shouldFail;
  Completer<void>? gate;

  @override
  Future<List<Course>> load() async {
    if (gate != null) await gate!.future;
    if (shouldFail) throw Exception('unavailable');
    return courses;
  }

  @override
  Future<void> save(List<Course> next) async => courses = next;

  @override
  String toString() => 'FakeCourseRepository(${courses.length})';
}

/// A host that registers the delegates a real host would.
Widget _host({
  required CourseRepository repository,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  String token = 'a-token',
}) => MaterialApp(
  locale: locale,
  supportedLocales: supportedGpaLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(brightness: brightness),
  home: GpaFeature(
    session: GpaSession(accessToken: token, accountId: 'student-1'),
    dependencies: GpaDependencies(
      courses: repository,
      scales: const _FakeScales(),
    ),
    config: const GpaConfig.sample(),
  ),
);

class _FakeScales implements GradeScaleRepository {
  const _FakeScales();

  @override
  Future<GradeScale> active() async => const FourPointScale();
}

Course _course(String id, double credits) => Course(
  id: id,
  title: 'Course $id',
  credits: credits,
  grade: const Grade(letter: 'A', qualityPoints: 4),
);

void main() {
  testWidgets('an empty transcript says so rather than showing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(repository: _FakeCourseRepository()));
    await tester.pumpAndSettle();

    expect(
      find.text('No courses yet. Add one to see your GPA.'),
      findsOneWidget,
    );
  });

  testWidgets('a failure shows a real error state', (tester) async {
    await tester.pumpWidget(
      _host(repository: _FakeCourseRepository(shouldFail: true)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load your courses. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a loaded transcript shows the average', (tester) async {
    await tester.pumpWidget(
      _host(repository: _FakeCourseRepository(courses: [_course('1', 3)])),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('4.00'), findsOneWidget);
  });

  testWidgets('loading shows a loader, not a blank screen', (tester) async {
    final repository = _FakeCourseRepository();
    repository.gate = Completer<void>();
    await tester.pumpWidget(_host(repository: repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repository.gate!.complete();
    await tester.pumpAndSettle();
  });

  for (final locale in supportedGpaLocales) {
    testWidgets('renders in ${locale.languageCode} without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeCourseRepository(courses: [_course('1', 3)]),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders in dark mode without overflow', (tester) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeCourseRepository(courses: [_course('1', 3)]),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('an unsupported locale falls back to English', (tester) async {
    await tester.pumpWidget(
      _host(repository: _FakeCourseRepository(), locale: const Locale('de')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No courses yet. Add one to see your GPA.'),
      findsOneWidget,
    );
  });

  testWidgets('a new token rebuilds the scope so nothing survives', (
    tester,
  ) async {
    final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
    await tester.pumpWidget(_host(repository: repository, token: 'student'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4.00'), findsOneWidget);

    repository.courses = const [];
    await tester.pumpWidget(_host(repository: repository, token: 'operator'));
    await tester.pumpAndSettle();

    expect(find.textContaining('4.00'), findsNothing);
  });

  testWidgets('renders inside a host that registers no delegates of its own', (
    tester,
  ) async {
    // the superapp may never have heard of this feature; it scopes its own
    // delegates so its strings resolve regardless
    await tester.pumpWidget(
      MaterialApp(
        home: GpaFeature(
          session: const GpaSession(
            accessToken: 'a-token',
            accountId: 'student-1',
          ),
          dependencies: GpaDependencies(
            courses: _FakeCourseRepository(),
            scales: const _FakeScales(),
          ),
          config: const GpaConfig.sample(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No courses yet. Add one to see your GPA.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a course can be added through the form and changes the average',
    (tester) async {
      final repository = _FakeCourseRepository();
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Linear Algebra',
      );
      await tester.enterText(find.byType(TextFormField).last, '3');
      await tester.tap(find.byType(DropdownButtonFormField<Grade?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Linear Algebra'), findsOneWidget);
      expect(find.textContaining('4.00'), findsOneWidget);
      expect(repository.courses, hasLength(1));
    },
  );

  testWidgets('the form refuses a blank title and bad credits', (tester) async {
    await tester.pumpWidget(_host(repository: _FakeCourseRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '99');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a course name'), findsOneWidget);
    expect(find.text('Enter credits between 0 and 24'), findsOneWidget);
  });

  testWidgets('a course can be deleted', (tester) async {
    final repository = _FakeCourseRepository(courses: [_course('1', 3)]);
    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Course 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Course 1'), findsNothing);
    expect(repository.courses, isEmpty);
  });

  testWidgets('the delete control carries a semantics label', (tester) async {
    // the semantics tree is not built unless a test asks for it
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(repository: _FakeCourseRepository(courses: [_course('1', 3)])),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Delete Course 1'),
      findsOneWidget,
      reason: 'an icon-only control needs a label a screen reader can read',
    );
    semantics.dispose();
  });
}
