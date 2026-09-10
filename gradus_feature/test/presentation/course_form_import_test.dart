import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:gradus_feature/src/l10n/gradus_strings.dart';
import 'package:gradus_feature/src/presentation/course_form.dart';

const SyllabusDraft complete = SyllabusDraft(
  code: 'MATH 273',
  title: 'Linear Algebra',
  credits: 8,
  creditUnit: 'ECTS',
  term: 'Fall 2026',
  assessments: [
    SyllabusAssessment(name: 'Midterm', weight: 40),
    SyllabusAssessment(name: 'Final', weight: 60),
  ],
);

Widget host({
  Future<SyllabusDraft?> Function()? onImport,
  void Function(Course)? onSaved,
}) => MaterialApp(
  supportedLocales: supportedGradusLocales,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: AppPrimaryButton(
          text: 'open',
          onPressed: () async {
            final course = await showModalBottomSheet<Course>(
              context: context,
              isScrollControlled: true,
              builder: (_) => GradusStringsScope(
                child: CourseForm(
                  scale: const FourPointScale(),
                  semesters: [Semester(id: 's1', name: 'Fall 2026')],
                  initialSemesterId: 's1',
                  onImportSyllabus: onImport,
                ),
              ),
            );
            if (course != null) onSaved?.call(course);
          },
        ),
      ),
    ),
  ),
);

// the sheet grows with the proposal, and a control scrolled off the bottom of
// a 600pt test viewport cannot be tapped
Future<void> openSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // the three text fields of the course form, in the order they are built
  Iterable<bool> fieldStates(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .map((field) => field.enabled ?? true);

  testWidgets('the fields are locked while a read is in flight', (
    tester,
  ) async {
    final pending = Completer<SyllabusDraft?>();
    await tester.pumpWidget(host(onImport: () => pending.future));
    await openSheet(tester);

    expect(fieldStates(tester), everyElement(isTrue));

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pump();

    // a draft is about to overwrite these, so they must not be typed into
    expect(fieldStates(tester), everyElement(isFalse));

    pending.complete(complete);
    await tester.pumpAndSettle();

    expect(fieldStates(tester), everyElement(isTrue));
  });

  testWidgets('save is refused while a read is in flight', (tester) async {
    Course? saved;
    final pending = Completer<SyllabusDraft?>();
    await tester.pumpWidget(
      host(onImport: () => pending.future, onSaved: (course) => saved = course),
    );
    await openSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(1), 'Typed by hand');
    await tester.tap(find.text('Fill from syllabus'));
    await tester.pump();

    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump();

    // saving mid-read would store a form the draft is about to change
    expect(saved, isNull);

    pending.complete(complete);
    await tester.pumpAndSettle();
  });

  testWidgets('a read that fails gives the fields back', (tester) async {
    await tester.pumpWidget(
      host(
        onImport: () async =>
            throw const SyllabusImportFailure(SyllabusImportProblem.network),
      ),
    );
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(fieldStates(tester), everyElement(isTrue));
  });

  testWidgets('a read that runs long says so rather than looking stuck', (
    tester,
  ) async {
    final pending = Completer<SyllabusDraft?>();
    await tester.pumpWidget(host(onImport: () => pending.future));
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pump();

    expect(find.text('Reading the syllabus'), findsOneWidget);
    expect(find.text('Still reading, this can take a moment'), findsNothing);

    // a read that has gone on this long is indistinguishable from a hang
    await tester.pump(importPatience);

    expect(find.text('Reading the syllabus'), findsNothing);
    expect(find.text('Still reading, this can take a moment'), findsOneWidget);

    pending.complete(complete);
    await tester.pumpAndSettle();

    expect(find.text('Still reading, this can take a moment'), findsNothing);
    expect(find.text('Fill from syllabus'), findsOneWidget);
  });

  testWidgets('a read that returns quickly never escalates the wait', (
    tester,
  ) async {
    await tester.pumpWidget(host(onImport: () async => complete));
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(find.text('Still reading, this can take a moment'), findsNothing);
  });

  testWidgets('the wait cannot be started twice, which would be paid twice', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<SyllabusDraft?>();
    await tester.pumpWidget(
      host(
        onImport: () {
          calls++;
          return pending.future;
        },
      ),
    );
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pump();
    await tester.tap(find.text('Reading the syllabus'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);

    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('leaving mid-read does not leave a timer behind', (tester) async {
    final pending = Completer<SyllabusDraft?>();
    await tester.pumpWidget(host(onImport: () => pending.future));
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pump();

    // the sheet closing while a read is in flight must not strand the timer
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    pending.complete(complete);
    await tester.pumpAndSettle();
  });

  testWidgets('the control is absent when no syllabus can be read', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await openSheet(tester);

    expect(find.text('Fill from syllabus'), findsNothing);
  });

  testWidgets('an import fills the fields and lists what it proposed', (
    tester,
  ) async {
    await tester.pumpWidget(host(onImport: () async => complete));
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'MATH 273'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Linear Algebra'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
    expect(find.text('Midterm'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
  });

  testWidgets('nothing is saved until save is tapped', (tester) async {
    Course? saved;
    await tester.pumpWidget(
      host(onImport: () async => complete, onSaved: (course) => saved = course),
    );
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(saved, isNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.assignments.length, 2);
    expect(saved!.assignments.first.name, 'Midterm');
    // a syllabus states weights, never a maximum score
    expect(saved!.assignments.first.maximumScore, 100);
    // the grade stays unset, and every score stays unmarked
    expect(saved!.grade, isNull);
    expect(saved!.assignments.every((entry) => !entry.isGraded), isTrue);
  });

  testWidgets('a partial draft names what it could not find', (tester) async {
    await tester.pumpWidget(
      host(onImport: () async => const SyllabusDraft(title: 'Linear Algebra')),
    );
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(
      find.text('Not found in the syllabus: code, credits, assignments'),
      findsOneWidget,
    );
  });

  testWidgets('an imported entry can be dropped before saving', (tester) async {
    Course? saved;
    await tester.pumpWidget(
      host(onImport: () async => complete, onSaved: (course) => saved = course),
    );
    await openSheet(tester);
    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Remove Midterm'));
    await tester.pumpAndSettle();

    expect(find.text('Midterm'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved!.assignments.single.name, 'Final');
  });

  testWidgets('weights over budget block the save rather than being scaled', (
    tester,
  ) async {
    Course? saved;
    await tester.pumpWidget(
      host(
        onImport: () async => const SyllabusDraft(
          code: 'MATH 273',
          title: 'Linear Algebra',
          credits: 8,
          assessments: [
            SyllabusAssessment(name: 'Midterm', weight: 70),
            SyllabusAssessment(name: 'Final', weight: 70),
          ],
        ),
        onSaved: (course) => saved = course,
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('over 100%'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNull);

    await tester.tap(find.bySemanticsLabel('Remove Midterm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved!.assignments.single.name, 'Final');
  });

  testWidgets('a refusal is named rather than passing silently', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        onImport: () async =>
            throw const SyllabusImportFailure(SyllabusImportProblem.noText),
      ),
    );
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no text to read'), findsOneWidget);
  });

  testWidgets('a cancelled picker changes nothing', (tester) async {
    await tester.pumpWidget(host(onImport: () async => null));
    await openSheet(tester);

    await tester.tap(find.text('Fill from syllabus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not found'), findsNothing);
    expect(find.textContaining('could not'), findsNothing);
  });

  testWidgets('the control says where the document goes', (tester) async {
    await tester.pumpWidget(host(onImport: () async => complete));
    await openSheet(tester);

    expect(find.textContaining('sent to the Gradus server'), findsOneWidget);
  });
}
