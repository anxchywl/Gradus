import '../domain/grade.dart';
import '../domain/repositories.dart';
import '../domain/transcript.dart';

// never the default in a build that leaves a development machine
class InMemoryTranscriptRepository implements TranscriptRepository {
  InMemoryTranscriptRepository([Transcript? seed])
    : _transcript = seed ?? Transcript.empty;

  Transcript _transcript;

  @override
  Future<Transcript> load() async => _transcript;

  @override
  Future<void> save(Transcript transcript) async => _transcript = transcript;
}

class StaticGradeScaleRepository implements GradeScaleRepository {
  const StaticGradeScaleRepository([this._scale = const FourPointScale()]);

  final GradeScale _scale;

  @override
  Future<GradeScale> active() async => _scale;
}
