import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/course.dart';
import '../domain/grade.dart';
import '../domain/semester.dart';
import '../l10n/gpa_strings.dart';
import 'focus_mode.dart';
import 'gpa_formatting.dart';
import 'gpa_widgets.dart';

enum _Field { code, title, credits }

class CourseForm extends StatefulWidget {
  const CourseForm({
    super.key,
    required this.scale,
    required this.semesters,
    required this.initialSemesterId,
    this.existing,
  });

  final GradeScale scale;
  final List<Semester> semesters;
  final String initialSemesterId;
  final Course? existing;

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
  late GradingMode _gradingMode =
      widget.existing?.gradingMode ?? GradingMode.graded;
  late bool _includeInGpa = widget.existing?.includeInGpa ?? true;
  late Grade? _grade = widget.existing?.grade;
  final SheetFocusMode _focus = SheetFocusMode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _credits.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    // a second tap while the first is still popping would add the course twice
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    _isSubmitting = true;

    Navigator.of(context).pop(
      Course(
        id:
            widget.existing?.id ??
            'course_${DateTime.now().microsecondsSinceEpoch}',
        semesterId: _semesterId,
        code: _code.text.trim(),
        title: _title.text.trim(),
        credits: double.parse(_credits.text.trim()),
        grade: _grade,
        gradingMode: _gradingMode,
        includeInGpa: _includeInGpa,
        // assignments belong to the course, so an edit here never touches them
        assignments: widget.existing?.assignments ?? const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
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
            padding: AppSpacing.screenPadding,
            child: FocusModeBody(
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
                          Text(
                            widget.existing == null
                                ? strings.addCourse
                                : strings.editCourse,
                            style: AppTextStyles.headlineSmall,
                          ),
                          AppSpacing.verticalDf,
                        ],
                      ),
                    ),
                    FocusFold(
                      hidden: _focus.hides(_Field.code),
                      child: TextFormField(
                        controller: _code,
                        focusNode: _focus.nodeFor(_Field.code),
                        decoration: InputDecoration(
                          labelText: strings.courseCode,
                        ),
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
                        decoration: InputDecoration(
                          labelText: strings.courseTitle,
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _focus.moveTo(_Field.credits),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? strings.titleRequired
                            : null,
                      ),
                    ),
                    FocusGap(hidden: _focus.hidesChrome),
                    FocusFold(
                      hidden: _focus.hides(_Field.credits),
                      child: TextFormField(
                        controller: _credits,
                        focusNode: _focus.nodeFor(_Field.credits),
                        decoration: InputDecoration(
                          labelText: strings.courseCredits,
                        ),
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
                          DropdownButtonFormField<String>(
                            initialValue: _semesterId,
                            dropdownColor: gpaSurface(context),
                            borderRadius: AppSpacing.borderRadiusDf,
                            decoration: InputDecoration(
                              labelText: strings.semesterLabel,
                            ),
                            items: [
                              for (final semester in widget.semesters)
                                DropdownMenuItem<String>(
                                  value: semester.id,
                                  child: Text(
                                    formatSemester(strings, semester),
                                  ),
                                ),
                            ],
                            onChanged: (id) =>
                                setState(() => _semesterId = id ?? _semesterId),
                          ),
                          AppSpacing.verticalMd,
                          DropdownButtonFormField<GradingMode>(
                            initialValue: _gradingMode,
                            dropdownColor: gpaSurface(context),
                            borderRadius: AppSpacing.borderRadiusDf,
                            decoration: InputDecoration(
                              labelText: strings.gradingMode,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: GradingMode.graded,
                                child: Text(strings.gradingModeGraded),
                              ),
                              DropdownMenuItem(
                                value: GradingMode.passFail,
                                child: Text(strings.gradingModePassFail),
                              ),
                            ],
                            onChanged: (mode) => setState(
                              () => _gradingMode = mode ?? _gradingMode,
                            ),
                          ),
                          AppSpacing.verticalMd,
                          DropdownButtonFormField<Grade?>(
                            initialValue: _grade,
                            dropdownColor: gpaSurface(context),
                            borderRadius: AppSpacing.borderRadiusDf,
                            decoration: InputDecoration(
                              labelText: strings.courseGrade,
                            ),
                            items: [
                              DropdownMenuItem<Grade?>(
                                child: Text(strings.gradeNotSet),
                              ),
                              for (final grade in widget.scale.grades)
                                DropdownMenuItem<Grade?>(
                                  value: grade,
                                  child: Text(grade.letter),
                                ),
                            ],
                            onChanged: (grade) =>
                                setState(() => _grade = grade),
                          ),
                          AppSpacing.verticalSm,
                          SwitchListTile.adaptive(
                            contentPadding: AppSpacing.zero,
                            value: _includeInGpa,
                            title: Text(
                              strings.includeInGpa,
                              style: AppTextStyles.bodyMedium,
                            ),
                            onChanged: (value) =>
                                setState(() => _includeInGpa = value),
                          ),
                          if (_gradingMode == GradingMode.passFail)
                            Text(
                              strings.passFailNote,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppSpacing.verticalXl,
                    FocusModeActions(
                      isTyping: _focus.isTyping,
                      doneLabel: strings.done,
                      onDone: _focus.release,
                      actions: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppPrimaryButton(
                            text: strings.save,
                            onPressed: _submit,
                          ),
                          AppSpacing.verticalSm,
                          AppTextButton(
                            text: strings.cancel,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
