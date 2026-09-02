import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../l10n/gpa_strings.dart';

// dismissed means false, tapping outside is not agreement
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    // the dialog mounts on the host overlay, so the delegate is installed again
    builder: (_) => GpaStringsScope(child: _ConfirmDialog(message: message)),
  );
  return confirmed ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
    return AlertDialog(
      content: Text(message, style: AppTextStyles.bodyMedium),
      actions: [
        AppTextButton(
          text: strings.cancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        Semantics(
          button: true,
          label: strings.delete,
          child: AppTextButton(
            text: strings.delete,
            textColor: Theme.of(context).brightness == Brightness.light
                ? AppColors.errorText
                : AppColors.errorTextDark,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
  }
}
