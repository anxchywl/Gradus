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

enum _Field { code, title, credits }

// which chooser has taken the sheet over, if any
enum _Chooser { semester, grade }

// what the syllabus did not state, named on screen rather than guessed
enum _MissingField { code, title, credits, assignments }

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
  final SheetFocusMode _focus = SheetFocusMode();
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

  void _dropImported(int index) => setState(() {
    _imported = [
      for (var position = 0; position < _imported.length; position++)
        if (position != index) _imported[position],
    ];
  });

  void _submit() {
    // a second tap while the first is still popping would add the course twice
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    // the course constructor would reject this, so it never gets the chance
    if (_isOverBudget) return;
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

  // identifiers are generated here; nothing from the document names anything
  List<Assignment> _importedAssignments(String courseId) => [
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

  String _importLabel(GradusStrings strings) {
    if (!_isImporting) return strings.importFromSyllabus;
    return _importIsSlow ? strings.importStillRunning : strings.importRunning;
  }

  // the control only exists where a syllabus can actually be read
  List<Widget> _importControl(GradusStrings strings) {
    if (widget.onImportSyllabus == null || widget.existing != null) {
      return const [];
    }
    final problem = _importProblem;
    return [
      AppSecondaryButton(
        text: _importLabel(strings),
        isLoading: _isImporting,
        onPressed: _isImporting ? null : _import,
      ),
      AppSpacing.verticalSm,
      Text(strings.importNote, style: AppTextStyles.bodySmall),
      if (problem != null) ...[
        AppSpacing.verticalSm,
        Text(
          _problemMessage(strings, problem),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorText),
        ),
      ],
      if (_importMissing.isNotEmpty) ...[
        AppSpacing.verticalSm,
        Text(
          strings.importMissingFields(
            _importMissing
                .map((field) => _fieldName(strings, field))
                .join(', '),
          ),
          style: AppTextStyles.bodySmall,
        ),
      ],
      AppSpacing.verticalDf,
    ];
  }

  List<Widget> _importedList(GradusStrings strings) {
    if (!_hasImported || _imported.isEmpty) return const [];
    return [
      AppSpacing.verticalMd,
      Text(strings.importedAssignments, style: AppTextStyles.labelMedium),
      AppSpacing.verticalSm,
      for (var index = 0; index < _imported.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _imported[index].name,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              Text(
                strings.percentValue(_imported[index].weight),
                style: AppTextStyles.bodyMedium,
              ),
              AppSpacing.horizontalSm,
              Semantics(
                container: true,
                button: true,
                label: strings.importRemoveEntry(_imported[index].name),
                child: AppIconButton(
                  icon: const AppIcon(AppIcons.close),
                  tooltip: strings.importRemoveEntry(_imported[index].name),
                  iconColor: gradusPrimaryText(context),
                  onPressed: () => _dropImported(index),
                ),
              ),
            ],
          ),
        ),
      Text(
        strings.importedWeightTotal(_importedWeight),
        style: AppTextStyles.bodySmall,
      ),
      if (_isOverBudget)
        Text(
          strings.importedWeightOverBudget,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.errorText),
        )
      else
        Text(strings.importedScoreNote, style: AppTextStyles.bodySmall),
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
    SyllabusImportProblem.notAPdf => strings.importNotAPdf,
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
          // no AnimatedPadding, the platform already animates this inset
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: gradusSheetPadding(context),
            // the sheet becomes the chooser and comes back, one surface
            child: AnimatedSize(
              duration: chooserDuration,
              curve: focusModeCurve,
              // the sheet is pinned to the bottom of the screen, so the
              // controls there stay put and the top edge does the moving
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: chooserDuration,
                switchInCurve: focusModeCurve,
                switchOutCurve: Curves.easeInCubic,
                // the outgoing panel is positioned, so it no longer measures
                // the stack: the height follows the arriving panel from the
                // first frame instead of waiting for the fade to finish
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (final child in previous)
                      Positioned(bottom: 0, left: 0, right: 0, child: child),
                    ?current,
                  ],
                ),
                // a plain cross-fade over a changing height reads as a jump,
                // so the incoming panel settles into place as it arrives
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
        cancelLabel: strings.cancel,
        onCancel: () => setState(() => _chooser = null),
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
        cancelLabel: strings.cancel,
        onCancel: () => setState(() => _chooser = null),
        onSelected: (letter) => setState(() {
          _grade = letter == null ? null : widget.scale.byLetter(letter);
          _chooser = null;
        }),
        rows: _gradeRows(strings),
      ),
    },
  );

  // the scale reads as the families a student already knows, and a family too
  // small for a row of its own joins the one above rather than taking a line
  List<List<GradusChooserOption<String?>>> _gradeRows(GradusStrings strings) {
    final rows = <List<GradusChooserOption<String?>>>[];
    for (final grade in widget.scale.grades) {
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

    return [
      ...rows,
      [GradusChooserOption(value: null, label: strings.gradeNotSet)],
    ];
  }

  Widget _fields(BuildContext context, GradusStrings strings) => FocusModeBody(
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FocusFold(
            hidden: _focus.hidesChrome,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GradusSheetTitle(
                  text: widget.existing == null
                      ? strings.addCourse
                      : strings.editCourse,
                ),
                AppSpacing.verticalDf,
                ..._importControl(strings),
              ],
            ),
          ),
          FocusFold(
            hidden: _focus.hides(_Field.code),
            child: TextFormField(
              controller: _code,
              focusNode: _focus.nodeFor(_Field.code),
              enabled: !_isImporting,
              decoration: InputDecoration(labelText: strings.courseCode),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _focus.moveTo(_Field.title),
            ),
          ),
          FocusGap(hidden: _focus.hidesChrome),
          FocusFold(
            hidden: _focus.hides(_Field.title),
            child: TextFormField(
              controller: _title,
              focusNode: _focus.nodeFor(_Field.title),
              enabled: !_isImporting,
              decoration: InputDecoration(labelText: strings.courseTitle),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _focus.moveTo(_Field.credits),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? strings.titleRequired : null,
            ),
          ),
          FocusGap(hidden: _focus.hidesChrome),
          FocusFold(
            hidden: _focus.hides(_Field.credits),
            child: TextFormField(
              controller: _credits,
              focusNode: _focus.nodeFor(_Field.credits),
              enabled: !_isImporting,
              decoration: InputDecoration(labelText: strings.courseCredits),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              // the fields are folded out, so done means done typing
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
          // chrome: none of it holds the keyboard
          FocusFold(
            hidden: _focus.hidesChrome,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.verticalMd,
                GradusChooserField(
                  isEnabled: !_isImporting,
                  label: strings.semesterLabel,
                  value: _semesterLabel(strings),
                  onTap: () => setState(() => _chooser = _Chooser.semester),
                ),
                AppSpacing.verticalMd,
                GradusChooserField(
                  isEnabled: !_isImporting,
                  label: strings.courseGrade,
                  value: _grade?.letter ?? strings.gradeNotSet,
                  onTap: () => setState(() => _chooser = _Chooser.grade),
                ),
              ],
            ),
          ),
          // chrome as well: the proposal is reviewed, not typed into
          FocusFold(
            hidden: _focus.hidesChrome,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _importedList(strings),
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
              secondaryLabel: widget.onDelete == null
                  ? strings.cancel
                  : strings.delete,
              onSecondary: _dismiss,
              isSecondaryDestructive: widget.onDelete != null,
            ),
          ),
        ],
      ),
    ),
  );
}
