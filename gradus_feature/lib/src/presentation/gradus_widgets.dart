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
EdgeInsets gradusSheetPadding(BuildContext context) =>
    AppSpacing.screenPadding.copyWith(
      // the theme's drag handle already stands above the header
      top: AppSpacing.xs,
      bottom: AppSpacing.df + MediaQuery.paddingOf(context).bottom,
    );

// a dropdown opens a second surface over the sheet; this looks like the fields
// beside it and hands over to a panel inside the sheet itself
class GradusChooserField extends StatelessWidget {
  const GradusChooserField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.isEnabled = true,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) => GradusField(
    label: label,
    // the chooser names itself below, so the heading is not read twice
    excludeLabelSemantics: true,
    child: _field(context),
  );

  Widget _field(BuildContext context) => Semantics(
    button: true,
    enabled: isEnabled,
    label: label,
    value: value,
    child: InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: AppSpacing.borderRadiusDf,
      child: InputDecorator(
        decoration: InputDecoration(enabled: isEnabled),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isEnabled
                      ? gradusPrimaryText(context)
                      : AppColors.textSecondary,
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
  });

  final String title;

  // the caller groups the options, because only it knows what they mean
  final List<List<GradusChooserOption<T>>> rows;

  final T selected;
  final ValueChanged<T> onSelected;

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

// every sheet ends the same way: the commitment on the right, taking the width,
// and anything else as a small button on its left
class GradusFormActions extends StatelessWidget {
  const GradusFormActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.isPrimaryDestructive = false,
    this.isSecondaryDestructive = false,
    this.isSecondaryEnabled = true,
    this.isPrimaryEnabled = true,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isPrimaryDestructive;
  final bool isSecondaryDestructive;
  final bool isSecondaryEnabled;
  final bool isPrimaryEnabled;

  @override
  Widget build(BuildContext context) {
    final destructive = Theme.of(context).brightness == Brightness.light
        ? AppColors.errorText
        : AppColors.errorTextDark;
    final primary = AppPrimaryButton(
      text: primaryLabel,
      isEnabled: isPrimaryEnabled,
      color: isPrimaryDestructive ? destructive : null,
      onPressed: onPrimary,
    );
    final secondary = secondaryLabel;
    if (secondary == null) return primary;

    return Row(
      children: [
        _CompactAction(
          label: secondary,
          isDestructive: isSecondaryDestructive,
          isEnabled: isSecondaryEnabled,
          onPressed: onSecondary,
        ),
        AppSpacing.horizontalMd,
        Expanded(child: primary),
      ],
    );
  }
}

// small and tinted rather than outlined, so it never reads as the main action
class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.label,
    required this.isDestructive,
    required this.isEnabled,
    required this.onPressed,
  });

  final String label;
  final bool isDestructive;
  final bool isEnabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final foreground = isDestructive
        ? (isLight ? AppColors.errorText : AppColors.errorTextDark)
        : gradusPrimaryText(context);
    final background = isDestructive
        ? (isLight
              ? AppColors.errorLight
              : AppColors.errorTextDark.withValues(alpha: 0.15))
        : gradusMutedSurface(context);
    final isActive = isEnabled && onPressed != null;

    return Semantics(
      button: true,
      enabled: isActive,
      child: Opacity(
        opacity: isActive ? 1 : 0.5,
        child: Material(
          color: background,
          borderRadius: AppSpacing.borderRadiusDf,
          child: InkWell(
            onTap: isActive ? onPressed : null,
            borderRadius: AppSpacing.borderRadiusDf,
            child: SizedBox(
              // level with the commitment beside it
              height: AppSpacing.buttonHeightLg,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppTextStyles.button.copyWith(color: foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
    required this.title,
    this.icon,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = GradusTone.neutral,
  });

  // a failure explains itself; an empty screen needs only its title
  final AppIconData? icon;
  final String title;
  final String? message;
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
          if (icon case final icon?) ...[
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
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: gradusPrimaryText(context),
            ),
          ),
          if (message case final message?) ...[
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
          ],
          if (actionLabel != null && onAction != null) ...[
            AppSpacing.verticalXl,
            // the width a thumb expects on a phone, held to the measure of
            // the text above so a tablet does not stretch it edge to edge
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.xxxxl * 5),
              child: AppPrimaryButton(text: actionLabel!, onPressed: onAction),
            ),
          ],
        ],
      ),
    ),
  );
}

// the label stands above its field, where it stays readable once the field is
// filled in, instead of shrinking into the field's top edge
class GradusField extends StatelessWidget {
  const GradusField({
    super.key,
    required this.label,
    required this.child,
    this.excludeLabelSemantics = false,
  });

  final String label;
  final Widget child;

  // a control that already names itself would otherwise be read twice
  final bool excludeLabelSemantics;

  @override
  Widget build(BuildContext context) {
    final heading = Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: 6),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: gradusPrimaryText(context),
        ),
      ),
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (excludeLabelSemantics)
          ExcludeSemantics(child: heading)
        else
          heading,
        child,
      ],
    );
    // merged, so a screen reader announces the field by the label above it
    return excludeLabelSemantics ? column : MergeSemantics(child: column);
  }
}

// a rule with words in it, between two ways of doing the same thing
class GradusDividerLabel extends StatelessWidget {
  const GradusDividerLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.light
        ? AppColors.lightGrey
        : AppColors.borderDark;
    return Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            text.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: color)),
      ],
    );
  }
}
