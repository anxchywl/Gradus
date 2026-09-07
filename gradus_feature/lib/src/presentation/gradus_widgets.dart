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

// the home indicator would otherwise sit on top of the last control; the
// keyboard takes this padding back, because it lifts the sheet clear itself
EdgeInsets gradusSheetPadding(BuildContext context) => AppSpacing.screenPadding
    .copyWith(bottom: AppSpacing.df + MediaQuery.paddingOf(context).bottom);

// a dropdown opens a second surface over the sheet; this looks like the fields
// beside it and hands over to a panel inside the sheet itself
class GradusChooserField extends StatelessWidget {
  const GradusChooserField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    value: value,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusDf,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: gradusPrimaryText(context),
                ),
              ),
            ),
            const AppIcon(
              AppIcons.chevronDown,
              size: AppSpacing.iconSm,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}

class GradusChooserOption<T> {
  const GradusChooserOption({required this.value, required this.label});

  final T value;
  final String label;
}

// the sheet becomes the chooser rather than stacking one on top of it; the
// options wrap so a long scale does not take the whole screen
class GradusChooserPanel<T> extends StatelessWidget {
  const GradusChooserPanel({
    super.key,
    required this.title,
    required this.rows,
    required this.selected,
    required this.onSelected,
    required this.onCancel,
    required this.cancelLabel,
  });

  final String title;

  // the caller groups the options, because only it knows what they mean
  final List<List<GradusChooserOption<T>>> rows;

  final T selected;
  final ValueChanged<T> onSelected;
  final VoidCallback onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GradusSheetTitle(text: title),
      AppSpacing.verticalDf,
      for (final row in rows) ...[
        // a wrap rather than a row, so a group too wide for the sheet folds
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final option in row)
              _ChooserChip(
                label: option.label,
                isSelected: option.value == selected,
                onTap: () => onSelected(option.value),
              ),
          ],
        ),
        AppSpacing.verticalSm,
      ],
      AppSpacing.verticalSm,
      AppSecondaryButton(
        text: cancelLabel,
        size: AppButtonSize.medium,
        onPressed: onCancel,
      ),
    ],
  );
}

class _ChooserChip extends StatelessWidget {
  const _ChooserChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: isSelected,
    button: true,
    child: AppCard(
      onTap: onTap,
      // the kit's own small-control height, so the target is reachable
      height: AppSpacing.buttonHeightSm,
      padding: AppSpacing.buttonPaddingCompact,
      borderRadius: AppSpacing.borderRadiusRound,
      backgroundColor: isSelected
          ? AppColors.primary
          : gradusMutedSurface(context),
      // without a width factor the centre would claim the whole wrap line
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            color: isSelected ? AppColors.white : gradusPrimaryText(context),
          ),
        ),
      ),
    ),
  );
}

// every sheet ends the same way: the way out beside the commitment, both
// compact enough to sit on one row
class GradusFormActions extends StatelessWidget {
  const GradusFormActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.isPrimaryDestructive = false,
    this.isSecondaryDestructive = false,
    this.isSecondaryEnabled = true,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final bool isPrimaryDestructive;
  final bool isSecondaryDestructive;
  final bool isSecondaryEnabled;

  @override
  Widget build(BuildContext context) {
    final destructive = Theme.of(context).brightness == Brightness.light
        ? AppColors.errorText
        : AppColors.errorTextDark;

    return Row(
      children: [
        Expanded(
          child: AppSecondaryButton(
            text: secondaryLabel,
            size: AppButtonSize.medium,
            isEnabled: isSecondaryEnabled,
            borderColor: isSecondaryDestructive ? destructive : null,
            textColor: isSecondaryDestructive ? destructive : null,
            onPressed: onSecondary,
          ),
        ),
        AppSpacing.horizontalMd,
        Expanded(
          child: isPrimaryDestructive
              ? AppSecondaryButton(
                  text: primaryLabel,
                  size: AppButtonSize.medium,
                  borderColor: destructive,
                  textColor: destructive,
                  onPressed: onPrimary,
                )
              : AppPrimaryButton(
                  text: primaryLabel,
                  size: AppButtonSize.medium,
                  onPressed: onPrimary,
                ),
        ),
      ],
    );
  }
}

// the heading of a sheet, centred over the fields it introduces
class GradusSheetTitle extends StatelessWidget {
  const GradusSheetTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: AppTextStyles.titleLarge.copyWith(color: gradusPrimaryText(context)),
  );
}

// the same height and radius as the rows it follows, so a list ends in a
// control rather than under a button floating over its last row
class GradusAddRow extends StatelessWidget {
  const GradusAddRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: AppSpacing.cardPaddingSm,
    backgroundColor: gradusMutedSurface(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppIcon(
          AppIcons.add,
          size: AppSpacing.iconSm,
          color: AppColors.primary,
        ),
        AppSpacing.horizontalSm,
        Text(
          label,
          style: AppTextStyles.button.copyWith(color: AppColors.primary),
        ),
      ],
    ),
  );
}

// a fact about a course reads as a line of prose; a pill turns a sentence
// into a badge the reader has to decode
class GradusNote extends StatelessWidget {
  const GradusNote({
    super.key,
    required this.text,
    this.tone = GradusTone.neutral,
  });

  final String text;
  final GradusTone tone;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.bodySmall.copyWith(
      color: _toneForeground(tone, context),
    ),
  );
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
      // fixed, not minimum: a wider letter would step the names beside it out
      // of line with the row above
      width: isLarge ? AppSpacing.avatarXl : AppSpacing.avatarLg,
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
  const GradusStatTile({
    super.key,
    required this.label,
    required this.value,
    this.isPlaceholder = false,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;

  // a short phrase saying why a figure is absent, not a figure
  final bool isPlaceholder;

  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        textAlign: _textAlign,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      AppSpacing.verticalXs,
      Text(
        value,
        textAlign: _textAlign,
        style: isPlaceholder
            ? AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)
            : AppTextStyles.titleMedium.copyWith(
                color: gradusPrimaryText(context),
              ),
      ),
    ],
  );

  // a wrapped label follows the column it sits in
  TextAlign get _textAlign => switch (alignment) {
    CrossAxisAlignment.end => TextAlign.end,
    CrossAxisAlignment.center => TextAlign.center,
    _ => TextAlign.start,
  };
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
          textAlign: TextAlign.center,
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
