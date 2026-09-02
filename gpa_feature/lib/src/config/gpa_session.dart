// the feature never parses, refreshes, persists or judges this token
class GpaSession {
  const GpaSession({required this.accessToken, required this.accountId});

  final String accessToken;

  // storage keys use this, never the token, which must not reach disk
  final String accountId;

  bool get isPresent => accessToken.isNotEmpty && accountId.isNotEmpty;
}

enum GpaBackend { sample, remote }

class GpaConfig {
  const GpaConfig({required this.backend, this.baseUri});

  const GpaConfig.sample() : backend = GpaBackend.sample, baseUri = null;

  // only the standalone debug host may opt out of https, and it says so
  GpaConfig.remote({required Uri this.baseUri, bool allowInsecure = false})
    : backend = GpaBackend.remote {
    if (!allowInsecure && baseUri!.scheme != 'https') {
      throw ArgumentError.value(baseUri, 'baseUri', 'must use HTTPS');
    }
  }

  final GpaBackend backend;
  final Uri? baseUri;
}
