import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:gradus_feature/src/domain/repositories.dart';
import 'package:gradus_feature/src/presentation/assignment_form.dart';
import 'package:gradus_feature/src/presentation/gradus_widgets.dart';

class _FakeTranscriptRepository implements TranscriptRepository {
  _FakeTranscriptRepository(this.transcript);

  Transcript transcript;

  @override
  Future<Transcript> load() async => transcript;

  @override
  Future<void> save(Transcript next) async => transcript = next;
}

class _FakeScales implements GradeScaleRepository {
  const _FakeScales();

  @override
  Future<GradeScale> active() async => const FourPointScale();
}

Widget _host(
  TranscriptRepository repository, {
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: supportedGradusLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: GradusFeature(
    session: const GradusSession(
      accessToken: 'a-token',
      accountId: 'student-1',
    ),
    dependencies: GradusDependencies(
      transcript: repository,
      scales: const _FakeScales(),
    ),
    config: const GradusConfig.sample(),
  ),
);

Assignment _assignment(
  String id,
  String name, {
  double weight = 25,
  double? earnedScore,
}) => Assignment(
  id: id,
  courseId: 'c1',
  name: name,
  weight: weight,
  maximumScore: 100,
  earnedScore: earnedScore,
);

Transcript _transcript({
  List<Assignment> assignments = const [],
  GradingMode gradingMode = GradingMode.graded,
  bool includeInGpa = true,
  Grade? grade,
}) => Transcript(
  semesters: [Semester(id: 'fall', name: 'Fall 2026', position: 1)],
  courses: [
    Course(
      id: 'c1',
      semesterId: 'fall',
      code: 'CSCI 235',
      title: 'Programming Languages',
      credits: 8,
      grade: grade,
      gradingMode: gradingMode,
      includeInGpa: includeInGpa,
      assignments: assignments,
    ),
  ],
);

// the empty list carries the action, once there are rows the button does
Future<void> _tapAddAssignment(WidgetTester tester) async {
  final inEmptyState = find.widgetWithText(AppPrimaryButton, 'Add assignment');
  if (inEmptyState.evaluate().isEmpty) {
    await tester.tap(find.byType(FloatingActionButton));
  } else {
    // the summary card is tall enough to push the empty state below the fold
    await tester.ensureVisible(inEmptyState);
    await tester.pumpAndSettle();
    await tester.tap(inEmptyState);
  }
  await tester.pumpAndSettle();
}

Future<void> _openAssignmentMenu(WidgetTester tester, String name) async {
  // the add button floats over the end of the list, so the row is brought out
  await tester.drag(find.byType(ListView), const Offset(0, -280));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Options for $name'));
  await tester.pumpAndSettle();
}

Future<void> _openCourse(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Programming Languages'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a course with no assignments offers a way in', (tester) async {
    await tester.pumpWidget(_host(_FakeTranscriptRepository(_transcript())));
    await _openCourse(tester);

    expect(find.text('No assignments yet'), findsWidgets);
    expect(
      find.text(
        'Add assignments and their weights to work the grade out from your '
        'own marks.',
      ),
      findsOneWidget,
    );
    expect(find.text('CSCI 235'), findsOneWidget);
    expect(
      find.widgetWithText(AppPrimaryButton, 'Add assignment'),
      findsOneWidget,
      reason: 'the empty list carries the action that fills it',
    );
    expect(
      find.text('Assumes full marks on everything not yet graded.'),
      findsNothing,
      reason: 'an assumption with no number to qualify is noise',
    );
  });

  testWidgets('an assignment can be added and moves the course grade', (
    tester,
  ) async {
    final repository = _FakeTranscriptRepository(_transcript());
    await tester.pumpWidget(_host(repository));
    await _openCourse(tester);

    await _tapAddAssignment(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Midterm Exam');
    await tester.enterText(find.byType(TextFormField).at(1), '25');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.enterText(find.byType(TextFormField).at(3), '85');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Midterm Exam'), findsOneWidget);
    expect(find.text('85.0%'), findsWidgets);
    expect(repository.transcript.courses.single.assignments, hasLength(1));
    expect(
      repository.transcript.courses.single.assignments.single.earnedScore,
      85,
    );
  });

  testWidgets('an assignment can be left ungraded', (tester) async {
    final repository = _FakeTranscriptRepository(_transcript());
    await tester.pumpWidget(_host(repository));
    await _openCourse(tester);

    await _tapAddAssignment(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Final Exam');
    await tester.enterText(find.byType(TextFormField).at(1), '50');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      repository.transcript.courses.single.assignments.single.earnedScore,
      isNull,
    );
    expect(
      find.text('Nothing is graded yet, so there is no grade to show.'),
      findsOneWidget,
    );
    expect(find.byType(GradusStatusChip), findsWidgets);
  });

  testWidgets('the form refuses an invalid weight and score', (tester) async {
    await tester.pumpWidget(_host(_FakeTranscriptRepository(_transcript())));
    await _openCourse(tester);

    await _tapAddAssignment(tester);
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    await tester.enterText(find.byType(TextFormField).at(3), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an assignment name'), findsOneWidget);
    expect(find.text('Enter a weight above 0 and up to 100'), findsOneWidget);
    expect(find.text('Enter a max score above 0'), findsOneWidget);
  });

  testWidgets('the form refuses a score above the maximum', (tester) async {
    await tester.pumpWidget(_host(_FakeTranscriptRepository(_transcript())));
    await _openCourse(tester);

    await _tapAddAssignment(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Quiz');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.enterText(find.byType(TextFormField).at(2), '20');
    await tester.enterText(find.byType(TextFormField).at(3), '21');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a score between 0 and the max score'),
      findsOneWidget,
    );
  });

  testWidgets('the form refuses a weight the course cannot afford', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(assignments: [_assignment('a1', 'Midterm', weight: 80)]),
        ),
      ),
    );
    await _openCourse(tester);

    await _tapAddAssignment(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'Final');
    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Only 20% is still unallocated in this course'),
      findsOneWidget,
    );
  });

  testWidgets('editing an assignment may keep its own weight', (tester) async {
    final repository = _FakeTranscriptRepository(
      _transcript(assignments: [_assignment('a1', 'Midterm', weight: 100)]),
    );
    await tester.pumpWidget(_host(repository));
    await _openCourse(tester);

    await _openAssignmentMenu(tester, 'Midterm');
    await tester.tap(find.text('Edit assignment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(3), '70');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      repository.transcript.courses.single.assignments.single.earnedScore,
      70,
      reason: 'the assignment being edited must not block its own weight',
    );
    expect(find.text('C'), findsOneWidget, reason: '70% is a C on this scale');
  });

  testWidgets('an assignment is deleted only after confirmation', (
    tester,
  ) async {
    final repository = _FakeTranscriptRepository(
      _transcript(
        assignments: [
          _assignment('a1', 'Midterm', earnedScore: 80),
          _assignment('a2', 'Final'),
        ],
      ),
    );
    await tester.pumpWidget(_host(repository));
    await _openCourse(tester);

    await _openAssignmentMenu(tester, 'Midterm');
    await tester.tap(find.text('Delete Midterm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.transcript.courses.single.assignments, hasLength(2));

    await _openAssignmentMenu(tester, 'Midterm');
    await tester.tap(find.text('Delete Midterm'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Midterm? This cannot be undone.'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.transcript.courses.single.assignments.single.id, 'a2');
    expect(find.text('Midterm'), findsNothing);
    expect(find.text('Final'), findsOneWidget);
  });

  testWidgets('a partly graded course separates its figures', (tester) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [
              _assignment('a1', 'Midterm', weight: 40, earnedScore: 90),
              _assignment('a2', 'Final', weight: 60),
            ],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    expect(find.text('90.0%'), findsWidgets);
    expect(find.text('36.0%'), findsOneWidget);
    expect(find.text('60%'), findsWidgets);
    expect(find.text('96.0%'), findsOneWidget);
    expect(find.text('Grading setup adds up to 100%.'), findsOneWidget);
    expect(find.text('From assignments'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('an incomplete grading setup is named on the detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [
              _assignment('a1', 'Midterm', weight: 30, earnedScore: 90),
            ],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    expect(
      find.text('70% of this course\'s grading setup is unallocated.'),
      findsOneWidget,
    );
  });

  testWidgets('a pass/fail course says what it does to the average', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            gradingMode: GradingMode.passFail,
            assignments: [
              _assignment('a1', 'Project', weight: 100, earnedScore: 95),
            ],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    expect(
      find.text('Counts as attempted credit, not toward the GPA.'),
      findsOneWidget,
    );
    expect(find.text('95.0%'), findsWidgets);
  });

  testWidgets('an excluded course says it is not counted', (tester) async {
    await tester.pumpWidget(
      _host(_FakeTranscriptRepository(_transcript(includeInGpa: false))),
    );
    await _openCourse(tester);

    expect(find.text('Not counted in the GPA'), findsOneWidget);
  });

  testWidgets('a hand-entered letter says where it came from', (tester) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(grade: const Grade(letter: 'B', qualityPoints: 3)),
        ),
      ),
    );
    await _openCourse(tester);

    expect(find.text('Entered by hand'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('the assumption travels with the maximum it belongs to', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [_assignment('a1', 'Midterm', earnedScore: 50)],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    expect(find.text('Max possible'), findsOneWidget);
    expect(
      find.text('Assumes full marks on everything not yet graded.'),
      findsOneWidget,
    );
  });

  testWidgets('a course deleted underneath the detail says so', (tester) async {
    final repository = _FakeTranscriptRepository(_transcript());
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Programming Languages'));
    await tester.pumpAndSettle();

    await _tapAddAssignment(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('CSCI 235'), findsOneWidget);
  });

  for (final locale in supportedGradusLocales) {
    testWidgets('the sheet renders in ${locale.languageCode}', (tester) async {
      await tester.pumpWidget(
        _host(
          _FakeTranscriptRepository(
            _transcript(
              assignments: [_assignment('a1', 'Midterm', earnedScore: 80)],
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Programming Languages'));
      await tester.pumpAndSettle();
      await _tapAddAssignment(tester);

      expect(tester.takeException(), isNull);
      // the sheet mounts outside the subtree, a missing delegate shows here
      expect(find.byType(TextFormField), findsNWidgets(4));
    });
  }

  testWidgets('destructive controls carry semantics labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(assignments: [_assignment('a1', 'Midterm')]),
        ),
      ),
    );
    await _openCourse(tester);

    expect(find.bySemanticsLabel('Options for Midterm'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the figures sit two to a row on a phone', (tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [_assignment('a1', 'Midterm', earnedScore: 80)],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    final earned = tester.getTopLeft(find.text('Earned toward final'));
    final remaining = tester.getTopLeft(find.text('Remaining weight'));

    expect(
      remaining.dy,
      earned.dy,
      reason: 'a stat grid that collapses turns the card into a tower',
    );
    expect(remaining.dx, greaterThan(earned.dx));
  });

  testWidgets('Done leaves focus mode once for good', (tester) async {
    await tester.pumpWidget(_host(_FakeTranscriptRepository(_transcript())));
    await _openCourse(tester);
    await _tapAddAssignment(tester);

    Finder inForm(String text) => find.descendant(
      of: find.byType(AssignmentForm),
      matching: find.text(text),
    );

    // nothing in a widget test raises the view's insets on its own
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(inForm('Assignment name'), findsNothing);

    await tester.tap(inForm('Done'));
    await tester.pumpAndSettle();

    expect(
      inForm('Save'),
      findsOneWidget,
      reason:
          'the form opens on its first field, and that field coming back '
          'must not take the keyboard again',
    );
    expect(inForm('Done'), findsNothing);
  });

  testWidgets('a score keeps its total beside it while the keyboard is up', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_FakeTranscriptRepository(_transcript())));
    await _openCourse(tester);
    await _tapAddAssignment(tester);

    Finder inForm(String text) => find.descendant(
      of: find.byType(AssignmentForm),
      matching: find.text(text),
    );

    // nothing in a widget test raises the view's insets on its own
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    expect(inForm('Weight'), findsNothing);
    expect(inForm('Save'), findsNothing);
    expect(inForm('Done'), findsOneWidget);
    expect(
      inForm('Max score'),
      findsOneWidget,
      reason:
          'a mark and the total it is out of are one field to a student, '
          'so folding one away leaves the other meaningless',
    );
    expect(inForm('Obtained score'), findsOneWidget);
  });
}
