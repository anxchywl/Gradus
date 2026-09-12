import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../application/gradus_controller.dart';
import '../config/gradus_scope.dart';
import '../domain/assignment.dart';
import '../domain/course.dart';
import '../domain/course_grade.dart';
import '../domain/grade.dart';
import '../domain/weights.dart';
import '../l10n/gradus_strings.dart';
import 'assignment_form.dart';
import 'confirm_dialog.dart';
import 'course_form.dart';
import 'gradus_formatting.dart';
import 'gradus_responsive.dart';
import 'gradus_widgets.dart';

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
      useSafeArea: true,
      isScrollControlled: true,
      // mounted on the host overlay, so the delegate is installed again
      builder: (_) => GradusStringsScope(
        child: AssignmentForm(
          courseId: course.id,
          availableWeight: available,
          existing: existing,
          onDelete: existing == null
              ? null
              : () => _delete(context, controller, existing),
        ),
      ),
    );
    if (assignment == null) return;
    await (existing == null
        ? controller.addAssignment(assignment)
        : controller.updateAssignment(assignment));
  }

  Future<void> _editCourse(
    BuildContext context,
    GradusController controller,
    Course course,
  ) async {
    final scale = controller.scale;
    final semesters = controller.semesters;
    if (scale == null || semesters.isEmpty) return;

    final next = await showModalBottomSheet<Course>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => GradusStringsScope(
        child: CourseForm(
          scale: scale,
          semesters: semesters,
          initialSemesterId: course.semesterId,
          existing: course,
          // removing a course is done from the sheet that edits it
          onDelete: () => _deleteCourse(context, controller, course),
        ),
      ),
    );
    if (next == null) return;
    await controller.updateCourse(next);
  }

  Future<void> _deleteCourse(
    BuildContext context,
    GradusController controller,
    Course course,
  ) async {
    final strings = GradusStrings.of(context);
    // the route goes away with the course, so the navigator is taken first
    final navigator = Navigator.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      message: strings.deleteCourseConfirm,
    );
    if (!confirmed) return;
    await controller.removeCourse(course.id);
    navigator.pop();
  }

  Future<void> _delete(
    BuildContext context,
    GradusController controller,
    Assignment assignment,
  ) async {
    final strings = GradusStrings.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      message: strings.deleteAssignmentConfirm,
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
            // the sheet over it pads itself by the keyboard; the screen behind
            // must not rise as well
            resizeToAvoidBottomInset: false,
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
          // the sheet over it pads itself by the keyboard; the screen behind
          // must not rise as well
          resizeToAvoidBottomInset: false,
          body: CustomScrollView(
            slivers: [
              // the header gives the list its room back on the way down
              AppSliverAppBar(
                // the name reads in the header; two lines of room so a long
                // one is not cut down to an ellipsis
                toolbarHeight: AppSpacing.appBarHeight + AppSpacing.xl,
                titleWidget: _CourseHeading(course: course),
                leading: _CourseAction(
                  icon: AppIcons.back,
                  label: strings.back,
                  onPressed: Navigator.of(context).pop,
                ),
                actions: [
                  _CourseAction(
                    icon: AppIcons.edit,
                    label: strings.editCourse,
                    onPressed: () => _editCourse(context, controller, course),
                  ),
                ],
              ),
              ..._content(context, controller, course, resolved, strings),
            ],
          ),
        );
      },
    );
  }

  String _semesterName(
    GradusController controller,
    Course course,
    GradusStrings strings,
  ) {
    for (final semester in controller.semesters) {
      if (semester.id == course.semesterId) {
        return formatSemester(strings, semester);
      }
    }
    return strings.unnamedSemester;
  }

  List<Widget> _content(
    BuildContext context,
    GradusController controller,
    Course course,
    CourseGrade resolved,
    GradusStrings strings,
  ) {
    final scale = controller.scale!;
    return [
      SliverPadding(
        padding: AppSpacing.screenHorizontal,
        sliver: SliverToBoxAdapter(
          child: CenteredContent(
            maxWidth: gradusReadingWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.verticalDf,
                _CourseSummary(
                  course: course,
                  resolved: resolved,
                  semesterName: _semesterName(controller, course, strings),
                ),
                AppSpacing.verticalXl,
                if (course.assignments.isEmpty)
                  // a heading over nothing, and prose under it, say less
                  // than the button that follows
                  Text(
                    strings.noAssignments,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else ...[
                  GradusSectionHeader(title: strings.assignmentsTitle),
                  AppSpacing.verticalMd,
                  AppProgressBar(
                    progress: resolved.gradedWeight / 100,
                    // the shortfall qualifies the bar, so it rides its label
                    label: resolved.isSetupComplete
                        ? strings.gradedWeightLabel
                        : strings.gradedWeightUnallocated(
                            resolved.unallocatedWeight,
                          ),
                    showPercentage: true,
                  ),
                  AppSpacing.verticalMd,
                  for (final assignment in course.assignments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _AssignmentRow(
                        assignment: assignment,
                        reservesBadge: course.assignments.any(
                          (entry) => entry.isGraded,
                        ),
                        letter: scale.forPercentage(
                          assignment.percentage ?? -1,
                        ),
                        onOpen: () => _openForm(
                          context,
                          controller,
                          course,
                          existing: assignment,
                        ),
                      ),
                    ),
                ],
                if (!resolved.isSetupComplete) ...[
                  AppSpacing.verticalMd,
                  GradusAddRow(
                    label: strings.addAssignment,
                    onTap: () => _openForm(context, controller, course),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
    ];
  }
}

// the name identifies the screen, so it belongs in the header with the code
// that qualifies it
class _CourseHeading extends StatelessWidget {
  const _CourseHeading({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        course.title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.titleMedium.copyWith(
          color: gradusPrimaryText(context),
        ),
      ),
      if (course.code.isNotEmpty)
        Text(
          course.code,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
    ],
  );
}

// an icon-only control carries the name of what it acts on
class _CourseAction extends StatelessWidget {
  const _CourseAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: label,
    child: AppIconButton(
      icon: AppIcon(icon),
      tooltip: label,
      iconColor: gradusPrimaryText(context),
      onPressed: onPressed,
    ),
  );
}

class _CourseSummary extends StatelessWidget {
  const _CourseSummary({
    required this.course,
    required this.resolved,
    required this.semesterName,
  });

  final Course course;
  final CourseGrade resolved;
  final String semesterName;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final hasAssignments = resolved.assignmentCount > 0;
    final percentage = resolved.currentPercentage;

    return AppCard(
      padding: AppSpacing.cardPaddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // an absent letter is not a letter worth a badge of its own
          if (resolved.grade != null) ...[
            Align(
              alignment: Alignment.center,
              child: GradusGradeBadge(
                letter: resolved.grade!.letter,
                countsTowardGpa: resolved.weighsOnGpa,
                isLarge: true,
              ),
            ),
          ],
          if (percentage != null) ...[
            if (resolved.grade != null) AppSpacing.verticalLg,
            Text(
              strings.currentGrade,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.verticalXs,
            Text(
              strings.percentValue(percentage),
              textAlign: TextAlign.center,
              style: AppTextStyles.displaySmall.copyWith(
                color: gradusPrimaryText(context),
              ),
            ),
          ],
          if (_exception(strings) case final note?) ...[
            AppSpacing.verticalMd,
            Align(
              alignment: Alignment.center,
              child: GradusNote(text: note),
            ),
          ],
          // with nothing graded the stats are the whole card, not a row under
          // an empty space
          if (resolved.grade != null ||
              percentage != null ||
              _exception(strings) != null)
            AppSpacing.verticalLg,
          // one row: what it could reach, what it belongs to, what it is
          // worth - the middle column keeps the term centred in the card
          Row(
            // a label that wraps must not drop its own figure out of line
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: hasAssignments
                    ? GradusStatTile(
                        label: strings.maximumPossible,
                        value: resolved.maximumPossiblePercentage == null
                            ? strings.gradeNotSet
                            : strings.percentValue(
                                resolved.maximumPossiblePercentage!,
                              ),
                        isPlaceholder:
                            resolved.maximumPossiblePercentage == null,
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: GradusStatTile(
                  label: strings.semesterLabel,
                  value: semesterName,
                  alignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: GradusStatTile(
                  label: strings.courseCredits,
                  value: strings.creditsNumber(course.credits),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // a letter the scale gives no points to still earns the credit
  String? _exception(GradusStrings strings) =>
      resolved.isAttempted && !resolved.weighsOnGpa
      ? strings.passFailNote
      : null;
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.letter,
    required this.reservesBadge,
    required this.onOpen,
  });

  final Assignment assignment;

  // true when another row has a badge, so this one keeps its room and the
  // names stay in one column
  final bool reservesBadge;

  // null when the scale cannot letter this mark, or there is no mark
  final Grade? letter;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final isGraded = assignment.isGraded;

    return AppCard(
      // the row opens the form that both edits and removes it
      onTap: onOpen,
      padding: AppSpacing.cardPaddingSm,
      child: Row(
        children: [
          if (isGraded && letter != null) ...[
            GradusGradeBadge(letter: letter!.letter),
            AppSpacing.horizontalMd,
          ] else if (reservesBadge) ...[
            const SizedBox(width: AppSpacing.avatarLg),
            AppSpacing.horizontalMd,
          ],
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
          if (isGraded) ...[
            AppSpacing.horizontalSm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.percentValue(assignment.percentage!),
                  style: AppTextStyles.titleMedium.copyWith(
                    color: gradusPrimaryText(context),
                  ),
                ),
                Text(
                  formatAssignmentScore(strings, assignment),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
