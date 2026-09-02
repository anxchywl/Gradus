import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';

void main() {
  group('GradusSession', () {
    test('an empty token is not a session', () {
      expect(
        const GradusSession(accessToken: '', accountId: 'student-1').isPresent,
        isFalse,
      );
      expect(
        const GradusSession(
          accessToken: 'a-token',
          accountId: 'student-1',
        ).isPresent,
        isTrue,
      );
    });
  });

  group('GradusConfig', () {
    test('a sample build records that it is not remote', () {
      expect(const GradusConfig.sample().backend, GradusBackend.sample);
      expect(const GradusConfig.sample().baseUri, isNull);
    });

    test('a remote build refuses plain HTTP', () {
      expect(
        () => GradusConfig.remote(baseUri: Uri.parse('http://gpa.example.edu')),
        throwsArgumentError,
      );
    });

    test('a remote build accepts HTTPS', () {
      final config = GradusConfig.remote(
        baseUri: Uri.parse('https://gpa.example.edu'),
      );
      expect(config.backend, GradusBackend.remote);
    });

    test('only an explicit opt-in allows insecure transport', () {
      final config = GradusConfig.remote(
        baseUri: Uri.parse('http://127.0.0.1:8000'),
        allowInsecure: true,
      );
      expect(config.baseUri!.scheme, 'http');
    });
  });
}
