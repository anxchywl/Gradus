/// The embeddable GPA feature.
///
/// Mount it inside a host that owns authentication, theme, locale and top-level
/// navigation:
///
/// ```dart
/// GpaFeature(
///   session: GpaSession(accessToken: token),
///   dependencies: createSampleDependencies(),
///   config: const GpaConfig.sample(),
/// )
/// ```
library;

import 'package:flutter/widgets.dart';

import 'src/config/gpa_scope.dart';
import 'src/config/gpa_session.dart';
import 'src/l10n/gpa_strings.dart';
import 'src/presentation/gpa_screen.dart';

export 'src/config/gpa_scope.dart'
    show
        GpaDependencies,
        GpaScope,
        createLocalDependencies,
        createSampleDependencies;
export 'src/config/gpa_session.dart' show GpaBackend, GpaConfig, GpaSession;
export 'src/domain/course.dart' show Course;
export 'src/domain/errors.dart';
export 'src/domain/gpa.dart' show GpaResult, calculateGpa;
export 'src/domain/grade.dart' show FourPointScale, Grade, GradeScale;
export 'src/l10n/gpa_strings.dart' show GpaStrings, supportedGpaLocales;

class GpaFeature extends StatelessWidget {
  const GpaFeature({
    super.key,
    required this.session,
    required this.dependencies,
    required this.config,
  });

  final GpaSession session;
  final GpaDependencies dependencies;
  final GpaConfig config;

  @override
  Widget build(BuildContext context) {
    // the host may not register our delegate, so the feature scopes its own
    return GpaStringsScope(
      child: GpaScope(
        // a new token rebuilds the scope, discarding the previous account
        key: ValueKey(session.accessToken),
        session: session,
        dependencies: dependencies,
        child: const GpaScreen(),
      ),
    );
  }
}
