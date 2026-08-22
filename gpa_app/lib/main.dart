import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gpa_feature/gpa_feature.dart';

import 'dev/dev_gate.dart';

void main() => runApp(const GpaHostApp());

/// The host owns MaterialApp, theme, locale, lifecycle and top-level
/// navigation. In production that host is the superapp; this one exists so the
/// feature can be run on its own.
class GpaHostApp extends StatefulWidget {
  const GpaHostApp({super.key});

  @override
  State<GpaHostApp> createState() => _GpaHostAppState();
}

class _GpaHostAppState extends State<GpaHostApp> {
  DevelopmentRole _role = DevelopmentRole.student;

  void _switchRole() {
    setState(() {
      _role = _role == DevelopmentRole.student
          ? DevelopmentRole.operator
          : DevelopmentRole.student;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPA',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedGpaLocales,
      home: _Host(role: _role, onSwitchRole: _switchRole),
    );
  }
}

class _Host extends StatelessWidget {
  const _Host({required this.role, required this.onSwitchRole});

  final DevelopmentRole role;
  final VoidCallback onSwitchRole;

  @override
  Widget build(BuildContext context) {
    if (!isDevelopmentAccessAllowed) {
      return const _Closed();
    }

    final token = tokenFor(role);
    if (token.isEmpty) {
      return const _Closed(missingToken: true);
    }

    return GestureDetector(
      // debug affordance only; it changes which token is sent, never a claim
      onLongPress: onSwitchRole,
      child: GpaFeature(
        session: GpaSession(accessToken: token),
        dependencies: createSampleDependencies(),
        config: const GpaConfig.sample(),
      ),
    );
  }
}

class _Closed extends StatelessWidget {
  const _Closed({this.missingToken = false});

  final bool missingToken;

  @override
  Widget build(BuildContext context) {
    // host-shell diagnostics, never shown to a student, so not localized
    final message = missingToken
        ? 'No development token was supplied to this build.'
        : 'This build does not permit standalone access.';
    return Scaffold(
      body: Center(
        child: Padding(padding: AppSpacing.screenPadding, child: Text(message)),
      ),
    );
  }
}
