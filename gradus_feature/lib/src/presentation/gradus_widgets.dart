import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

// the kit styles carry no colour, these are for places that need one
Color gradusPrimaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? AppColors.textPrimary
    : AppColors.textPrimaryDark;

Color gradusSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? AppColors.white
    : AppColors.surfaceDark;

Color gradusMutedSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? AppColors.fieldBackground
    : AppColors.borderDark;

enum GradusTone { neutral, info, warning }

Color _toneForeground(GradusTone tone, BuildContext context) => switch (tone) {
  GradusTone.neutral => AppColors.textSecondary,
  GradusTone.info => AppColors.info,
  GradusTone.warning => AppColors.warning,
};

Color _toneBackground(GradusTone tone, BuildContext context) {
  if (Theme.of(context).brightness != Brightness.light) {
    // the light tints are far too bright on a dark surface
    return _toneForeground(tone, context).withValues(alpha: 0.16);
  }
  return switch (tone) {
    GradusTone.neutral => AppColors.fieldBackground,
    GradusTone.info => AppColors.infoLight,
    GradusTone.warning => AppColors.warningLight,
  };
}

// a reader scans these, they do not read grey sentences stacked under a card
class GradusStatusChip extends StatelessWidget {
  const GradusStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = GradusTone.neutral,
  });

  final String label;
  final AppIconData? icon;
  final GradusTone tone;

  @override
  Widget build(BuildContext context) {
    final foreground = _toneForeground(tone, context);
    return Container(
      padding: AppSpacing.chipPadding,
      decoration: BoxDecoration(
        color: _toneBackground(tone, context),
        borderRadius: AppSpacing.borderRadiusRound,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: AppSpacing.iconSm, color: foreground),
            AppSpacing.horizontalXs,
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.chip.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

// muted when the letter does not move the average, so a pass is not a lost A
class GradusGradeBadge extends StatelessWidget {
  const GradusGradeBadge({
    super.key,
    required this.letter,
    this.countsTowardGpa = true,
    this.isLarge = false,
  });

  final String letter;
  final bool countsTowardGpa;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = countsTowardGpa
        ? AppColors.primary
        : AppColors.textSecondary;
    final background = countsTowardGpa
        ? (isLight ? AppColors.primaryLight : AppColors.primaryLightDark)
        : gradusMutedSurface(context);

    return Container(
      constraints: BoxConstraints(
        minWidth: isLarge ? AppSpacing.avatarDf : AppSpacing.avatarSm,
      ),
      padding: AppSpacing.chipPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Text(
        letter,
        textAlign: TextAlign.center,
        style:
            (isLarge ? AppTextStyles.headlineSmall : AppTextStyles.titleMedium)
                .copyWith(color: foreground),
      ),
    );
  }
}

// the label sits above the figure so a bare number is never met first
class GradusStatTile extends StatelessWidget {
  const GradusStatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      AppSpacing.verticalXs,
      Text(
        value,
        style: AppTextStyles.titleMedium.copyWith(
          color: gradusPrimaryText(context),
        ),
      ),
    ],
  );
}

class GradusStatGrid extends StatelessWidget {
  const GradusStatGrid({super.key, required this.tiles});

  final List<GradusStatTile> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // measured against the width the card offers, not the screen
      final columns = constraints.maxWidth < AppSpacing.avatarXxl * 3 ? 1 : 2;
      final width =
          (constraints.maxWidth - AppSpacing.df * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.df,
        runSpacing: AppSpacing.df,
        children: [
          for (final tile in tiles) SizedBox(width: width, child: tile),
        ],
      );
    },
  );
}

class GradusSectionHeader extends StatelessWidget {
  const GradusSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: AppTextStyles.sectionHeader.copyWith(
            color: gradusPrimaryText(context),
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

// an empty screen with no way forward is a dead end
class GradusEmptyState extends StatelessWidget {
  const GradusEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = GradusTone.neutral,
  });

  final AppIconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final GradusTone tone;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: AppSpacing.cardPadding,
            decoration: BoxDecoration(
              color: _toneBackground(tone, context),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              icon,
              size: AppSpacing.iconLg,
              color: _toneForeground(tone, context),
            ),
          ),
          AppSpacing.verticalLg,
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: gradusPrimaryText(context),
            ),
          ),
          AppSpacing.verticalSm,
          ConstrainedBox(
            // a measure that stays readable rather than one long line
            constraints: const BoxConstraints(maxWidth: AppSpacing.xxxxl * 5),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            AppSpacing.verticalXl,
            AppPrimaryButton(
              text: actionLabel!,
              onPressed: onAction,
              width: AppSpacing.xxxxl * 4,
            ),
          ],
        ],
      ),
    ),
  );
}
