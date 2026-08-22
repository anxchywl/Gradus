import 'package:flutter/foundation.dart';

/// Whether this build may open the feature without a real host session.
///
/// Default deny. A debug build opts in; a release build additionally requires
/// an explicit define that no shipped build ever passes.
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

/// Which data source this build was assembled with.
const String configuredBackend = String.fromEnvironment(
  'GPA_BACKEND',
  defaultValue: 'sample',
);

const String configuredApiBaseUrl = String.fromEnvironment('GPA_API_BASE_URL');

/// Development session tokens.
///
/// There is no default. A token is a bearer credential to the development
/// backend, so it is supplied from outside source control or the standalone
/// host simply does not open. Never passed to a build that leaves this machine.
const String developmentUserToken = String.fromEnvironment('GPA_ACCESS_TOKEN');

const String developmentOperatorToken = String.fromEnvironment(
  'GPA_OPERATOR_ACCESS_TOKEN',
);

/// The two development identities the standalone host can hold.
///
/// Switching between them re-creates the account scope. The client never claims
/// a role: it sends a different token and the backend resolves what that token
/// is allowed to do.
enum DevelopmentRole { student, operator }

String tokenFor(DevelopmentRole role) => switch (role) {
  DevelopmentRole.student => developmentUserToken,
  DevelopmentRole.operator => developmentOperatorToken,
};
