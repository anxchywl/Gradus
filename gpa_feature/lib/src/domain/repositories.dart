import 'grade.dart';
import 'transcript.dart';

// implemented under data, a boundary test stops anything above naming it
abstract interface class TranscriptRepository {
  Future<Transcript> load();

  Future<void> save(Transcript transcript);
}

abstract interface class GradeScaleRepository {
  Future<GradeScale> active();
}
