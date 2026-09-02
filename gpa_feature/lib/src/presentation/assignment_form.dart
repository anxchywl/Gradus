import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../domain/assignment.dart';
import '../domain/weights.dart';
import '../l10n/gpa_strings.dart';
import 'focus_mode.dart';

enum _Field { name, weight, maximumScore, earnedScore }

class AssignmentForm extends StatefulWidget {
  const AssignmentForm({
    super.key,
    required this.courseId,
    required this.availableWeight,
    this.existing,
  });

  final String courseId;

  // the edited assignment gives its own weight back, or an edit is blocked
  final double availableWeight;
  final Assignment? existing;

  @override
  State<AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<AssignmentForm> {
  final _formKey = GlobalKey<FormState>();
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
  final SheetFocusMode _focus = SheetFocusMode();
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

  String? _validateWeight(String? value, GpaStrings strings) {
    final weight = double.tryParse((value ?? '').trim());
    if (weight == null || weight <= 0 || weight > Assignment.maximumWeight) {
      return strings.assignmentWeightRequired;
    }
    if (toHundredths(weight) > toHundredths(widget.availableWeight)) {
      return strings.assignmentWeightOverBudget(widget.availableWeight);
    }
    return null;
  }

  String? _validateMaximumScore(String? value, GpaStrings strings) {
    final maximum = double.tryParse((value ?? '').trim());
    if (maximum == null || maximum <= 0) return strings.maximumScoreRequired;
    return null;
  }

  String? _validateEarnedScore(String? value, GpaStrings strings) {
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
                                ? strings.addAssignment
                                : strings.editAssignment,
                            style: AppTextStyles.headlineSmall,
                          ),
                          AppSpacing.verticalDf,
                        ],
                      ),
                    ),
                    FocusFold(
                      hidden: _focus.hides(_Field.name),
                      child: TextFormField(
                        controller: _name,
                        focusNode: _focus.nodeFor(_Field.name),
                        autofocus: _focus.takeAutofocus(),
                        decoration: InputDecoration(
                          labelText: strings.assignmentName,
                          helperText: strings.assignmentNameHelp,
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _focus.moveTo(_Field.weight),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? strings.assignmentNameRequired
                            : null,
                      ),
                    ),
                    FocusGap(hidden: _focus.hidesChrome),
                    FocusFold(
                      hidden: _focus.hides(_Field.weight),
                      child: TextFormField(
                        controller: _weight,
                        focusNode: _focus.nodeFor(_Field.weight),
                        decoration: InputDecoration(
                          labelText: strings.assignmentWeight,
                          helperText: strings.assignmentWeightHelp,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focus.moveTo(_Field.maximumScore),
                        validator: (value) => _validateWeight(value, strings),
                      ),
                    ),
                    FocusGap(hidden: _focus.hidesChrome),
                    // a mark and its total fold as one thing
                    FocusFold(
                      hidden:
                          _focus.hides(_Field.maximumScore) &&
                          _focus.hides(_Field.earnedScore),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _maximumScore,
                              focusNode: _focus.nodeFor(_Field.maximumScore),
                              decoration: InputDecoration(
                                labelText: strings.maximumScore,
                              ),
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
                          AppSpacing.horizontalMd,
                          Expanded(
                            child: TextFormField(
                              controller: _earnedScore,
                              focusNode: _focus.nodeFor(_Field.earnedScore),
                              decoration: InputDecoration(
                                labelText: strings.earnedScore,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.done,
                              // the rest of the form is folded away
                              onFieldSubmitted: (_) => _focus.release(),
                              validator: (value) =>
                                  _validateEarnedScore(value, strings),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FocusFold(
                      hidden: _focus.hidesChrome,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSpacing.verticalSm,
                          Text(
                            strings.earnedScoreHelp,
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
