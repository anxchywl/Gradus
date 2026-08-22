import 'package:flutter_test/flutter_test.dart';
import 'package:gpa_app/dev/dev_gate.dart';

void main() {
  group('developmentAccessAllowed', () {
    test('a release build with no defines is closed', () {
      expect(
        developmentAccessAllowed(isDebugMode: false, requested: false),
        isFalse,
      );
    });

    test('requesting access is not enough in a release build', () {
      expect(
        developmentAccessAllowed(isDebugMode: false, requested: true),
        isFalse,
      );
    });

    test('a release build opens only with the explicit second define', () {
      expect(
        developmentAccessAllowed(
          isDebugMode: false,
          requested: true,
          allowReleaseAccess: true,
        ),
        isTrue,
      );
    });

    test('a debug build still has to ask', () {
      expect(
        developmentAccessAllowed(isDebugMode: true, requested: false),
        isFalse,
      );
    });

    test('a debug build that asks is allowed', () {
      expect(
        developmentAccessAllowed(isDebugMode: true, requested: true),
        isTrue,
      );
    });
  });

  test('no development token is compiled in by default', () {
    // a token baked into a distributed binary is not a secret; there is no
    // default so a build that forgets to supply one simply does not open
    expect(developmentUserToken, isEmpty);
    expect(developmentOperatorToken, isEmpty);
  });
}
