// the feature never parses, refreshes, persists or judges this token
class GradusSession {
  const GradusSession({required this.accessToken, required this.accountId});

  final String accessToken;

  // storage keys use this, never the token, which must not reach disk
  final String accountId;

  bool get isPresent => accessToken.isNotEmpty && accountId.isNotEmpty;
}

enum GradusBackend { sample, remote }

class GradusConfig {
  const GradusConfig({required this.backend, this.baseUri});

  const GradusConfig.sample() : backend = GradusBackend.sample, baseUri = null;

  // only the standalone debug host may opt out of https, and it says so
  GradusConfig.remote({required Uri this.baseUri, bool allowInsecure = false})
    : backend = GradusBackend.remote {
    if (!allowInsecure && baseUri!.scheme != 'https') {
      throw ArgumentError.value(baseUri, 'baseUri', 'must use HTTPS');
    }
  }

  final GradusBackend backend;
  final Uri? baseUri;
}
