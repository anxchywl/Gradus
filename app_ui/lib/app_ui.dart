/// Shared Flutter UI kit: design tokens, generic widgets, light and dark themes.
///
/// ```dart
/// import 'package:app_ui/app_ui.dart';
/// ```
///
/// Tokens are the only source of colour, spacing, radius, shadow and type.
/// Never use `Colors.*`, a raw `Color`, a raw `TextStyle` or a raw spacing
/// number in feature code. Radius lives in [AppSpacing]; there is one scale.
///
/// Nothing product-specific belongs in this package. See PROVENANCE.md.
library;

// Tokens
export 'tokens/app_colors.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_shadows.dart';
export 'tokens/app_text_styles.dart';

// Icons
export 'icons/app_icon_data.dart';
export 'icons/app_icon.dart';
export 'icons/app_icons.dart';

// Buttons
export 'buttons/app_primary_button.dart';
export 'buttons/app_secondary_button.dart';
export 'buttons/app_text_button.dart';
export 'buttons/app_icon_button.dart';

// Inputs
export 'inputs/app_text_field.dart';
export 'inputs/app_search_bar.dart';

// Cards
export 'cards/app_card.dart';
export 'cards/app_list_tile.dart';

// AppBars
export 'appbars/app_app_bar.dart';

// Dialogs
export 'dialogs/app_bottom_sheet.dart';

// Indicators
export 'indicators/app_loader.dart';
export 'indicators/app_progress_bar.dart';

// Theme
export 'theme/app_theme.dart';

// Widgets
export 'widgets/app_toast.dart';
export 'widgets/toast_manager.dart';
