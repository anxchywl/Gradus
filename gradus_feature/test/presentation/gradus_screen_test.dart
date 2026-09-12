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
  List<Assignment> assignments = const [],
}) => Course(
  id: id,
  semesterId: semesterId,
  code: code,
  title: 'Course $id',
  credits: credits,
  grade: grade,
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

Future<void> _openSemesterSheet(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(AppCard, 'Semester GPA'));
  await tester.pumpAndSettle();
}

Future<void> _openCourse(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

// the screen behind the sheet carries the same words
Finder _inCourseForm(String text) =>
    find.descendant(of: find.byType(CourseForm), matching: find.text(text));

// nothing in a widget test raises the view's insets on its own
void _raiseKeyboard(WidgetTester tester) {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.resetViewInsets);
}

void main() {
  testWidgets('an account with no semesters is told to make one', (
    tester,
  ) async {
    await tester.pumpWidget(_host(repository: _FakeTranscriptRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No semesters yet'), findsOneWidget);
    // the one line and the way forward, with no title over them
    expect(find.text('Gradus'), findsNothing);
    expect(
      find.widgetWithText(AppPrimaryButton, 'Add semester'),
      findsOneWidget,
      reason: 'an empty screen without a way forward is a dead end',
    );
    expect(
      find.widgetWithText(AppCard, 'Add course'),
      findsNothing,
      reason: 'a course has nowhere to go until a semester exists',
    );
  });

  testWidgets('the course list ends in the control that adds to it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([_course('1', 3)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppCard, 'Add course'), findsOneWidget);
    expect(
      find.byType(FloatingActionButton),
      findsNothing,
      reason: 'a button floating over the list covered its last row',
    );

    await tester.tap(find.widgetWithText(AppCard, 'Add course'));
    await tester.pumpAndSettle();

    expect(find.text('Add course'), findsWidgets);
    expect(find.byType(TextFormField), findsWidgets);
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
    // with nothing to average, the GPA panel has nothing to say
    expect(find.text('Semester GPA'), findsNothing);
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
    // a host may register no delegate of its own, so the feature scopes its own
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

    testWidgets('the plus beside the chooser adds another', (tester) async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add semester'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Spring 2027');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.transcript.semesters.length, 2);
      expect(find.text('Spring 2027'), findsWidgets);
    });

    testWidgets('only a term on screen can be opened', (tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // the all-semesters card stands for no one term, so it opens nothing
      await tester.tap(find.text('All semesters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppCard, 'Cumulative GPA'));
      await tester.pumpAndSettle();

      expect(find.text('Edit semester'), findsNothing);
      expect(find.byTooltip('Add semester'), findsOneWidget);

      // the section header repeats the name, the chip is the one in a card
      await tester.tap(find.widgetWithText(AppCard, 'Fall 2026'));
      await tester.pumpAndSettle();
      await _openSemesterSheet(tester);

      expect(find.text('Edit semester'), findsOneWidget);
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

      await _openSemesterSheet(tester);

      expect(find.text('Move or delete its courses first'), findsOneWidget);

      await tester.ensureVisible(find.text('Delete'));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Delete this semester?'),
        findsNothing,
        reason: 'the control is closed, not merely explained afterwards',
      );
      expect(find.text('Fall 2026'), findsWidgets);
      expect(find.text('Course 1'), findsOneWidget);
    });

    testWidgets('each term heading carries that term\'s own figures', (
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
                _course('1', 3),
                _course('2', 3, semesterId: 'spring'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All semesters'));
      await tester.pumpAndSettle();

      expect(
        find.text('GPA 4.00  |  3 credits'),
        findsNWidgets(2),
        reason: 'a term is grouped under its own total, not only the card one',
      );
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

    testWidgets('each view reports the one figure it is about', (tester) async {
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

      // a term reports its own average, the cumulative belongs to all terms
      expect(find.text('Semester GPA'), findsOneWidget);
      expect(find.text('4.00'), findsWidgets);
      expect(find.text('Cumulative GPA'), findsNothing);

      await tester.tap(find.text('All semesters'));
      await tester.pumpAndSettle();

      expect(find.text('Cumulative GPA'), findsOneWidget);
      expect(find.text('Semester GPA'), findsNothing);
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

      await tester.enterText(find.byType(TextFormField).at(1), 'MATH 273');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Linear Algebra',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '3');
      await tester.tap(
        find.widgetWithText(GradusChooserField, 'Not graded yet'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Linear Algebra'), findsOneWidget);
      // the code sits with the credits on the card's own detail line
      expect(find.textContaining('MATH 273'), findsOneWidget);
      expect(find.text('4.00'), findsWidgets);
      expect(repository.transcript.courses, hasLength(1));
    });

    testWidgets('the grade chooser groups the scale by family', (tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openCourse(tester, 'Course 1');
      await tester.tap(find.byTooltip('Edit course'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(GradusChooserField, 'A'));
      await tester.pumpAndSettle();

      // a row of its own for each family, with the singletons folded in
      final rows = tester
          .widgetList<Wrap>(find.byType(Wrap))
          .where((wrap) => wrap.children.isNotEmpty)
          .toList();

      expect(rows, hasLength(6));
      expect(rows[0].children, hasLength(2), reason: 'A and A-');
      expect(rows[1].children, hasLength(3), reason: 'B+, B and B-');
      expect(rows[3].children, hasLength(3), reason: 'D+, D and F');
      expect(
        rows[4].children,
        hasLength(6),
        reason: 'P, AU, I, IP, W and AW keep a line of their own',
      );
      expect(rows[5].children, hasLength(1), reason: 'Not graded yet');
    });

    testWidgets('the card carries no menu of its own', (tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(
            transcript: _oneTerm([_course('1', 3)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // the course opens on a tap, so a second control on the row is clutter
      expect(find.byTooltip('Options for Course 1'), findsNothing);

      await _openCourse(tester, 'Course 1');

      // the one icon-only control on the screen names what it acts on
      expect(find.bySemanticsLabel('Edit course'), findsOneWidget);
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

      await _openCourse(tester, 'Course 1');
      await tester.tap(find.byTooltip('Edit course'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this course?'), findsOneWidget);
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Course 1'),
        findsNothing,
        reason: 'the detail route goes away with the course it described',
      );
      expect(repository.transcript.courses, isEmpty);
    });

    testWidgets('a cancelled deletion keeps the course', (tester) async {
      final repository = _FakeTranscriptRepository(
        transcript: _oneTerm([_course('1', 3)]),
      );
      await tester.pumpWidget(_host(repository: repository));
      await tester.pumpAndSettle();

      await _openCourse(tester, 'Course 1');
      await tester.tap(find.byTooltip('Edit course'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Course 1'), findsWidgets);
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

      expect(find.text('4.00'), findsWidgets);
      // the row names the course, the course itself explains its grading
      expect(
        find.text('Counts as attempted credit, not toward the GPA.'),
        findsNothing,
      );
      // the card reports the average and what it was earned over
      // both courses are attempted, the P earns its credit without points
      expect(find.text('6 credits earned'), findsOneWidget);
      expect(find.text('Credits enrolled'), findsNothing);

      await _openCourse(tester, 'Course 2');

      expect(
        find.text('Counts as attempted credit, not toward the GPA.'),
        findsOneWidget,
      );
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

      // the row carries what names the course, not what it has earned
      expect(find.text('Graded weight (60% unallocated)'), findsNothing);
      // the summary card reports credits too, so the row's own line is scoped
      expect(
        find.descendant(
          of: find.widgetWithText(AppCard, 'Course 1'),
          matching: find.text('3 credits'),
        ),
        findsOneWidget,
      );

      await _openCourse(tester, 'Course 1');

      expect(find.text('Graded weight (60% unallocated)'), findsOneWidget);
      expect(find.text('90.0%'), findsWidgets);
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

      // an icon-only control needs a label a screen reader can read
      expect(find.bySemanticsLabel('Add semester'), findsOneWidget);
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

    // the letter is muted on the row, and the course says why when opened
    expect(find.text('P'), findsOneWidget);
    expect(
      find.text('Counts as attempted credit, not toward the GPA.'),
      findsNothing,
    );
  });

  testWidgets('an undefined average says why instead of showing a dash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([
            _course(
              '1',
              3,
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

    expect(find.text('Not enough graded credits yet'), findsOneWidget);

    // a dash is a figure a reader has to decode, the sentence above says it
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Semester GPA'),
          matching: find.byType(AppCard),
        ),
        matching: find.text('—'),
      ),
      findsNothing,
    );
  });

  testWidgets('a course with no grade yet carries no badge', (tester) async {
    await tester.pumpWidget(
      _host(
        repository: _FakeTranscriptRepository(
          transcript: _oneTerm([_course('1', 3, grade: null)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsNothing);
  });

  testWidgets('an ungraded course leaves the panel off the screen', (
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

    expect(find.text('Course 1'), findsOneWidget);
    // an average of nothing says nothing; the course list is the whole screen
    expect(find.text('Semester GPA'), findsNothing);
    expect(find.text('Not enough graded credits yet'), findsNothing);

    // the panel used to hold the chips off the list, so its absence must not
    // leave the first course sitting on top of them
    expect(
      tester.getRect(find.widgetWithText(AppCard, 'Course 1')).top,
      greaterThanOrEqualTo(tester.getRect(find.text('All semesters')).bottom),
    );
  });

  group('focus mode', () {
    Future<void> openCourseForm(WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          repository: _FakeTranscriptRepository(transcript: _oneTerm(const [])),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppPrimaryButton, 'Add course'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the field with the keyboard is all the form leaves on screen',
      (tester) async {
        await openCourseForm(tester);
        _raiseKeyboard(tester);
        await tester.tap(find.byType(TextFormField).at(0));
        await tester.pumpAndSettle();

        expect(_inCourseForm('Course'), findsOneWidget);
        for (final gone in const [
          'Add course',
          'Course code',
          'Credits',
          'Semester',
          'Grade',
          'Save',
        ]) {
          expect(_inCourseForm(gone), findsNothing, reason: gone);
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
      await openCourseForm(tester);
      _raiseKeyboard(tester);
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      expect(_inCourseForm('Course code'), findsOneWidget);
      expect(_inCourseForm('Course'), findsNothing);
      expect(
        _inCourseForm('Done'),
        findsOneWidget,
        reason:
            'a folded field is out of the tree, so the key that walks the '
            'form has to open the next fold rather than hunt for a node',
      );
    });

    testWidgets('what was typed survives the fold', (tester) async {
      await openCourseForm(tester);
      await tester.enterText(find.byType(TextFormField).at(1), 'MATH 273');
      _raiseKeyboard(tester);
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pumpAndSettle();
      await tester.tap(_inCourseForm('Done'));
      await tester.pumpAndSettle();

      expect(find.text('MATH 273'), findsOneWidget);
    });

    testWidgets('without an on-screen keyboard nothing folds', (tester) async {
      await openCourseForm(tester);
      // a hardware keyboard, as on a simulator: focus with no insets
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pumpAndSettle();

      for (final label in const ['Course code', 'Semester', 'Save']) {
        expect(_inCourseForm(label), findsOneWidget, reason: label);
      }
      expect(_inCourseForm('Done'), findsNothing);
    });
  });
}
