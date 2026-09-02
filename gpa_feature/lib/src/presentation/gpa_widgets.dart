import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

// the kit styles carry no colour, these are for places that need one
Color gpaPrimaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? AppColors.textPrimary
    : AppColors.textPrimaryDark;

Color gpaSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? AppColors.white
    : AppColors.surfaceDark;

Color gpaMutedSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? AppColors.fieldBackground
    : AppColors.borderDark;

enum GpaTone { neutral, info, warning }

Color _toneForeground(GpaTone tone, BuildContext context) => switch (tone) {
  GpaTone.neutral => AppColors.textSecondary,
  GpaTone.info => AppColors.info,
  GpaTone.warning => AppColors.warning,
};

Color _toneBackground(GpaTone tone, BuildContext context) {
  if (Theme.of(context).brightness != Brightness.light) {
    // the light tints are far too bright on a dark surface
    return _toneForeground(tone, context).withValues(alpha: 0.16);
  }
  return switch (tone) {
    GpaTone.neutral => AppColors.fieldBackground,
    GpaTone.info => AppColors.infoLight,
    GpaTone.warning => AppColors.warningLight,
  };
}

// a reader scans these, they do not read grey sentences stacked under a card
class GpaStatusChip extends StatelessWidget {
  const GpaStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = GpaTone.neutral,
  });

  final String label;
  final AppIconData? icon;
  final GpaTone tone;

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
class GpaGradeBadge extends StatelessWidget {
  const GpaGradeBadge({
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
        : gpaMutedSurface(context);

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
class GpaStatTile extends StatelessWidget {
  const GpaStatTile({super.key, required this.label, required this.value});

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
          color: gpaPrimaryText(context),
        ),
      ),
    ],
  );
}

class GpaStatGrid extends StatelessWidget {
  const GpaStatGrid({super.key, required this.tiles});

  final List<GpaStatTile> tiles;

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

class GpaSectionHeader extends StatelessWidget {
  const GpaSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: AppTextStyles.sectionHeader.copyWith(
            color: gpaPrimaryText(context),
          ),
        ),
      ),
      ?trailing,
    ],
  );
}

// an empty screen with no way forward is a dead end
class GpaEmptyState extends StatelessWidget {
  const GpaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = GpaTone.neutral,
  });

  final AppIconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final GpaTone tone;

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
              color: gpaPrimaryText(context),
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
