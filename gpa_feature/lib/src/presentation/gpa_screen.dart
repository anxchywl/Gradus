import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../config/gpa_scope.dart';
import '../l10n/gpa_strings.dart';

/// Entry screen. Renders text that is already translated and already formatted;
/// deciding what a number means belongs to the controller, not here.
class GpaScreen extends StatefulWidget {
  const GpaScreen({super.key});

  @override
  State<GpaScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GpaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GpaScope.of(context).gpa.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
    final controller = GpaScope.of(context).gpa;

    return Scaffold(
      appBar: AppAppBar(title: strings.featureTitle),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: AppLoader());
          }
          if (controller.failure != null) {
            return _Message(text: strings.loadFailed);
          }
          if (controller.entries.isEmpty) {
            return _Message(text: strings.noCourses);
          }
          return Padding(
            padding: AppSpacing.screenPadding,
            child: Text(
              controller.result.isDefined
                  ? strings.gpaValue(controller.result.value!)
                  : strings.gpaUndefined,
              style: AppTextStyles.headlineMedium,
            ),
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.screenPadding,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium,
      ),
    ),
  );
}
