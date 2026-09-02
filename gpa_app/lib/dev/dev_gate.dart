import 'package:flutter/foundation.dart';

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
  'GPA_BACKEND',
  defaultValue: 'sample',
);

const String configuredApiBaseUrl = String.fromEnvironment('GPA_API_BASE_URL');

// no default, a token is a bearer credential and never leaves this machine
const String developmentUserToken = String.fromEnvironment('GPA_ACCESS_TOKEN');

const String developmentOperatorToken = String.fromEnvironment(
  'GPA_OPERATOR_ACCESS_TOKEN',
);

// the client never claims a role, the backend resolves what the token allows
enum DevelopmentRole { student, operator }

String tokenFor(DevelopmentRole role) => switch (role) {
  DevelopmentRole.student => developmentUserToken,
  DevelopmentRole.operator => developmentOperatorToken,
};
