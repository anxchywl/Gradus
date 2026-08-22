import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_feature/gpa_feature.dart';

void main() {
  group('GpaSession', () {
    test('an empty token is not a session', () {
      expect(const GpaSession(accessToken: '').isPresent, isFalse);
      expect(const GpaSession(accessToken: 'a-token').isPresent, isTrue);
    });
  });

  group('GpaConfig', () {
    test('a sample build records that it is not remote', () {
      expect(const GpaConfig.sample().backend, GpaBackend.sample);
      expect(const GpaConfig.sample().baseUri, isNull);
    });

    test('a remote build refuses plain HTTP', () {
      expect(
        () => GpaConfig.remote(baseUri: Uri.parse('http://gpa.example.edu')),
        throwsArgumentError,
      );
    });

    test('a remote build accepts HTTPS', () {
      final config = GpaConfig.remote(
        baseUri: Uri.parse('https://gpa.example.edu'),
      );
      expect(config.backend, GpaBackend.remote);
    });

    test('only an explicit opt-in allows insecure transport', () {
      final config = GpaConfig.remote(
        baseUri: Uri.parse('http://127.0.0.1:8000'),
        allowInsecure: true,
      );
      expect(config.baseUri!.scheme, 'http');
    });
  });
}
