import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../application/gradus_controller.dart';
import '../config/gradus_scope.dart';
import '../domain/assignment.dart';
import '../domain/course.dart';
import '../domain/course_grade.dart';
import '../domain/weights.dart';
import '../l10n/gradus_strings.dart';
import 'assignment_form.dart';
import 'confirm_dialog.dart';
import 'gradus_formatting.dart';
import 'gradus_responsive.dart';
import 'gradus_widgets.dart';

enum _AssignmentAction { edit, delete }

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  Future<void> _openForm(
    BuildContext context,
    GradusController controller,
    Course course, {
    Assignment? existing,
  }) async {
    final configured = fromHundredths(
      sumHundredths(course.assignments.map((a) => a.weight)),
    );
    final available = fromHundredths(
      completeWeight -
          toHundredths(configured) +
          toHundredths(existing?.weight ?? 0),
    );

    final assignment = await showModalBottomSheet<Assignment>(
      context: context,
      isScrollControlled: true,
      // mounted on the host overlay, so the delegate is installed again
      builder: (_) => GradusStringsScope(
        child: AssignmentForm(
          courseId: course.id,
          availableWeight: available,
          existing: existing,
        ),
      ),
    );
    if (assignment == null) return;
    await (existing == null
        ? controller.addAssignment(assignment)
        : controller.updateAssignment(assignment));
  }

  Future<void> _delete(
    BuildContext context,
    GradusController controller,
    Assignment assignment,
  ) async {
    final strings = GradusStrings.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      message: strings.deleteAssignmentConfirm(assignment.name),
    );
    if (!confirmed) return;
    await controller.removeAssignment(assignment.courseId, assignment.id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final controller = GradusScope.of(context).controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final course = controller.courseById(courseId);
        final scale = controller.scale;
        if (course == null || scale == null) {
          return Scaffold(
            appBar: AppAppBar(
              title: strings.featureTitle,
              showBackButton: true,
            ),
            body: GradusEmptyState(
              icon: AppIcons.warning,
              tone: GradusTone.warning,
              title: strings.courseUnavailable,
              message: strings.loadFailedBody,
            ),
          );
        }

        final resolved = calculateCourseGrade(course, scale);
        return Scaffold(
          appBar: AppAppBar(
            title: course.title,
            showBackButton: true,
            centerTitle: false,
          ),
          // the empty state already carries this action
          floatingActionButton: course.assignments.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openForm(context, controller, course),
                  // the brand colour reads in both themes
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  icon: const AppIcon(AppIcons.add, color: AppColors.white),
                  label: Text(strings.addAssignment),
                ),
          body: ListView(
            padding: AppSpacing.screenHorizontal,
            children: [
              CenteredContent(
                maxWidth: gradusReadingWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSpacing.verticalDf,
                    _CourseSummary(course: course, resolved: resolved),
                    AppSpacing.verticalXl,
                    GradusSectionHeader(title: strings.assignmentsTitle),
                    AppSpacing.verticalMd,
                    if (course.assignments.isEmpty)
                      GradusEmptyState(
                        icon: AppIcons.book,
                        title: strings.noAssignments,
                        message: strings.noAssignmentsBody,
                        actionLabel: strings.addAssignment,
                        onAction: () => _openForm(context, controller, course),
                      )
                    else
                      for (final assignment in course.assignments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AssignmentRow(
                            assignment: assignment,
                            onEdit: () => _openForm(
                              context,
                              controller,
                              course,
                              existing: assignment,
                            ),
                            onDelete: () =>
                                _delete(context, controller, assignment),
                          ),
                        ),
                  ],
                ),
              ),
              // clears the floating button at the end of the list
              const SizedBox(height: AppSpacing.xxxxl + AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

class _CourseSummary extends StatelessWidget {
  const _CourseSummary({required this.course, required this.resolved});

  final Course course;
  final CourseGrade resolved;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);

    return AppCard(
      padding: AppSpacing.cardPaddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course.code.isNotEmpty) ...[
            Text(
              course.code,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.verticalSm,
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.currentGrade,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    AppSpacing.verticalXs,
                    Text(
                      formatPercentage(strings, resolved.currentPercentage),
                      style: AppTextStyles.displaySmall.copyWith(
                        color: gradusPrimaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.horizontalMd,
              GradusGradeBadge(
                letter: formatLetter(strings, resolved),
                countsTowardGpa: resolved.weighsOnGpa,
                isLarge: true,
              ),
            ],
          ),
          AppSpacing.verticalXs,
          Text(
            formatGradeSource(strings, resolved),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.verticalLg,
          AppProgressBar(
            progress: resolved.gradedWeight / 100,
            label: strings.gradedWeightLabel,
            showPercentage: true,
          ),
          AppSpacing.verticalLg,
          GradusStatGrid(
            tiles: [
              GradusStatTile(
                label: strings.earnedTowardFinal,
                value: strings.percentValue(resolved.earnedPercentage),
              ),
              GradusStatTile(
                label: strings.remainingWeightLabel,
                value: strings.weightPercent(resolved.remainingWeight),
              ),
              GradusStatTile(
                label: strings.unallocatedWeightLabel,
                value: strings.weightPercent(resolved.unallocatedWeight),
              ),
              GradusStatTile(
                label: strings.maximumPossible,
                value: formatPercentage(
                  strings,
                  resolved.maximumPossiblePercentage,
                ),
              ),
              GradusStatTile(
                label: strings.courseCredits,
                value: strings.creditsValue(course.credits),
              ),
            ],
          ),
          if (_chips(strings).isNotEmpty) ...[
            AppSpacing.verticalLg,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _chips(strings),
            ),
          ],
          if (resolved.assignmentCount > 0) ...[
            AppSpacing.verticalMd,
            // the assumption travels with the number it qualifies
            Text(
              strings.maximumPossibleNote,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _chips(GradusStrings strings) => [
    if (resolved.assignmentCount == 0)
      GradusStatusChip(label: strings.noAssignments, icon: AppIcons.info)
    else if (!resolved.hasGradedWork)
      GradusStatusChip(label: strings.noGradedAssignments, icon: AppIcons.info)
    else if (resolved.isSetupComplete)
      GradusStatusChip(label: strings.setupComplete, icon: AppIcons.checkCircle)
    else
      GradusStatusChip(
        label: strings.setupIncomplete(resolved.unallocatedWeight),
        icon: AppIcons.warning,
        tone: GradusTone.warning,
      ),
    if (resolved.isAttempted && !resolved.weighsOnGpa)
      GradusStatusChip(
        label: strings.passFailNote,
        icon: AppIcons.checkCircle,
        tone: GradusTone.info,
      ),
    if (!course.includeInGpa)
      GradusStatusChip(label: strings.excludedFromGpa, icon: AppIcons.info),
  ];
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.onEdit,
    required this.onDelete,
  });

  final Assignment assignment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final isGraded = assignment.isGraded;

    return AppCard(
      onTap: onEdit,
      padding: AppSpacing.cardPaddingSm,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: gradusPrimaryText(context),
                  ),
                ),
                AppSpacing.verticalXs,
                Text(
                  strings.weightPercent(assignment.weight),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.horizontalSm,
          Text(
            formatPercentage(strings, assignment.percentage),
            style: AppTextStyles.titleMedium.copyWith(
              // unmarked work reads as pending rather than as a poor result
              color: isGraded
                  ? gradusPrimaryText(context)
                  : AppColors.textSecondary,
            ),
          ),
          _AssignmentMenu(
            assignment: assignment,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AssignmentMenu extends StatelessWidget {
  const _AssignmentMenu({
    required this.assignment,
    required this.onEdit,
    required this.onDelete,
  });

  final Assignment assignment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    return Semantics(
      container: true,
      button: true,
      label: strings.assignmentActions(assignment.name),
      child: AppMenu<_AssignmentAction>(
        tooltip: strings.assignmentActions(assignment.name),
        iconColor: AppColors.textSecondary,
        onSelected: (action) => switch (action) {
          _AssignmentAction.edit => onEdit(),
          _AssignmentAction.delete => onDelete(),
        },
        items: [
          AppMenuItem(
            value: _AssignmentAction.edit,
            label: strings.editAssignment,
            icon: AppIcons.edit,
          ),
          AppMenuItem(
            value: _AssignmentAction.delete,
            label: strings.deleteAssignment(assignment.name),
            icon: AppIcons.delete,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}
