import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_app/dev/dev_gate.dart';
import 'package:gradus_feature/gradus_feature.dart';

void main() {
  group('resolveHostConfig', () {
    test('sample names no backend, so nothing leaves the device', () {
      final config = resolveHostConfig(
        backend: 'sample',
        apiBaseUrl: '',
        isDebugMode: false,
      );
      expect(config.backend, GradusBackend.sample);
      expect(config.baseUri, isNull);
    });

    test('a remote backend over https is accepted from any build', () {
      final config = resolveHostConfig(
        backend: 'remote',
        apiBaseUrl: 'https://gradus.example',
        isDebugMode: false,
      );
      expect(config.backend, GradusBackend.remote);
      expect(config.baseUri, Uri.parse('https://gradus.example'));
    });

    test('plain http reaches a backend on this machine from a debug build', () {
      for (final url in const [
        'http://localhost:8000',
        'http://127.0.0.1:8000',
        'http://[::1]:8000',
      ]) {
        final config = resolveHostConfig(
          backend: 'remote',
          apiBaseUrl: url,
          isDebugMode: true,
        );
        expect(config.baseUri, Uri.parse(url));
      }
    });

    test(
      'plain http is refused from a release build, even to this machine',
      () {
        expect(
          () => resolveHostConfig(
            backend: 'remote',
            apiBaseUrl: 'http://localhost:8000',
            isDebugMode: false,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'plain http to another machine is refused even from a debug build',
      () {
        expect(
          () => resolveHostConfig(
            backend: 'remote',
            apiBaseUrl: 'http://192.168.1.20:8000',
            isDebugMode: true,
          ),
          throwsArgumentError,
        );
      },
    );

    test('a remote backend needs an absolute url', () {
      for (final url in const ['', 'gradus.example', '/api']) {
        expect(
          () => resolveHostConfig(
            backend: 'remote',
            apiBaseUrl: url,
            isDebugMode: true,
          ),
          throwsArgumentError,
        );
      }
    });

    test('a mistyped backend is refused rather than read as sample', () {
      expect(
        () => resolveHostConfig(
          backend: 'Remote',
          apiBaseUrl: 'https://gradus.example',
          isDebugMode: true,
        ),
        throwsArgumentError,
      );
    });
  });

  test('a build with no defines names no backend', () {
    expect(configuredBackend, 'sample');
    expect(configuredApiBaseUrl, isEmpty);
  });
}
