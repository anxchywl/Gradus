import 'package:flutter_test/flutter_test.dart';
import 'package:gradus_feature/gradus_feature.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Importer implements SyllabusImporter {
  @override
  Future<SyllabusDraft?> importFromFile() async => null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // the standalone host once built these without an importer, which hid
  // syllabus import from every build, whatever backend it named
  test('an importer handed to the local dependencies reaches the feature', () {
    final controller = createLocalDependencies(
      accountId: 'student-a',
      syllabus: _Importer(),
    ).createController();
    addTearDown(controller.dispose);

    expect(controller.canImportSyllabus, isTrue);
  });

  test('without an importer the feature offers no import', () {
    final controller = createLocalDependencies(
      accountId: 'student-a',
    ).createController();
    addTearDown(controller.dispose);

    expect(controller.canImportSyllabus, isFalse);
  });
}
