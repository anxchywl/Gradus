import 'package:flutter/widgets.dart';

import '../application/gpa_controller.dart';
import '../data/in_memory_transcript_repository.dart';
import '../data/preferences_transcript_repository.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';
import 'gpa_session.dart';

class GpaDependencies {
  const GpaDependencies({required this.transcript, required this.scales});

  final TranscriptRepository transcript;
  final GradeScaleRepository scales;

  GpaController createController() =>
      GpaController(transcript: transcript, scales: scales);
}

GpaDependencies createSampleDependencies() => GpaDependencies(
  transcript: InMemoryTranscriptRepository(),
  scales: const StaticGradeScaleRepository(),
);

GpaDependencies createLocalDependencies({
  required String accountId,
  GradeScale scale = const FourPointScale(),
}) => GpaDependencies(
  transcript: PreferencesTranscriptRepository(
    accountId: accountId,
    scale: scale,
  ),
  scales: StaticGradeScaleRepository(scale),
);

// the controller is owned by GpaFeature, so a rebuild above cannot swap it
class GpaScope extends InheritedWidget {
  const GpaScope({
    super.key,
    required this.session,
    required this.gpa,
    required super.child,
  });

  final GpaSession session;
  final GpaController gpa;

  static GpaScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GpaScope>();
    assert(scope != null, 'GpaScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(GpaScope oldWidget) =>
      oldWidget.session.accessToken != session.accessToken ||
      oldWidget.gpa != gpa;
}
