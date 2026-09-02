import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/gpa_localizations.dart';

const List<Locale> supportedGpaLocales = GpaLocalizations.supportedLocales;

typedef GpaStrings = GpaLocalizations;

class GpaStringsScope extends StatelessWidget {
  const GpaStringsScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ambient = Localizations.maybeLocaleOf(context);
    return Localizations.override(
      context: context,
      locale: _resolve(ambient),
      delegates: const [
        GpaLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      child: child,
    );
  }

  static Locale _resolve(Locale? ambient) {
    if (ambient == null) return const Locale('en');
    for (final locale in supportedGpaLocales) {
      if (locale.languageCode == ambient.languageCode) return locale;
    }
    return const Locale('en');
  }
}
