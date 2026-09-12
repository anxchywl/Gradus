import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/assignment.dart';
import '../domain/weights.dart';
import '../l10n/gradus_strings.dart';
import 'focus_mode.dart';
import 'gradus_widgets.dart';

enum _Field { name, weight, maximumScore, earnedScore }

class AssignmentForm extends StatefulWidget {
  const AssignmentForm({
    super.key,
    required this.courseId,
    required this.availableWeight,
    this.existing,
    this.onDelete,
  });

  final String courseId;

  // the edited assignment gives its own weight back, or an edit is blocked
  final double availableWeight;
  final Assignment? existing;

  // an edited assignment is removed from the sheet that opened it
  final VoidCallback? onDelete;

  @override
  State<AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<AssignmentForm> {
  final _formKey = GlobalKey<FormState>();
  final SheetFocusMode _focus = SheetFocusMode();
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: _initial(widget.existing?.weight),
  );
  late final TextEditingController _maximumScore = TextEditingController(
    text: _initial(widget.existing?.maximumScore),
  );
  late final TextEditingController _earnedScore = TextEditingController(
    text: _initial(widget.existing?.earnedScore),
  );
  bool _isSubmitting = false;

  static String _initial(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _maximumScore.dispose();
    _earnedScore.dispose();
    _focus.dispose();
    super.dispose();
  }

  double? _parsed(TextEditingController controller) =>
      double.tryParse(controller.text.trim());

  String? _validateWeight(String? value, GradusStrings strings) {
    final weight = double.tryParse((value ?? '').trim());
    if (weight == null || weight <= 0 || weight > Assignment.maximumWeight) {
      return strings.assignmentWeightRequired;
    }
    if (toHundredths(weight) > toHundredths(widget.availableWeight)) {
      return strings.assignmentWeightOverBudget(widget.availableWeight);
    }
    return null;
  }

  String? _validateMaximumScore(String? value, GradusStrings strings) {
    final maximum = double.tryParse((value ?? '').trim());
    if (maximum == null || maximum <= 0) return strings.maximumScoreRequired;
    return null;
  }

  String? _validateEarnedScore(String? value, GradusStrings strings) {
    final text = (value ?? '').trim();
    // empty is the normal state of work that has not been marked, not an error
    if (text.isEmpty) return null;
    final earned = double.tryParse(text);
    final maximum = _parsed(_maximumScore);
    if (earned == null || earned < 0) return strings.earnedScoreRequired;
    if (maximum != null && earned > maximum) {
      return strings.earnedScoreRequired;
    }
    return null;
  }

  void _submit() {
    // a second tap while the first is still popping would add the work twice
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    _isSubmitting = true;

    Navigator.of(context).pop(
      Assignment(
        id:
            widget.existing?.id ??
            'assignment_${DateTime.now().microsecondsSinceEpoch}',
        courseId: widget.courseId,
        name: _name.text.trim(),
        weight: _parsed(_weight)!,
        maximumScore: _parsed(_maximumScore)!,
        earnedScore: _parsed(_earnedScore),
      ),
    );
  }

  void _dismiss() {
    final delete = widget.onDelete;
    Navigator.of(context).pop();
    // the confirmation belongs to the screen, which outlives this sheet
    delete?.call();
  }

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
                              ? strings.addAssignment
                              : strings.editAssignment,
                        ),
                        AppSpacing.verticalDf,
                      ],
                    ),
                  ),
                  FocusFold(
                    hidden: _focus.hides(_Field.name),
                    child: GradusField(
                      label: strings.assignmentName,
                      child: TextFormField(
                        controller: _name,
                        focusNode: _focus.nodeFor(_Field.name),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _focus.moveTo(_Field.weight),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? strings.assignmentNameRequired
                            : null,
                      ),
                    ),
                  ),
                  FocusGap(hidden: _focus.hidesChrome, height: AppSpacing.md),
                  FocusFold(
                    hidden: _focus.hides(_Field.weight),
                    child: GradusField(
                      label: strings.assignmentWeight,
                      child: TextFormField(
                        controller: _weight,
                        focusNode: _focus.nodeFor(_Field.weight),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focus.moveTo(_Field.maximumScore),
                        validator: (value) => _validateWeight(value, strings),
                      ),
                    ),
                  ),
                  FocusGap(hidden: _focus.hidesChrome, height: AppSpacing.md),
                  // a mark and its total fold as one: either alone means nothing
                  FocusFold(
                    hidden:
                        _focus.hides(_Field.maximumScore) &&
                        _focus.hides(_Field.earnedScore),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GradusField(
                            label: strings.maximumScore,
                            child: TextFormField(
                              controller: _maximumScore,
                              focusNode: _focus.nodeFor(_Field.maximumScore),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  _focus.moveTo(_Field.earnedScore),
                              validator: (value) =>
                                  _validateMaximumScore(value, strings),
                            ),
                          ),
                        ),
                        AppSpacing.horizontalMd,
                        Expanded(
                          child: GradusField(
                            label: strings.earnedScore,
                            child: TextFormField(
                              controller: _earnedScore,
                              focusNode: _focus.nodeFor(_Field.earnedScore),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _focus.release(),
                              validator: (value) =>
                                  _validateEarnedScore(value, strings),
                            ),
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
                    actions: GradusFormActions(
                      primaryLabel: strings.save,
                      onPrimary: _submit,
                      secondaryLabel: widget.onDelete == null
                          ? null
                          : strings.delete,
                      onSecondary: widget.onDelete == null ? null : _dismiss,
                      isSecondaryDestructive: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
