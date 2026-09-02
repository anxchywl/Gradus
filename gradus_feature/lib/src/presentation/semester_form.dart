import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/semester.dart';
import '../l10n/gradus_strings.dart';
import 'focus_mode.dart';

enum _Field { name }

class SemesterForm extends StatefulWidget {
  const SemesterForm({super.key, required this.nextPosition, this.existing});

  final int nextPosition;
  final Semester? existing;

  @override
  State<SemesterForm> createState() => _SemesterFormState();
}

class _SemesterFormState extends State<SemesterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  final SheetFocusMode _focus = SheetFocusMode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    // a second tap while the first is still popping would return two semesters
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    _isSubmitting = true;

    final existing = widget.existing;
    Navigator.of(context).pop(
      existing == null
          ? Semester(
              id: 'semester_${DateTime.now().microsecondsSinceEpoch}',
              name: _name.text.trim(),
              position: widget.nextPosition,
            )
          : existing.copyWith(name: _name.text.trim()),
    );
  }

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
                                ? strings.addSemester
                                : strings.editSemester,
                            style: AppTextStyles.headlineSmall,
                          ),
                          AppSpacing.verticalDf,
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: _name,
                      focusNode: _focus.nodeFor(_Field.name),
                      autofocus: _focus.takeAutofocus(),
                      decoration: InputDecoration(
                        labelText: strings.semesterName,
                        helperText: strings.semesterNameHelp,
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? strings.semesterNameRequired
                          : null,
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
