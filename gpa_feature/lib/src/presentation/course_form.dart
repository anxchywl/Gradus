import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/course.dart';
import '../domain/grade.dart';
import '../l10n/gpa_strings.dart';

/// Collects one course. Returns the course on save, or null when dismissed.
class CourseForm extends StatefulWidget {
  const CourseForm({super.key, required this.scale, this.existing});

  final GradeScale scale;
  final Course? existing;

  @override
  State<CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<CourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _credits;
  Grade? _grade;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _credits = TextEditingController(
      text: widget.existing?.credits.toString() ?? '',
    );
    _grade = widget.existing?.grade;
  }

  @override
  void dispose() {
    _title.dispose();
    _credits.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Course(
        id:
            widget.existing?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        credits: double.parse(_credits.text.trim()),
        grade: _grade,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? strings.addCourse
                    : strings.editCourse,
                style: AppTextStyles.headlineSmall,
              ),
              AppSpacing.verticalDf,
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: strings.courseTitle),
                textInputAction: TextInputAction.next,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? strings.titleRequired : null,
              ),
              AppSpacing.verticalMd,
              TextFormField(
                controller: _credits,
                decoration: InputDecoration(labelText: strings.courseCredits),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
              AppSpacing.verticalMd,
              DropdownButtonFormField<Grade?>(
                initialValue: _grade,
                decoration: InputDecoration(labelText: strings.courseGrade),
                items: [
                  DropdownMenuItem<Grade?>(child: Text(strings.gradeNotSet)),
                  for (final grade in widget.scale.grades)
                    DropdownMenuItem<Grade?>(
                      value: grade,
                      child: Text(grade.letter),
                    ),
                ],
                onChanged: (grade) => setState(() => _grade = grade),
              ),
              AppSpacing.verticalXl,
              AppPrimaryButton(text: strings.save, onPressed: _submit),
              AppSpacing.verticalSm,
              AppTextButton(
                text: strings.cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
