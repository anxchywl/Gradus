import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:gradus_feature/src/presentation/course_form.dart';
import 'package:gradus_feature/src/presentation/gradus_responsive.dart';
import 'package:gradus_feature/src/presentation/gradus_widgets.dart';
import 'package:gradus_feature/src/domain/repositories.dart';

class _FakeTranscriptRepository implements TranscriptRepository {
  _FakeTranscriptRepository({Transcript? transcript, this.shouldFail = false})
    : transcript = transcript ?? Transcript.empty;

  Transcript transcript;
  bool shouldFail;
  Completer<void>? gate;

  @override
  Future<Transcript> load() async {
    if (gate != null) await gate!.future;
    if (shouldFail) throw Exception('unavailable');
    return transcript;
  }

  @override
  Future<void> save(Transcript next) async => transcript = next;

  @override
  String toString() => 'FakeTranscriptRepository(${transcript.courses.length})';
}

class _FakeScales implements GradeScaleRepository {
  const _FakeScales();

  @override
  Future<GradeScale> active() async => const FourPointScale();
}

Widget _host({
  required TranscriptRepository repository,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  String token = 'a-token',
}) => MaterialApp(
  locale: locale,
  supportedLocales: supportedGradusLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(brightness: brightness),
  home: GradusFeature(
    session: GradusSession(accessToken: token, accountId: 'student-1'),
    dependencies: GradusDependencies(
      transcript: repository,
      scales: const _FakeScales(),
    ),
    config: const GradusConfig.sample(),
  ),
);

Semester _semester(String id, String name, {int position = 1}) =>
    Semester(id: id, name: name, position: position);

Course _course(
  String id,
  double credits, {
  String semesterId = 'fall',
  String code = '',
  Grade? grade = const Grade(letter: 'A', qualityPoints: 4),
  GradingMode gradingMode = GradingMode.graded,
  List<Assignment> assignments = const [],
}) => Course(
  id: id,
  semesterId: semesterId,
  code: code,
  title: 'Course $id',
  credits: credits,
  grade: grade,
  gradingMode: gradingMode,
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

Transcript _oneTerm(List<Course> courses) =>
    Transcript(semesters: [_semester('fall', 'Fall 2026')], courses: courses);

// the breakpoints under test are the ones the layout actually reads
void _resizeTo(WidgetTester tester, Size size) {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = size;
}

Future<void> _openSemesterMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Semester options'));
  await tester.pumpAndSettle();
}

Future<void> _openCourseMenu(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Options for $title'));
  await tester.pumpAndSettle();
}

// nothing in a widget test raises the view insets on its own
void _raiseKeyboard(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.reset);
}

// the screen behind the sheet carries the same words
Finder _inCourseForm(String text) =>
    find.descendant(of: find.byType(CourseForm), matching: find.text(text));

void main() {
  testWidgets('an account with no semesters is told to make one', (
    tester,
  ) async {
    await tester.pumpWidget(_host(repository: _FakeTranscriptRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No semesters yet'), findsOneWidget);
    expect(
      find.text('Create a semester, then add the courses you are taking.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppPrimaryButton, 'Add semester'),
      findsOneWidget,
      reason: 'an empty screen without a way forward is a dead end',
    );
    expect(
      find.byType(FloatingActionButton),
      findsNothing,
      reason: 'a course has nowhere to go until a semester exists',
    );
  });

  testWidgets('an empty semester says so rather than showing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(transcript: _oneTerm(const [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No courses yet'), findsOneWidget);
    expect(find.widgetWithText(AppPrimaryButton, 'Add course'), findsOneWidget);
  });

  testWidgets('a failure offers a way out of itself', (tester) async {
    final repository = _FakeTranscriptRepository(shouldFail: true);
    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your courses'), findsOneWidget);
    expect(find.widgetWithText(AppPrimaryButton, 'Try again'), findsOneWidget);

    // an error state with no way to retry leaves the student stuck
    repository
      ..shouldFail = false
      ..transcript = _oneTerm([_course('1', 3)]);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Course 1'), findsOneWidget);
  });

  testWidgets('a loaded transcript shows the average', (tester) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([_course('1', 3)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4.00'), findsWidgets);
    expect(
      find.text('Semester GPA'),
      findsOneWidget,
      reason: 'the label belongs above the figure, not after it',
    );
  });

  testWidgets('loading shows a loader, not a blank screen', (tester) async {
    final repository = _FakeTranscriptRepository();
    repository.gate = Completer<void>();
    await tester.pumpWidget(_host(repository: repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    repository.gate!.complete();
    await tester.pumpAndSettle();
  });

  for (final locale in supportedGradusLocales) {
    testWidgets('renders in ${locale.languageCode} without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([
              _course(
                '1',
                3,
                assignments: [_assignment('a1', '1', earnedScore: 80)],
              ),
            ]),
          ),
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
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([_course('1', 3)]),
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('an unsupported locale falls back to English', (tester) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(),
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No semesters yet'), findsOneWidget);
  });

  testWidgets('a new token rebuilds the scope so nothing survives', (
    tester,
  ) async {
    final repository = _FakeTranscriptRepository(
      transcript: _oneTerm([_course('1', 3)]),
    );
    await tester.pumpWidget(_host(repository: repository, token: 'student'));
    await tester.pumpAndSettle();
    expect(find.text('4.00'), findsWidgets);

    repository.transcript = Transcript.empty;
    await tester.pumpWidget(_host(repository: repository, token: 'operator'));
    await tester.pumpAndSettle();

    expect(find.text('4.00'), findsNothing);
  });

  testWidgets('renders inside a host that registers no delegates of its own', (
    tester,
  ) async {
    // the superapp may never have heard of this feature, it scopes its own
    await tester.pumpWidget(
      MaterialApp(
        home: GradusFeature(
          session: const GradusSession(
            accessToken: 'a-token',
            accountId: 'student-1',
          ),
          dependencies: GradusDependencies(
            transcript: _FakeTranscriptRepository(),
            scales: const _FakeScales(),
          ),
          config: const GradusConfig.sample(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No semesters yet'), findsOneWidget);
  });

  testWidgets('a rebuild of the host does not discard what was loaded', (
    tester,
  ) async {
    final repository = _FakeTranscriptRepository(
      transcript: _oneTerm([_course('1', 3)]),
    );
    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();

    expect(
      find.text('Course 1'),
      findsOneWidget,
      reason: 'the controller belongs to the session, not to one build',
    );
  });

  group('semesters', () {
    testWidgets('one can be created and becomes the selection', (tester) async {
      final repository = _FakeTranscriptRepository();
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add semester'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Fall 2026');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Fall 2026'), findsWidgets);
      expect(repository.transcript.semesters.single.name, 'Fall 2026');
    });

    testWidgets('the form refuses a blank name', (tester) async {
      await tester.pumpWidget(_host(repository: _FakeTranscriptRepository()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add semester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a semester name'), findsOneWidget);
    });

    testWidgets('one holding courses cannot be deleted', (tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // the reason belongs where the control is, not on the screen at all times
      expect(
        find.text('Move or delete its courses first'),
        findsNothing,
        reason: 'an explanation is not an error to show before anyone acts',
      );

      await _openSemesterMenu(tester);

      expect(find.text('Move or delete its courses first'), findsOneWidget);

      await tester.tap(find.text('Delete Fall 2026'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This cannot be undone'),
        findsNothing,
        reason: 'the control is closed, not merely explained afterwards',
      );
      expect(find.text('Fall 2026'), findsWidgets);
      expect(find.text('Course 1'), findsOneWidget);
    });

    testWidgets('switching hides the other semester\'s courses', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: Transcript(
              semesters: [
                _semester('fall', 'Fall 2026', position: 2),
                _semester('spring', 'Spring 2026', position: 1),
              ],
              courses: [
                _course('1', 3, semesterId: 'fall'),
                _course('2', 3, semesterId: 'spring'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course 1'), findsOneWidget);
      expect(find.text('Course 2'), findsNothing);

      await tester.tap(find.text('Spring 2026'));
      await tester.pumpAndSettle();

      expect(find.text('Course 2'), findsOneWidget);
      expect(find.text('Course 1'), findsNothing);
    });

    testWidgets('the all-semesters view groups every course by term', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: Transcript(
              semesters: [
                _semester('fall', 'Fall 2026', position: 2),
                _semester('spring', 'Spring 2026', position: 1),
              ],
              courses: [
                _course('1', 4, semesterId: 'fall'),
                _course(
                  '2',
                  4,
                  semesterId: 'spring',
                  grade: const Grade(letter: 'B', qualityPoints: 3),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All semesters'));
      await tester.pumpAndSettle();

      expect(find.text('Course 1'), findsOneWidget);
      expect(find.text('Course 2'), findsOneWidget);
      expect(find.text('Cumulative GPA'), findsOneWidget);
      expect(find.text('3.50'), findsWidgets);
    });

    testWidgets('a semester and a cumulative figure are shown apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: Transcript(
              semesters: [
                _semester('fall', 'Fall 2026', position: 2),
                _semester('spring', 'Spring 2026', position: 1),
              ],
              courses: [
                _course('1', 4, semesterId: 'fall'),
                _course(
                  '2',
                  4,
                  semesterId: 'spring',
                  grade: const Grade(letter: 'B', qualityPoints: 3),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Semester GPA'), findsOneWidget);
      expect(find.text('4.00'), findsWidgets);
      expect(find.text('Cumulative GPA'), findsOneWidget);
      expect(find.text('3.50'), findsOneWidget);
    });
  });

  group('courses', () {
    testWidgets('one can be added through the form and changes the average', (
      tester,
    ) async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm(const []),
      );
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add course'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'MATH 273');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Linear Algebra',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '3');
      await tester.tap(find.byType(DropdownButtonFormField<Grade?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Linear Algebra'), findsOneWidget);
      expect(find.text('MATH 273'), findsOneWidget);
      expect(find.text('4.00'), findsWidgets);
      expect(repository.transcript.courses, hasLength(1));
    });

    testWidgets('the form refuses a blank title and bad credits', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(transcript: _oneTerm(const [])),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add course'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), '99');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a course name'), findsOneWidget);
      expect(find.text('Enter credits between 0 and 24'), findsOneWidget);
    });

    testWidgets('one can be deleted after the deletion is confirmed', (
      tester,
    ) async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Course 1'), findsOneWidget);

      await _openCourseMenu(tester, 'Course 1');
      await tester.tap(find.text('Delete Course 1'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Delete Course 1 and its assignments? This cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Course 1'), findsNothing);
      expect(repository.transcript.courses, isEmpty);
    });

    testWidgets('a cancelled deletion keeps the course', (tester) async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      await _openCourseMenu(tester, 'Course 1');
      await tester.tap(find.text('Delete Course 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Course 1'), findsOneWidget);
      expect(repository.transcript.courses, hasLength(1));
    });

    testWidgets('a pass/fail course is labelled rather than looking lost', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([
              _course('1', 3),
              _course(
                '2',
                3,
                gradingMode: GradingMode.passFail,
                grade: const Grade(
                  letter: 'P',
                  qualityPoints: 0,
                  countsTowardGpa: false,
                ),
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pass/fail'), findsOneWidget);
      expect(find.text('4.00'), findsWidgets);
      expect(find.byType(GradusStatusChip), findsOneWidget);
      expect(find.text('Credits counted'), findsOneWidget);
      expect(find.text('3 of 6'), findsOneWidget);
    });

    testWidgets('an incomplete grading setup is called out on the row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([
              _course(
                '1',
                3,
                grade: null,
                assignments: [
                  _assignment('a1', '1', weight: 40, earnedScore: 90),
                ],
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('60% of this course\'s grading setup is unallocated.'),
        findsOneWidget,
      );
      expect(find.text('1 of 1 graded  ·  Graded weight 40%'), findsOneWidget);
      expect(find.text('3 cr  ·  90.0%  ·  GPA 4.00'), findsOneWidget);
    });

    testWidgets('the delete control carries a semantics label', (tester) async {
      // the semantics tree is not built unless a test asks for it
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('Options for Course 1'),
        findsOneWidget,
        reason: 'an icon-only control needs a label a screen reader can read',
      );
      expect(find.bySemanticsLabel('Semester options'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('layout', () {
    testWidgets('one column on a phone, two once there is room', (
      tester,
    ) async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3), _course('2', 3)]),
      );

      _resizeTo(tester, const Size(390, 844));
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      final phoneFirst = tester.getTopLeft(find.text('Course 1'));
      final phoneSecond = tester.getTopLeft(find.text('Course 2'));
      expect(
        phoneSecond.dy,
        greaterThan(phoneFirst.dy),
        reason: 'a phone stacks the cards',
      );

      _resizeTo(tester, const Size(1280, 900));
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      final wideFirst = tester.getTopLeft(find.text('Course 1'));
      final wideSecond = tester.getTopLeft(find.text('Course 2'));
      expect(
        wideSecond.dy,
        wideFirst.dy,
        reason: 'a wide window puts them side by side',
      );
      expect(wideSecond.dx, greaterThan(wideFirst.dx));
    });

    testWidgets('the reading column stops growing on a wide window', (
      tester,
    ) async {
      _resizeTo(tester, const Size(1600, 900));
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = tester.getSize(
        find.ancestor(
          of: find.text('Semester GPA'),
          matching: find.byType(AppCard),
        ),
      );
      expect(
        card.width,
        lessThanOrEqualTo(gradusReadingWidth),
        reason: 'a hero card that spans a tablet is unscannable',
      );
    });

    testWidgets('every semester chip is a reachable target', (tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const ['All semesters', 'Fall 2026']) {
        final size = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(AppCard)),
        );
        expect(size.height, greaterThanOrEqualTo(AppSpacing.buttonHeightSm));
      }
    });

    testWidgets('a long course title wraps rather than pushing the row', (
      tester,
    ) async {
      _resizeTo(tester, const Size(320, 720));
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: Transcript(
              semesters: [_semester('fall', 'Fall 2026')],
              courses: [
                Course(
                  id: '1',
                  semesterId: 'fall',
                  code: 'WCS 210/ASC 200',
                  title:
                      'Academic Writing, Science Communication and Research '
                      'Methods for Undergraduates',
                  credits: 6,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(
        find.textContaining('Academic Writing'),
      );
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });
  });

  testWidgets('a letter that carries no points explains itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([
            _course(
              '1',
              6,
              grade: const Grade(
                letter: 'P',
                qualityPoints: 0,
                countsTowardGpa: false,
              ),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Counts as attempted credit, not toward the GPA.'),
      findsOneWidget,
      reason: 'a muted badge alone reads as a course with no marks',
    );
  });

  testWidgets('an undefined average says why instead of showing a dash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([_course('1', 3, grade: null)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not enough graded credits yet'), findsOneWidget);

    // at display size a dash reads as a stray rule rather than an absent figure
    final dashes = tester.widgetList<Text>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Semester GPA'),
          matching: find.byType(AppCard),
        ),
        matching: find.text('—'),
      ),
    );
    expect(dashes, isNotEmpty);
    expect(
      dashes.every(
        (text) =>
            (text.style?.fontSize ?? 0) < AppTextStyles.displaySmall.fontSize!,
      ),
      isTrue,
    );
  });

  group('focus mode', () {
    testWidgets(
      'the field with the keyboard is all the form leaves on screen',
      (tester) async {
        await tester.pumpWidget(
          _host(
            repository: _FakeTranscriptRepository(
              transcript: _oneTerm(const []),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add course'));
        await tester.pumpAndSettle();

        expect(_inCourseForm('Semester'), findsOneWidget);
        expect(_inCourseForm('Done'), findsNothing);

        _raiseKeyboard(tester);
        await tester.tap(find.byType(TextFormField).at(1));
        await tester.pumpAndSettle();

        expect(
          _inCourseForm('Course'),
          findsOneWidget,
          reason: 'the field being typed into is the one thing that stays',
        );
        for (final gone in const [
          'Add course',
          'Course code',
          'Credits',
          'Semester',
          'Include in GPA',
          'Save',
          'Cancel',
        ]) {
          expect(
            _inCourseForm(gone),
            findsNothing,
            reason: '$gone does not belong on screen next to a keyboard',
          );
        }
        expect(_inCourseForm('Done'), findsOneWidget);

        await tester.tap(_inCourseForm('Done'));
        await tester.pumpAndSettle();

        expect(_inCourseForm('Save'), findsOneWidget);
        expect(_inCourseForm('Semester'), findsOneWidget);
        expect(_inCourseForm('Done'), findsNothing);
      },
    );

    testWidgets('the next-field key moves the keyboard on rather than out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(transcript: _oneTerm(const [])),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add course'));
      await tester.pumpAndSettle();

      _raiseKeyboard(tester);
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pumpAndSettle();
      expect(_inCourseForm('Course code'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(_inCourseForm('Course'), findsOneWidget);
      expect(_inCourseForm('Course code'), findsNothing);
      expect(
        _inCourseForm('Done'),
        findsOneWidget,
        reason:
            'a folded field is out of the tree, so the key that walks the '
            'form has to open the next fold rather than hunt for a node',
      );
    });

    testWidgets('what was typed survives the fold', (tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(transcript: _oneTerm(const [])),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add course'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'MATH 273');
      _raiseKeyboard(tester);
      await tester.tap(find.byType(TextFormField).at(1));
      await tester.pumpAndSettle();
      await tester.tap(_inCourseForm('Done'));
      await tester.pumpAndSettle();

      expect(
        find.text('MATH 273'),
        findsOneWidget,
        reason:
            'the controllers outlive the fold, so a folded field keeps '
            'what was already in it',
      );
    });
  });
}
