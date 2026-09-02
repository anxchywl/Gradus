import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

import '../application/gradus_controller.dart';
import '../config/gradus_scope.dart';
import '../domain/course.dart';
import '../domain/course_grade.dart';
import '../domain/semester.dart';
import '../l10n/gradus_strings.dart';
import 'confirm_dialog.dart';
import 'course_detail_screen.dart';
import 'course_form.dart';
import 'gradus_formatting.dart';
import 'gradus_responsive.dart';
import 'gradus_widgets.dart';
import 'semester_form.dart';

enum _SemesterAction { add, rename, delete }

enum _CourseAction { edit, delete }

class GradusScreen extends StatefulWidget {
  const GradusScreen({super.key});

  @override
  State<GradusScreen> createState() => _GpaScreenState();
}

class _GpaScreenState extends State<GradusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GradusScope.of(context).controller.load();
    });
  }

  Future<void> _openSemesterForm({Semester? existing}) async {
    final controller = GradusScope.of(context).controller;
    final highest = controller.semesters.isEmpty
        ? 0
        : controller.semesters.first.position;

    final semester = await showModalBottomSheet<Semester>(
      context: context,
      isScrollControlled: true,
      // mounted on the host overlay, so the delegate is installed again
      builder: (_) => GradusStringsScope(
        child: SemesterForm(nextPosition: highest + 1, existing: existing),
      ),
    );
    if (semester == null) return;
    await (existing == null
        ? controller.addSemester(semester)
        : controller.updateSemester(semester));
  }

  Future<void> _deleteSemester(Semester semester) async {
    final controller = GradusScope.of(context).controller;
    final strings = GradusStrings.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      message: strings.deleteSemesterConfirm(formatSemester(strings, semester)),
    );
    if (!confirmed) return;
    await controller.removeSemester(semester.id);
  }

  Future<void> _openCourseForm({Course? existing}) async {
    final controller = GradusScope.of(context).controller;
    final scale = controller.scale;
    final semesters = controller.semesters;
    if (scale == null || semesters.isEmpty) return;

    final course = await showModalBottomSheet<Course>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GradusStringsScope(
        child: CourseForm(
          scale: scale,
          semesters: semesters,
          initialSemesterId:
              controller.selectedSemesterId ?? semesters.first.id,
          existing: existing,
        ),
      ),
    );
    if (course == null) return;
    await (existing == null
        ? controller.addCourse(course)
        : controller.updateCourse(course));
  }

  Future<void> _deleteCourse(Course course) async {
    final controller = GradusScope.of(context).controller;
    final strings = GradusStrings.of(context);
    final confirmed = await confirmDestructiveAction(
      context,
      message: strings.deleteCourseConfirm(course.title),
    );
    if (!confirmed) return;
    await controller.removeCourse(course.id);
  }

  void _openCourse(Course course) {
    final scope = GradusScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // a pushed route builds outside this subtree, so both are re-exposed
        builder: (_) => GradusStringsScope(
          child: GradusScope(
            session: scope.session,
            controller: scope.controller,
            child: CourseDetailScreen(courseId: course.id),
          ),
        ),
      ),
    );
  }

  void _onSemesterAction(_SemesterAction action, Semester? selected) {
    switch (action) {
      case _SemesterAction.add:
        _openSemesterForm();
      case _SemesterAction.rename:
        if (selected != null) _openSemesterForm(existing: selected);
      case _SemesterAction.delete:
        if (selected != null) _deleteSemester(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final controller = GradusScope.of(context).controller;

    return Scaffold(
      appBar: AppAppBar(
        title: strings.featureTitle,
        centerTitle: false,
        actions: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _SemesterMenu(
              controller: controller,
              onSelected: _onSemesterAction,
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.isLoading) {
            return const Center(child: AppLoader());
          }
          if (controller.failure != null && controller.allCourses.isEmpty) {
            return GradusEmptyState(
              icon: AppIcons.warning,
              tone: GradusTone.warning,
              title: strings.loadFailed,
              message: strings.loadFailedBody,
              actionLabel: strings.retry,
              onAction: controller.load,
            );
          }
          if (controller.semesters.isEmpty) {
            return GradusEmptyState(
              icon: AppIcons.calendar,
              title: strings.noSemesters,
              message: strings.noSemestersBody,
              actionLabel: strings.addSemester,
              onAction: _openSemesterForm,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SemesterBar(controller: controller),
              Expanded(
                child: controller.entries.isEmpty
                    ? _EmptySemester(
                        controller: controller,
                        onAddCourse: _openCourseForm,
                      )
                    : _Body(
                        controller: controller,
                        onOpen: _openCourse,
                        onEdit: (course) => _openCourseForm(existing: course),
                        onDelete: _deleteCourse,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: controller,
        builder: (context, _) =>
            controller.semesters.isEmpty || controller.entries.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _openCourseForm,
                // the brand colour reads in both themes
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                icon: const AppIcon(AppIcons.add, color: AppColors.white),
                label: Text(strings.addCourse),
              ),
      ),
    );
  }
}

// a reason a control is unavailable belongs beside it, not always on screen
class _SemesterMenu extends StatelessWidget {
  const _SemesterMenu({required this.controller, required this.onSelected});

  final GradusController controller;
  final void Function(_SemesterAction, Semester?) onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final selected = controller.selectedSemester;
    final canDelete =
        selected != null && controller.canRemoveSemester(selected.id);

    return Semantics(
      container: true,
      button: true,
      label: strings.semesterActions,
      child: AppMenu<_SemesterAction>(
        tooltip: strings.semesterActions,
        iconColor: gradusPrimaryText(context),
        onSelected: (action) => onSelected(action, selected),
        items: [
          AppMenuItem(
            value: _SemesterAction.add,
            label: strings.addSemester,
            icon: AppIcons.add,
          ),
          if (selected != null) ...[
            AppMenuItem(
              value: _SemesterAction.rename,
              label: strings.editSemester,
              icon: AppIcons.edit,
            ),
            AppMenuItem(
              value: _SemesterAction.delete,
              label: strings.deleteSemester(formatSemester(strings, selected)),
              icon: AppIcons.delete,
              enabled: canDelete,
              isDestructive: true,
              description: canDelete ? null : strings.deleteSemesterBlocked,
            ),
          ],
        ],
      ),
    );
  }
}

class _SemesterBar extends StatelessWidget {
  const _SemesterBar({required this.controller});

  final GradusController controller;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.screenHorizontal,
          child: Row(
            children: [
              _SemesterChip(
                label: strings.allSemesters,
                isSelected: controller.isAllSemestersSelected,
                onTap: () => controller.selectSemester(null),
              ),
              for (final semester in controller.semesters)
                _SemesterChip(
                  label: formatSemester(strings, semester),
                  isSelected: semester.id == controller.selectedSemesterId,
                  onTap: () => controller.selectSemester(semester.id),
                ),
            ],
          ),
        ),
        Padding(
          padding: AppSpacing.screenPadding,
          child: CenteredContent(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                // full width would put the label and the figure far apart
                constraints: const BoxConstraints(maxWidth: gradusReadingWidth),
                child: _SummaryCard(controller: controller),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SemesterChip extends StatelessWidget {
  const _SemesterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.sm),
    child: Semantics(
      selected: isSelected,
      button: true,
      child: AppCard(
        onTap: onTap,
        // the kit's own small-control height, so the target is reachable
        height: AppSpacing.buttonHeightSm,
        padding: AppSpacing.buttonPaddingCompact,
        borderRadius: AppSpacing.borderRadiusRound,
        backgroundColor: isSelected ? AppColors.primary : null,
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.chip.copyWith(
              color: isSelected ? AppColors.white : gradusPrimaryText(context),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final GradusController controller;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final result = controller.result;
    final showSemester = !controller.isAllSemestersSelected;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            showSemester ? strings.semesterGpa : strings.cumulativeGpa,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.verticalXs,
          // an em dash at display size reads as a stray rule
          if (result.isDefined)
            Text(
              formatGpa(strings, result.value),
              style: AppTextStyles.displaySmall.copyWith(
                color: gradusPrimaryText(context),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                strings.gpaUndefined,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          AppSpacing.verticalDf,
          const Divider(height: AppSpacing.dividerDf, color: AppColors.divider),
          AppSpacing.verticalDf,
          Row(
            children: [
              if (showSemester)
                Expanded(
                  child: GradusStatTile(
                    label: strings.cumulativeGpa,
                    value: formatGpa(
                      strings,
                      controller.cumulativeResult.value,
                    ),
                  ),
                ),
              Expanded(
                flex: showSemester ? 1 : 2,
                child: GradusStatTile(
                  // a label and a figure, not a sentence dressed as a figure
                  label: strings.creditsCountedLabel,
                  value: strings.creditsRatio(
                    result.qualityCredits,
                    result.attemptedCredits,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySemester extends StatelessWidget {
  const _EmptySemester({required this.controller, required this.onAddCourse});

  final GradusController controller;
  final VoidCallback onAddCourse;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    return GradusEmptyState(
      icon: AppIcons.book,
      title: strings.noCourses,
      message: strings.noCoursesBody,
      actionLabel: strings.addCourse,
      onAction: onAddCourse,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final GradusController controller;
  final void Function(Course) onOpen;
  final void Function(Course) onEdit;
  final void Function(Course) onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final scale = controller.scale!;

    Widget card(Course course) => _CourseCard(
      course: course,
      resolved: calculateCourseGrade(course, scale),
      onOpen: () => onOpen(course),
      onEdit: () => onEdit(course),
      onDelete: () => onDelete(course),
    );

    final children = <Widget>[];
    if (controller.isAllSemestersSelected) {
      for (final semester in controller.semesters) {
        final courses = controller.coursesIn(semester.id);
        if (courses.isEmpty) continue;
        children
          ..add(
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.md,
              ),
              child: GradusSectionHeader(
                title: formatSemester(strings, semester),
              ),
            ),
          )
          ..add(
            CardGrid(
              spacing: AppSpacing.md,
              children: [for (final course in courses) card(course)],
            ),
          );
      }
    } else {
      children.add(
        CardGrid(
          spacing: AppSpacing.md,
          children: [for (final course in controller.entries) card(course)],
        ),
      );
    }

    return ListView(
      padding: AppSpacing.screenHorizontal,
      children: [
        CenteredContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        // the button floats over the list, so the last row stays reachable
        const SizedBox(height: AppSpacing.xxxxl + AppSpacing.xl),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.resolved,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final CourseGrade resolved;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradusGradeBadge(
                letter: formatLetter(strings, resolved),
                countsTowardGpa: resolved.weighsOnGpa,
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (course.code.isNotEmpty) ...[
                      Text(
                        course.code,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      AppSpacing.verticalXs,
                    ],
                    Text(
                      course.title,
                      // one course cannot push the list off screen
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: gradusPrimaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              _CourseMenu(course: course, onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          AppSpacing.verticalSm,
          Text(
            formatCourseMeta(strings, course.credits, resolved),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (resolved.assignmentCount > 0) ...[
            AppSpacing.verticalMd,
            AppProgressBar(
              progress: resolved.gradedWeight / 100,
              height: AppSpacing.xs,
            ),
            AppSpacing.verticalSm,
            Text(
              formatAssignmentProgress(strings, resolved),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (_chips(strings).isNotEmpty) ...[
            AppSpacing.verticalMd,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _chips(strings),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _chips(GradusStrings strings) => [
    // without this a muted badge is the same as a course with no marks at all
    if (resolved.isAttempted && !resolved.weighsOnGpa)
      GradusStatusChip(
        label: course.gradingMode == GradingMode.passFail
            ? strings.gradingModePassFail
            : strings.passFailNote,
        icon: AppIcons.checkCircle,
        tone: GradusTone.info,
      ),
    if (!course.includeInGpa)
      GradusStatusChip(label: strings.excludedFromGpa, icon: AppIcons.info),
    if (resolved.assignmentCount > 0 && !resolved.isSetupComplete)
      GradusStatusChip(
        label: strings.setupIncomplete(resolved.unallocatedWeight),
        icon: AppIcons.warning,
        tone: GradusTone.warning,
      ),
  ];
}

// two icon buttons put a destructive action one mis-tap from a scroll
class _CourseMenu extends StatelessWidget {
  const _CourseMenu({
    required this.course,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    return Semantics(
      container: true,
      button: true,
      label: strings.courseActions(course.title),
      child: AppMenu<_CourseAction>(
        tooltip: strings.courseActions(course.title),
        iconColor: AppColors.textSecondary,
        onSelected: (action) => switch (action) {
          _CourseAction.edit => onEdit(),
          _CourseAction.delete => onDelete(),
        },
        items: [
          AppMenuItem(
            value: _CourseAction.edit,
            label: strings.editCourse,
            icon: AppIcons.edit,
          ),
          AppMenuItem(
            value: _CourseAction.delete,
            label: strings.deleteCourse(course.title),
            icon: AppIcons.delete,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}
