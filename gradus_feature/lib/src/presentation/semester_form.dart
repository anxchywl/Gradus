import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/semester.dart';
import '../l10n/gradus_strings.dart';
import 'focus_mode.dart';
import 'gradus_widgets.dart';

enum _Field { name }

class SemesterForm extends StatefulWidget {
  const SemesterForm({
    super.key,
    required this.nextPosition,
    this.existing,
    this.onDelete,
    this.canDelete = false,
  });

  final int nextPosition;
  final Semester? existing;

  // an edited semester is removed from the sheet that opened it
  final VoidCallback? onDelete;

  // a term still holding courses stays, and the sheet says so
  final bool canDelete;

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

  void _dismiss() {
    final delete = widget.onDelete;
    Navigator.of(context).pop();
    // the confirmation belongs to the screen, which outlives this sheet
    if (widget.canDelete) delete?.call();
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
            padding: gradusSheetPadding(context),
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
                          GradusSheetTitle(
                            text: widget.existing == null
                                ? strings.addSemester
                                : strings.editSemester,
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
                          GradusFormActions(
                            primaryLabel: strings.save,
                            onPrimary: _submit,
                            secondaryLabel: widget.onDelete == null
                                ? strings.cancel
                                : strings.delete,
                            onSecondary: _dismiss,
                            isSecondaryDestructive: widget.onDelete != null,
                            isSecondaryEnabled:
                                widget.onDelete == null || widget.canDelete,
                          ),
                          if (widget.onDelete != null && !widget.canDelete) ...[
                            AppSpacing.verticalSm,
                            GradusNote(text: strings.deleteSemesterBlocked),
                          ],
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
