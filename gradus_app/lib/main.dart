import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gradus_feature/gradus_feature.dart';

import 'dev/dev_gate.dart';

void main() => runApp(const GradusHostApp());

// a real host would own identity and navigation, this one runs the feature alone
class GradusHostApp extends StatefulWidget {
  const GradusHostApp({super.key});

  @override
  State<GradusHostApp> createState() => _GradusHostAppState();
}

class _GradusHostAppState extends State<GradusHostApp> {
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
      title: 'Gradus',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: supportedGradusLocales,
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
      child: GradusFeature(
        session: GradusSession(accessToken: token, accountId: role.name),
        // courses persist on this device, namespaced per development identity
        dependencies: createLocalDependencies(accountId: role.name),
        config: const GradusConfig.sample(),
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
