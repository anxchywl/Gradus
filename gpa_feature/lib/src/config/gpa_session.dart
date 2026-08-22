/// What the host supplies so the feature can act on a student's behalf.
///
/// The feature does not parse this token, does not refresh it, does not persist
/// it, and does not decide whether the holder is a student or an operator. All
/// of that comes back from whatever resolved the session.
class GpaSession {
  const GpaSession({required this.accessToken, required this.accountId});

  final String accessToken;

  /// A stable identifier for the student, supplied by the host alongside the
  /// token. Storage keys are namespaced with this rather than with the token,
  /// because a token must never be written to disk, not even as a key.
  final String accountId;

  bool get isPresent => accessToken.isNotEmpty && accountId.isNotEmpty;
}

/// Which data source this build was assembled with.
enum GpaBackend { sample, remote }

class GpaConfig {
  const GpaConfig({required this.backend, this.baseUri});

  const GpaConfig.sample() : backend = GpaBackend.sample, baseUri = null;

  /// Remote configuration requires HTTPS. The standalone debug host is the only
  /// caller that may opt into plain HTTP, and it does so explicitly.
  GpaConfig.remote({required Uri this.baseUri, bool allowInsecure = false})
    : backend = GpaBackend.remote {
    if (!allowInsecure && baseUri!.scheme != 'https') {
      throw ArgumentError.value(baseUri, 'baseUri', 'must use HTTPS');
    }
  }

  final GpaBackend backend;
  final Uri? baseUri;
}
