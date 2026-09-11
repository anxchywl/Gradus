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
      useSafeArea: true,
      isScrollControlled: true,
      // mounted on the host overlay, so the delegate is installed again
      builder: (_) => GradusStringsScope(
        child: SemesterForm(
          nextPosition: highest + 1,
          existing: existing,
          // a term holding courses cannot go, and the sheet says why
          canDelete:
              existing != null && controller.canRemoveSemester(existing.id),
          onDelete: existing == null ? null : () => _deleteSemester(existing),
        ),
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
      message: strings.deleteSemesterConfirm,
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
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => GradusStringsScope(
        child: CourseForm(
          scale: scale,
          semesters: semesters,
          initialSemesterId:
              controller.selectedSemesterId ?? semesters.first.id,
          existing: existing,
          onImportSyllabus: controller.canImportSyllabus
              ? controller.importSyllabus
              : null,
        ),
      ),
    );
    if (course == null) return;
    await (existing == null
        ? controller.addCourse(course)
        : controller.updateCourse(course));
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

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final controller = GradusScope.of(context).controller;

    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomScrollView(
          slivers: [
            // the header gives the list its room back on the way down
            // an account with nothing in it gets the screen to its one way
            // forward, without a title over it
            if (controller.semesters.isNotEmpty)
              AppSliverAppBar(title: strings.featureTitle),
            ..._content(context, controller, strings),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    GradusController controller,
    GradusStrings strings,
  ) {
    Widget fills(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: child);

    if (controller.isLoading) {
      return [fills(const Center(child: AppLoader()))];
    }
    if (controller.failure != null && controller.allCourses.isEmpty) {
      return [
        fills(
          GradusEmptyState(
            icon: AppIcons.warning,
            tone: GradusTone.warning,
            title: strings.loadFailed,
            message: strings.loadFailedBody,
            actionLabel: strings.retry,
            onAction: controller.load,
          ),
        ),
      ];
    }
    if (controller.semesters.isEmpty) {
      return [
        fills(
          GradusEmptyState(
            title: strings.noSemesters,
            actionLabel: strings.addSemester,
            onAction: _openSemesterForm,
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: _SemesterBar(
          controller: controller,
          // with nothing to average, the GPA panel has nothing to say
          showSummary: controller.entries.isNotEmpty,
          onAddSemester: _openSemesterForm,
          onEditSemester: (semester) => _openSemesterForm(existing: semester),
        ),
      ),
      if (controller.entries.isEmpty)
        fills(
          _EmptySemester(controller: controller, onAddCourse: _openCourseForm),
        )
      else ...[
        SliverToBoxAdapter(
          child: _Body(
            controller: controller,
            onOpen: _openCourse,
            onAdd: _openCourseForm,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    ];
  }
}

class _SemesterBar extends StatelessWidget {
  const _SemesterBar({
    required this.controller,
    required this.showSummary,
    required this.onAddSemester,
    required this.onEditSemester,
  });

  final GradusController controller;
  final bool showSummary;
  final VoidCallback onAddSemester;
  final void Function(Semester) onEditSemester;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenHorizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                _AddSemesterChip(onTap: onAddSemester),
              ],
            ),
          ),
        ),
        if (showSummary)
          Padding(
            padding: AppSpacing.screenPadding,
            child: CenteredContent(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  // full width would put the label and the figure far apart
                  constraints: const BoxConstraints(
                    maxWidth: gradusReadingWidth,
                  ),
                  child: _SummaryCard(
                    controller: controller,
                    onEditSemester: onEditSemester,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddSemesterChip extends StatelessWidget {
  const _AddSemesterChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    return Semantics(
      container: true,
      button: true,
      label: strings.addSemester,
      child: Tooltip(
        message: strings.addSemester,
        child: AppCard(
          onTap: onTap,
          height: AppSpacing.buttonHeightSm,
          padding: AppSpacing.buttonPaddingCompact,
          borderRadius: AppSpacing.borderRadiusRound,
          child: const Center(
            child: AppIcon(
              AppIcons.add,
              size: AppSpacing.iconSm,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
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
  const _SummaryCard({required this.controller, required this.onEditSemester});

  final GradusController controller;
  final void Function(Semester) onEditSemester;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final result = controller.result;
    final selected = controller.selectedSemester;
    final showSemester = !controller.isAllSemestersSelected && selected != null;

    return AppCard(
      // the card is the semester, so tapping it opens the semester
      onTap: showSemester ? () => onEditSemester(selected) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            showSemester ? strings.semesterGpa : strings.cumulativeGpa,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          AppSpacing.verticalXs,
          // an em dash at display size reads as a stray rule
          if (result.isDefined)
            Text(
              formatGpa(strings, result.value),
              textAlign: TextAlign.center,
              style: AppTextStyles.displaySmall.copyWith(
                color: gradusPrimaryText(context),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                strings.gpaUndefined,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          AppSpacing.verticalXs,
          // what the average was earned over, under the average itself
          Text(
            strings.creditsEarnedCount(result.attemptedCredits),
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
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
      title: strings.noCourses,
      actionLabel: strings.addCourse,
      onAction: onAddCourse,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.onOpen,
    required this.onAdd,
  });

  final GradusController controller;
  final void Function(Course) onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);
    final scale = controller.scale!;

    // one graded course is enough for the rest to keep the badge's room
    final anyGraded = controller.allCourses.any(
      (course) => calculateCourseGrade(course, scale).grade != null,
    );

    Widget card(Course course) => _CourseCard(
      course: course,
      resolved: calculateCourseGrade(course, scale),
      reservesBadge: anyGraded,
      onOpen: () => onOpen(course),
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
                top: AppSpacing.lg,
                bottom: AppSpacing.md,
              ),
              child: _SemesterHeading(
                title: formatSemester(strings, semester),
                totals: formatSemesterTotals(
                  strings,
                  controller.resultFor(semester.id),
                ),
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
    children
      ..add(AppSpacing.verticalMd)
      ..add(GradusAddRow(label: strings.addCourse, onTap: onAdd));

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: CenteredContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.resolved,
    required this.reservesBadge,
    required this.onOpen,
  });

  final Course course;
  final CourseGrade resolved;

  // true when another course has a badge, so this one keeps its room and the
  // titles stay in one column
  final bool reservesBadge;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final strings = GradusStrings.of(context);

    return AppCard(
      onTap: onOpen,
      child: Row(
        // the name sits level with the letter it belongs to
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // a course with no grade yet carries no badge, and no dash for one
          if (resolved.grade != null) ...[
            GradusGradeBadge(
              letter: resolved.grade!.letter,
              countsTowardGpa: resolved.weighsOnGpa,
            ),
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
                  course.title,
                  // one course cannot push the list off screen
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: gradusPrimaryText(context),
                  ),
                ),
                if (course.code.isNotEmpty) ...[
                  AppSpacing.verticalXs,
                  Text(
                    course.code,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.horizontalMd,
          // what the letter is worth, opposite the letter itself
          Text(
            strings.creditsCount(course.credits),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// a term header carries that term's own figures, so the summary card is not
// the only place a total appears
class _SemesterHeading extends StatelessWidget {
  const _SemesterHeading({required this.title, required this.totals});

  final String title;
  final String totals;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppTextStyles.sectionHeader.copyWith(
          color: gradusPrimaryText(context),
        ),
      ),
      AppSpacing.verticalXs,
      Text(
        totals,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );
}
