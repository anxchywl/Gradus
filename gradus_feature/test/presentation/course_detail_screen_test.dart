import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:gradus_feature/src/domain/repositories.dart';
import 'package:gradus_feature/src/presentation/assignment_form.dart';

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
      assignments: assignments,
    ),
  ],
);

// the action sits at the end of the list rather than floating over it, so it
// is the last card on the screen in every locale
Future<void> _tapAddAssignment(WidgetTester tester) async {
  final add = find.byType(AppCard).last;
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
  await tester.pumpAndSettle();
}

// the row is the control: it opens the form that edits and removes it
Future<void> _openAssignment(WidgetTester tester, String name) async {
  // the add button floats over the end of the list, so the row is brought out
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
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

    expect(find.text('No assignments yet'), findsOneWidget);
    expect(
      find.text('Assignments'),
      findsNothing,
      reason: 'a heading over an empty list names nothing',
    );
    // the code and the credits sit under the name the card carries
    expect(find.textContaining('CSCI 235'), findsOneWidget);
    expect(
      find.widgetWithText(AppCard, 'Add assignment'),
      findsOneWidget,
      reason: 'the empty list still ends in the control that fills it',
    );
    expect(
      find.byType(FloatingActionButton),
      findsNothing,
      reason: 'a button floating over the list covered its last row',
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
    // an absent grade is left absent rather than spelled out twice over
    expect(
      find.text('Nothing is graded yet, so there is no grade to show.'),
      findsNothing,
    );
    expect(find.text('Not graded yet'), findsNothing);
    expect(find.text('Current grade'), findsNothing);
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

    await _openAssignment(tester, 'Midterm');
    await tester.enterText(find.byType(TextFormField).at(3), '70');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      repository.transcript.courses.single.assignments.single.earnedScore,
      70,
      reason: 'the assignment being edited must not block its own weight',
    );
    // the course letter, and the same letter on the assignment that set it
    expect(
      find.text('C+'),
      findsNWidgets(2),
      reason: '70% is a C on this scale',
    );
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

    await _openAssignment(tester, 'Midterm');
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.transcript.courses.single.assignments, hasLength(2));

    await _openAssignment(tester, 'Midterm');
    await tester.ensureVisible(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this assignment?'), findsOneWidget);
    // the answer to the question is the big button, the way out is small
    expect(find.widgetWithText(AppPrimaryButton, 'Delete'), findsOneWidget);
    expect(find.widgetWithText(AppPrimaryButton, 'Cancel'), findsNothing);
    // the form's own Delete is behind the sheet, the confirmation's is last
    await tester.tap(find.text('Delete').last);
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
    expect(find.text('60%'), findsWidgets);
    expect(find.text('96.0%'), findsOneWidget);
    // a setup that adds up is the normal case, it needs no announcement
    expect(find.text('Grading setup adds up to 100%.'), findsNothing);
    // where a grade came from is visible from the assignments listed below
    expect(find.text('From assignments'), findsNothing);
    // the course letter, and the letter the marked assignment earned
    expect(find.text('A-'), findsNWidgets(2));
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

    // the shortfall qualifies the bar, so it reads as part of its label
    expect(find.text('Graded weight (70% unallocated)'), findsOneWidget);
  });

  testWidgets('a letter with no points says what it does to the average', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            grade: const Grade(
              letter: 'P',
              qualityPoints: 0,
              countsTowardGpa: false,
            ),
          ),
        ),
      ),
    );
    await _openCourse(tester);

    expect(
      find.text('Counts as attempted credit, not toward the GPA.'),
      findsOneWidget,
    );
  });

  testWidgets('a hand-entered letter shows without a provenance line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(grade: const Grade(letter: 'B', qualityPoints: 3)),
        ),
      ),
    );
    await _openCourse(tester);

    expect(find.text('B'), findsOneWidget);
    expect(find.text('Entered by hand'), findsNothing);
  });

  testWidgets('a course whose weights add up offers no more assignments', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [
              _assignment('a1', 'Midterm', weight: 40, earnedScore: 90),
              _assignment('a2', 'Final', weight: 60, earnedScore: 80),
            ],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    // there is no weight left to give one, so the control would only mislead
    expect(find.widgetWithText(AppCard, 'Add assignment'), findsNothing);
    expect(
      find.text('Graded weight'),
      findsOneWidget,
      reason: 'the weight belongs beside the assignments that carry it',
    );
  });

  testWidgets('an unmarked assignment shows no figure at all', (tester) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(assignments: [_assignment('a1', 'Midterm')]),
        ),
      ),
    );
    await _openCourse(tester);

    expect(find.text('Midterm'), findsOneWidget);
    // nothing is marked, so there is no letter and no stand-in for one
    expect(
      find.descendant(
        of: find.widgetWithText(AppCard, 'Midterm'),
        matching: find.text('—'),
      ),
      findsNothing,
    );
  });

  testWidgets('an unmarked row keeps the badge column beside a marked one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [
              _assignment('a1', 'Midterm', earnedScore: 80),
              _assignment('a2', 'Final'),
            ],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    // the names stay in one column whichever rows are marked
    expect(
      tester.getTopLeft(find.text('Final')).dx,
      tester.getTopLeft(find.text('Midterm')).dx,
    );
  });

  testWidgets('an assignment shows its mark beside its percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _FakeTranscriptRepository(
          _transcript(
            assignments: [
              _assignment('a1', 'Midterm', weight: 100, earnedScore: 45),
            ],
          ),
        ),
      ),
    );
    await _openCourse(tester);

    // a percentage alone hides the marks it was worked out from
    expect(find.text('45/100'), findsOneWidget);
    expect(find.text('45.0%'), findsWidgets);
  });

  testWidgets('the maximum stands without a sentence explaining it', (
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
      findsNothing,
    );
  });

  testWidgets('a course deleted underneath the detail says so', (tester) async {
    final repository = _FakeTranscriptRepository(_transcript());
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Programming Languages'));
    await tester.pumpAndSettle();

    await _tapAddAssignment(tester);
    // the sheet has no cancel of its own; it is left by tapping outside it
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.textContaining('CSCI 235'), findsOneWidget);
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

    // the course's own controls are the icon-only ones on this screen
    expect(find.bySemanticsLabel('Edit course'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
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

    final maximum = tester.getTopLeft(find.text('Max possible'));
    final credits = tester.getTopLeft(find.text('Credits'));

    expect(
      credits.dy,
      maximum.dy,
      reason: 'a stat grid that collapses turns the card into a tower',
    );
    expect(credits.dx, greaterThan(maximum.dx));
  });

  testWidgets('Back leaves focus mode once for good', (tester) async {
    await tester.pumpWidget(_host(_FakeTranscriptRepository(_transcript())));
    await _openCourse(tester);
    await _tapAddAssignment(tester);

    Finder inForm(String text) => find.descendant(
      of: find.byType(AssignmentForm),
      matching: find.text(text),
    );

    // nothing in a widget test raises the view's insets on its own, and the
    // form no longer opens with a field already holding the keyboard
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.tap(find.byType(TextFormField).first);
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
          'leaving focus mode brings the whole form back, and the field it '
          'came from must not take the keyboard again',
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
