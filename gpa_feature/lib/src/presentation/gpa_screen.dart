import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../config/gpa_scope.dart';
import '../domain/course.dart';
import '../l10n/gpa_strings.dart';
import 'course_form.dart';

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

  Future<void> _openForm({Course? existing}) async {
    final controller = GpaScope.of(context).gpa;
    final scale = controller.scale;
    if (scale == null) return;

    final course = await showModalBottomSheet<Course>(
      context: context,
      isScrollControlled: true,
      // the sheet mounts on the host's overlay, outside our subtree, so the
      // feature's delegate has to be installed again or its strings resolve
      // to nothing
      builder: (_) => GpaStringsScope(
        child: CourseForm(scale: scale, existing: existing),
      ),
    );
    if (course == null) return;
    await (existing == null
        ? controller.add(course)
        : controller.update(course));
  }

  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
    final controller = GpaScope.of(context).gpa;

    return Scaffold(
      appBar: AppAppBar(title: strings.featureTitle),
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        tooltip: strings.addCourse,
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: AppLoader());
          }
          if (controller.failure != null && controller.entries.isEmpty) {
            return _Message(text: strings.loadFailed);
          }
          return Column(
            children: [
              _Summary(),
              Expanded(
                child: controller.entries.isEmpty
                    ? _Message(text: strings.noCourses)
                    : ListView.builder(
                        padding: AppSpacing.screenHorizontal,
                        itemCount: controller.entries.length,
                        itemBuilder: (context, index) {
                          final course = controller.entries[index];
                          return _CourseRow(
                            course: course,
                            onEdit: () => _openForm(existing: course),
                            onDelete: () => controller.remove(course.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
    final result = GpaScope.of(context).gpa.result;

    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.isDefined
                ? strings.gpaValue(result.value!)
                : strings.gpaUndefined,
            style: AppTextStyles.displaySmall,
          ),
          AppSpacing.verticalXs,
          // both figures, so a pass/fail course does not look like lost credit
          Text(
            strings.creditsSummary(
              result.qualityCredits,
              result.attemptedCredits,
            ),
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = GpaStrings.of(context);
    return AppCard(
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, style: AppTextStyles.titleMedium),
                AppSpacing.verticalXs,
                Text(
                  course.grade == null
                      ? strings.gradeNotSet
                      : '${course.grade!.letter}  ·  '
                            '${strings.courseCredits} ${course.credits}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          // icon-only control, so the label is the only thing a screen
          // reader has to go on
          Semantics(
            // its own node, so the card's tappable row does not swallow the
            // label into one long announcement
            container: true,
            label: strings.deleteCourse(course.title),
            button: true,
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: strings.deleteCourse(course.title),
            ),
          ),
        ],
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
