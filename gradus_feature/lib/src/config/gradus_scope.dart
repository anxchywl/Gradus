import 'package:flutter/widgets.dart';

import '../application/gradus_controller.dart';
import '../data/in_memory_transcript_repository.dart';
import '../data/preferences_transcript_repository.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';
import '../data/http_syllabus_importer.dart';
import 'gradus_session.dart';

class GradusDependencies {
  const GradusDependencies({
    required this.transcript,
    required this.scales,
    this.syllabus,
  });

  final TranscriptRepository transcript;
  final GradeScaleRepository scales;
  final SyllabusImporter? syllabus;

  GradusController createController() => GradusController(
    transcript: transcript,
    scales: scales,
    syllabus: syllabus,
  );
}

// the token never reaches disk, so the importer is rebuilt with the session
SyllabusImporter createSyllabusImporter({
  required Uri baseUri,
  required String accessToken,
}) => HttpSyllabusImporter(baseUri: baseUri, accessToken: accessToken);

GradusDependencies createSampleDependencies() => GradusDependencies(
  transcript: InMemoryTranscriptRepository(),
  scales: const StaticGradeScaleRepository(),
);

GradusDependencies createLocalDependencies({
  required String accountId,
  GradeScale scale = const FourPointScale(),
  SyllabusImporter? syllabus,
}) => GradusDependencies(
  transcript: PreferencesTranscriptRepository(
    accountId: accountId,
    scale: scale,
  ),
  scales: StaticGradeScaleRepository(scale),
  syllabus: syllabus,
);

// the controller is owned by GradusFeature, so a rebuild above cannot swap it
class GradusScope extends InheritedWidget {
  const GradusScope({
    super.key,
    required this.session,
    required this.controller,
    required super.child,
  });

  final GradusSession session;
  final GradusController controller;

  static GradusScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GradusScope>();
    assert(scope != null, 'GradusScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(GradusScope oldWidget) =>
      oldWidget.session.accessToken != session.accessToken ||
      oldWidget.controller != controller;
}
