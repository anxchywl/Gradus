import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/gradus_localizations.dart';

const List<Locale> supportedGradusLocales =
    GradusLocalizations.supportedLocales;

typedef GradusStrings = GradusLocalizations;

class GradusStringsScope extends StatelessWidget {
  const GradusStringsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ambient = Localizations.maybeLocaleOf(context);
    return Localizations.override(
      context: context,
      locale: _resolve(ambient),
      delegates: const [
        GradusLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: child,
    );
  }

  static Locale _resolve(Locale? ambient) {
    if (ambient == null) return const Locale('en');
    for (final locale in supportedGradusLocales) {
      if (locale.languageCode == ambient.languageCode) return locale;
    }
    return const Locale('en');
  }
}
