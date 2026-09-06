import 'grade.dart';
import 'syllabus.dart';
import 'transcript.dart';

// implemented under data, a boundary test stops anything above naming it
abstract interface class TranscriptRepository {
  Future<Transcript> load();

  Future<void> save(Transcript transcript);
}

abstract interface class GradeScaleRepository {
  Future<GradeScale> active();
}

// picking the file and reading it are one step to the domain, which learns
// neither where the file came from nor what reads it
abstract interface class SyllabusImporter {
  // null when the student cancels the picker, which is not a failure
  Future<SyllabusDraft?> importFromFile();
}
