import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/assignment.dart';
import '../domain/course.dart';
import '../domain/errors.dart';
import '../domain/grade.dart';
import '../domain/semester.dart';
import '../domain/syllabus.dart';
import '../domain/weights.dart';
import '../l10n/gradus_strings.dart';
import 'focus_mode.dart';
import 'gradus_formatting.dart';
import 'gradus_widgets.dart';

// how long a read may run before the wait has to say something other than what
// it said at the start
const Duration importPatience = Duration(seconds: 5);

// the sheet swaps its whole body for a chooser and back, one motion
const Duration _chooserDuration = Duration(milliseconds: 340);

const Curve _chooserCurve = Curves.easeOutCubic;

// which chooser has taken the sheet over, if any
enum _Chooser { semester, grade }

enum _Field { title, code, credits }

// what the syllabus did not state, named on screen rather than guessed
enum _MissingField { code, title, credits, assignments }

// what the import card is showing: the offer, the wait, the result, a refusal
enum _ImportState { idle, reading, done, failed }

class CourseForm extends StatefulWidget {
  const CourseForm({
    super.key,
    required this.scale,
    required this.semesters,
    required this.initialSemesterId,
    this.existing,
    this.onDelete,
    this.onImportSyllabus,
  });

  final GradeScale scale;
  final List<Semester> semesters;
  final String initialSemesterId;
  final Course? existing;

  // an edited course is removed from the sheet that opened it
  final VoidCallback? onDelete;

  // absent when there is no backend to read a syllabus, which hides the control
  final Future<SyllabusDraft?> Function()? onImportSyllabus;

  @override
  State<CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  final _formKey = GlobalKey<FormState>();
  final SheetFocusMode _focus = SheetFocusMode();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.code ?? '',
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _credits = TextEditingController(
    text: widget.existing?.credits.toString() ?? '',
  );
  late String _semesterId =
      widget.existing?.semesterId ?? widget.initialSemesterId;
  late Grade? _grade = widget.existing?.grade;
  _Chooser? _chooser;
  bool _isSubmitting = false;
  bool _isImporting = false;
  bool _importIsSlow = false;
  Timer? _importPatience;
  List<SyllabusAssessment> _imported = const [];
  SyllabusImportProblem? _importProblem;
  List<_MissingField> _importMissing = const [];
  bool _hasImported = false;

  double get _importedWeight =>
      _imported.fold(0, (total, entry) => total + entry.weight);

  bool get _isOverBudget =>
      sumHundredths(_imported.map((entry) => entry.weight)) > completeWeight;

  String _semesterLabel(GradusStrings strings) {
    for (final semester in widget.semesters) {
      if (semester.id == _semesterId) return formatSemester(strings, semester);
    }
    return strings.unnamedSemester;
  }

  void _dismiss() {
    final delete = widget.onDelete;
    Navigator.of(context).pop();
    // the confirmation belongs to the screen, which outlives this sheet
    delete?.call();
  }

  @override
  void dispose() {
    _importPatience?.cancel();
    _code.dispose();
    _title.dispose();
    _credits.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final importer = widget.onImportSyllabus;
    // a second tap would pay for a second extraction
    if (importer == null || _isImporting) return;
    setState(() {
      _isImporting = true;
      _importIsSlow = false;
      _importProblem = null;
    });
    // reads have run from three seconds to fourteen, and the long ones look
    // identical to a hang unless the wait says something new
    _importPatience = Timer(importPatience, () {
      if (mounted) setState(() => _importIsSlow = true);
    });
    try {
      final draft = await importer();
      if (!mounted) return;
      // the student cancelled the picker, which is not a failure to report
      if (draft != null) setState(() => _applyDraft(draft));
    } on SyllabusImportFailure catch (failure) {
      if (!mounted) return;
      setState(() => _importProblem = failure.problem);
    } finally {
      _importPatience?.cancel();
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importIsSlow = false;
        });
      }
    }
  }

  // extraction proposes, the student confirms: nothing here is saved until Save
  void _applyDraft(SyllabusDraft draft) {
    final missing = <_MissingField>[];
    if (draft.code != null) {
      _code.text = draft.code!;
    } else {
      missing.add(_MissingField.code);
    }
    if (draft.title != null) {
      _title.text = draft.title!;
    } else {
      missing.add(_MissingField.title);
    }
    if (draft.credits != null) {
      _credits.text = formatImportedCredits(draft.credits!);
    } else {
      missing.add(_MissingField.credits);
    }
    if (draft.assessments.isEmpty) missing.add(_MissingField.assignments);

    _imported = draft.assessments;
    _importMissing = missing;
    _hasImported = true;
  }

  void _submit() {
    // a second tap while the first is still popping would add the course twice
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    _isSubmitting = true;

    final id =
        widget.existing?.id ??
        'course_${DateTime.now().microsecondsSinceEpoch}';
    Navigator.of(context).pop(
      Course(
        id: id,
        semesterId: _semesterId,
        code: _code.text.trim(),
        title: _title.text.trim(),
        credits: double.parse(_credits.text.trim()),
        grade: _grade,
        // assignments belong to the course, so an edit here never touches them
        assignments: widget.existing?.assignments ?? _importedAssignments(id),
      ),
    );
  }

  // identifiers are generated here; nothing from the document names anything.
  // a set over 100% is left out whole, since trimming it to fit would be a guess
  List<Assignment> _importedAssignments(String courseId) => _isOverBudget
      ? const []
      : [
          for (var index = 0; index < _imported.length; index++)
            Assignment(
              id: 'assignment_${DateTime.now().microsecondsSinceEpoch}_$index',
              courseId: courseId,
              name: _imported[index].name,
              weight: _imported[index].weight,
              // a syllabus states weights, never a maximum score
              maximumScore: importedMaximumScore,
            ),
        ];

  _ImportState get _importState {
    if (_isImporting) return _ImportState.reading;
    if (_importProblem != null) return _ImportState.failed;
    if (_hasImported) return _ImportState.done;
    return _ImportState.idle;
  }

  String _importTitle(GradusStrings strings) => switch (_importState) {
    _ImportState.reading =>
      _importIsSlow ? strings.importStillRunning : strings.importRunning,
    _ImportState.done => strings.importDone,
    _ImportState.idle || _ImportState.failed => strings.importFromSyllabus,
  };

  // the card offers the fill and says nothing more until something needs the
  // student's attention: a refusal, or what a read could not fill. the
  // assignments are reviewed on the course once it is saved
  List<_CardLine> _importLines(GradusStrings strings) => switch (_importState) {
    _ImportState.idle || _ImportState.reading => const [],
    _ImportState.failed => [
      _CardLine(_problemMessage(strings, _importProblem!), isProblem: true),
    ],
    _ImportState.done => [
      if (_isOverBudget)
        _CardLine(strings.importOverBudget(_importedWeight), isProblem: true),
      if (_importMissing.isNotEmpty)
        _CardLine(
          strings.importMissingFields(
            _importMissing
                .map((field) => _fieldName(strings, field))
                .join(', '),
          ),
        ),
    ],
  };

  // the card only exists where a syllabus can actually be read
  List<Widget> _importCard(GradusStrings strings) {
    if (widget.onImportSyllabus == null || widget.existing != null) {
      return const [];
    }
    return [
      _SyllabusCard(
        state: _importState,
        title: _importTitle(strings),
        lines: _importLines(strings),
        // a second tap would pay for a second extraction, and a finished read
        // is not repeated from here
        onTap: _isImporting || _hasImported ? null : _import,
      ),
      AppSpacing.verticalLg,
      // before a read there are two ways to fill the form; after one, only
      // the fields are left to check
      if (_importState != _ImportState.done) ...[
        GradusDividerLabel(text: strings.importOrEnter),
        AppSpacing.verticalLg,
      ],
    ];
  }

  String _fieldName(GradusStrings strings, _MissingField field) =>
      switch (field) {
        _MissingField.code => strings.importFieldCode,
        _MissingField.title => strings.importFieldTitle,
        _MissingField.credits => strings.importFieldCredits,
        _MissingField.assignments => strings.importFieldAssignments,
      };

  String _problemMessage(
    GradusStrings strings,
    SyllabusImportProblem problem,
  ) => switch (problem) {
    SyllabusImportProblem.unsupportedType => strings.importUnsupportedType,
    SyllabusImportProblem.tooLarge => strings.importTooLarge,
    SyllabusImportProblem.encrypted => strings.importEncrypted,
    SyllabusImportProblem.noText => strings.importNoText,
    SyllabusImportProblem.nothingFound => strings.importNothingFound,
    SyllabusImportProblem.rateLimited => strings.importRateLimited,
    SyllabusImportProblem.unavailable => strings.importUnavailable,
    SyllabusImportProblem.network => strings.importNetwork,
  };

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        _focus.setKeyboardVisible(MediaQuery.viewInsetsOf(context).bottom > 0);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: gradusSheetPadding(context),
            child: AnimatedSize(
              duration: _chooserDuration,
              curve: _chooserCurve,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: _chooserDuration,
                switchInCurve: _chooserCurve,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (final child in previous)
                      Positioned(bottom: 0, left: 0, right: 0, child: child),
                    ?current,
                  ],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.97,
                      end: 1,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _chooser != null
                    ? _panel(context, strings)
                    : _fields(context, strings),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panel(BuildContext context, GradusStrings strings) => KeyedSubtree(
    key: ValueKey(_chooser),
    child: switch (_chooser!) {
      _Chooser.semester => GradusChooserPanel<String>(
        title: strings.semesterLabel,
        selected: _semesterId,
        onSelected: (id) => setState(() {
          _semesterId = id;
          _chooser = null;
        }),
        // a term name is long enough to want the width to itself
        rows: [
          for (final semester in widget.semesters)
            [
              GradusChooserOption(
                value: semester.id,
                label: formatSemester(strings, semester),
              ),
            ],
        ],
      ),
      _Chooser.grade => GradusChooserPanel<String?>(
        title: strings.courseGrade,
        selected: _grade?.letter,
        onSelected: (letter) => setState(() {
          _grade = letter == null ? null : widget.scale.byLetter(letter);
          _chooser = null;
        }),
        rows: _gradeRows(strings),
      ),
    },
  );

  // the scale reads as the families a student already knows, and a family too
  // small for a row of its own joins the one above rather than taking a line.
  // the administrative grades keep a line to themselves: they are a different
  // kind of answer, and folding them onto the end of D reads as one
  List<List<GradusChooserOption<String?>>> _gradeRows(GradusStrings strings) {
    final rows = <List<GradusChooserOption<String?>>>[];
    for (final grade in widget.scale.grades.where((g) => g.countsTowardGpa)) {
      final option = GradusChooserOption<String?>(
        value: grade.letter,
        label: grade.letter,
      );
      final family = grade.letter[0];
      if (rows.isEmpty || rows.last.first.label[0] != family) {
        rows.add([option]);
      } else {
        rows.last.add(option);
      }
    }

    var index = 1;
    while (index < rows.length) {
      if (rows[index].length > 1) {
        index++;
        continue;
      }
      rows[index - 1].addAll(rows.removeAt(index));
    }

    final administrative = [
      for (final grade in widget.scale.grades.where((g) => !g.countsTowardGpa))
        GradusChooserOption<String?>(value: grade.letter, label: grade.letter),
    ];

    return [
      ...rows,
      if (administrative.isNotEmpty) administrative,
      [GradusChooserOption(value: null, label: strings.gradeNotSet)],
    ];
  }

  Widget _fields(BuildContext context, GradusStrings strings) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // the sheet's own AnimatedSize carries every height change here, so
        // the folds collapse at once rather than animating against it
        FocusFold(
          hidden: _focus.hidesChrome,
          animateSize: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradusSheetTitle(
                text: widget.existing == null
                    ? strings.addCourse
                    : strings.editCourse,
              ),
              AppSpacing.verticalDf,
              ..._importCard(strings),
            ],
          ),
        ),
        FocusFold(
          hidden: _focus.hides(_Field.title),
          animateSize: false,
          child: GradusField(
            label: strings.courseTitle,
            child: TextFormField(
              controller: _title,
              focusNode: _focus.nodeFor(_Field.title),
              enabled: !_isImporting,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _focus.moveTo(_Field.code),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? strings.titleRequired : null,
            ),
          ),
        ),
        FocusGap(hidden: _focus.hidesChrome, animateSize: false),
        // a code and its credits share a line and fold as one, the way a mark
        // and its total do
        FocusFold(
          hidden: _focus.hides(_Field.code) && _focus.hides(_Field.credits),
          animateSize: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: GradusField(
                  label: strings.courseCode,
                  child: TextFormField(
                    controller: _code,
                    focusNode: _focus.nodeFor(_Field.code),
                    enabled: !_isImporting,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _focus.moveTo(_Field.credits),
                  ),
                ),
              ),
              AppSpacing.horizontalMd,
              Expanded(
                flex: 2,
                child: GradusField(
                  label: strings.courseCredits,
                  child: TextFormField(
                    controller: _credits,
                    focusNode: _focus.nodeFor(_Field.credits),
                    enabled: !_isImporting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _focus.release(),
                    validator: (value) {
                      final credits = double.tryParse((value ?? '').trim());
                      if (credits == null ||
                          credits <= 0 ||
                          credits > Course.maximumCredits) {
                        return strings.creditsRequired;
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        // chrome: none of it holds the keyboard
        FocusFold(
          hidden: _focus.hidesChrome,
          animateSize: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.verticalDf,
              GradusChooserField(
                isEnabled: !_isImporting,
                label: strings.semesterLabel,
                value: _semesterLabel(strings),
                onTap: () => setState(() => _chooser = _Chooser.semester),
              ),
              AppSpacing.verticalDf,
              GradusChooserField(
                isEnabled: !_isImporting,
                label: strings.courseGrade,
                value: _grade?.letter ?? strings.gradeNotSet,
                onTap: () => setState(() => _chooser = _Chooser.grade),
              ),
            ],
          ),
        ),
        AppSpacing.verticalXl,
        FocusModeActions(
          isTyping: _focus.isTyping,
          doneLabel: strings.done,
          onDone: _focus.release,
          actions: GradusFormActions(
            primaryLabel: strings.save,
            onPrimary: _submit,
            isPrimaryEnabled: !_isImporting,
            secondaryLabel: widget.onDelete == null ? null : strings.delete,
            onSecondary: widget.onDelete == null ? null : _dismiss,
            isSecondaryDestructive: true,
          ),
        ),
      ],
    ),
  );
}

class _CardLine {
  const _CardLine(this.text, {this.isProblem = false});

  final String text;
  final bool isProblem;
}

// one surface for the whole import, so the offer, the wait and the result sit
// in the same place instead of a button with notes scattered under it
class _SyllabusCard extends StatelessWidget {
  const _SyllabusCard({
    required this.state,
    required this.title,
    required this.lines,
    required this.onTap,
  });

  final _ImportState state;
  final String title;
  final List<_CardLine> lines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final accent = isLight ? AppColors.primary : AppColors.primaryAccentDark;
    final problem = isLight ? AppColors.errorText : AppColors.errorTextDark;

    // the state rides the trailing edge, where the chevron offered the read
    final trailing = switch (state) {
      _ImportState.reading => SizedBox.square(
        dimension: AppSpacing.iconSm,
        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
      ),
      _ImportState.done => AppIcon(
        AppIcons.check,
        size: AppSpacing.iconMd,
        color: accent,
      ),
      _ImportState.idle || _ImportState.failed => AppIcon(
        AppIcons.chevronRight,
        size: AppSpacing.iconSm,
        color: accent,
      ),
    };

    // the same card and the same brand-coloured label as the add row, so the
    // one shortcut in the form reads as an action rather than a heading
    return AppCard(
      onTap: onTap,
      padding: AppSpacing.cardPaddingSm,
      backgroundColor: isLight
          ? AppColors.primaryLight
          : AppColors.primaryLightDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.button.copyWith(color: accent),
                ),
                for (final line in lines) ...[
                  AppSpacing.verticalXs,
                  Text(
                    line.text,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: line.isProblem ? problem : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.horizontalMd,
          trailing,
        ],
      ),
    );
  }
}
