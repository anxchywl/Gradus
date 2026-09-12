import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../l10n/gradus_strings.dart';
import 'gradus_widgets.dart';

// dismissed means false, tapping outside is not agreement
Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String message,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    // the sheet mounts on the host overlay, so the delegate is installed again
    builder: (_) => GradusStringsScope(child: _ConfirmSheet(message: message)),
  );
  return confirmed ?? false;
}

// the same shape as the forms it undoes, rather than a platform dialog
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);

    return SingleChildScrollView(
      padding: gradusSheetPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradusSheetTitle(text: message),
          AppSpacing.verticalXl,
          // the question asked is the one the big button answers, in the same
          // shape Save wears elsewhere; the way out sits small beside it
          GradusFormActions(
            primaryLabel: strings.delete,
            onPrimary: () => Navigator.of(context).pop(true),
            isPrimaryDestructive: true,
            secondaryLabel: strings.cancel,
            onSecondary: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
