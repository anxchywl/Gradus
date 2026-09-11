import 'package:flutter/foundation.dart';
import 'package:gradus_feature/gradus_feature.dart';

// default deny, a release build needs a define no shipped build passes
const bool _devAccessRequested = bool.fromEnvironment('ENABLE_DEV_ACCESS');

const bool _standaloneReleaseAccess = bool.fromEnvironment(
  'ALLOW_STANDALONE_DEV_ACCESS',
);

bool get isDevelopmentAccessAllowed => developmentAccessAllowed(
  isDebugMode: kDebugMode,
  requested: _devAccessRequested,
  allowReleaseAccess: _standaloneReleaseAccess,
);

@visibleForTesting
bool developmentAccessAllowed({
  required bool isDebugMode,
  required bool requested,
  bool allowReleaseAccess = false,
}) => requested && (isDebugMode || allowReleaseAccess);

const String configuredBackend = String.fromEnvironment(
  'GRADUS_BACKEND',
  defaultValue: 'sample',
);

const String configuredApiBaseUrl = String.fromEnvironment(
  'GRADUS_API_BASE_URL',
);

// no default, a token is a bearer credential and never leaves this machine
const String developmentUserToken = String.fromEnvironment(
  'GRADUS_ACCESS_TOKEN',
);

const String developmentOperatorToken = String.fromEnvironment(
  'GRADUS_OPERATOR_ACCESS_TOKEN',
);

// the client never claims a role, the backend resolves what the token allows
enum DevelopmentRole { student, operator }

String tokenFor(DevelopmentRole role) => switch (role) {
  DevelopmentRole.student => developmentUserToken,
  DevelopmentRole.operator => developmentOperatorToken,
};

// sample keeps the transcript on the device and offers no import; remote sends
// a chosen syllabus to the backend named here
GradusConfig get hostConfig => resolveHostConfig(
  backend: configuredBackend,
  apiBaseUrl: configuredApiBaseUrl,
  isDebugMode: kDebugMode,
);

@visibleForTesting
GradusConfig resolveHostConfig({
  required String backend,
  required String apiBaseUrl,
  required bool isDebugMode,
}) {
  switch (backend) {
    case 'sample':
      return const GradusConfig.sample();
    case 'remote':
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw ArgumentError.value(
          apiBaseUrl,
          'GRADUS_API_BASE_URL',
          'must be an absolute URL',
        );
      }
      // plain http is for a backend on this machine, from a debug build only
      return GradusConfig.remote(
        baseUri: uri,
        allowInsecure: isDebugMode && _loopbackHosts.contains(uri.host),
      );
    default:
      // a mistyped define must not quietly run without a backend
      throw ArgumentError.value(
        backend,
        'GRADUS_BACKEND',
        'must be sample or remote',
      );
  }
}

const Set<String> _loopbackHosts = {'localhost', '127.0.0.1', '::1'};
