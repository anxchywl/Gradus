import 'assignment.dart';
import 'course.dart';

// what a syllabus offered, before the student has agreed to any of it
class SyllabusDraft {
  const SyllabusDraft({
    this.code,
    this.title,
    this.credits,
    this.creditUnit,
    this.term,
    this.assessments = const [],
  });

  final String? code;
  final String? title;
  final double? credits;

  // ects in every syllabus seen so far, and never converted for the student
  final String? creditUnit;
  final String? term;
  final List<SyllabusAssessment> assessments;

  bool get isEmpty =>
      code == null &&
      title == null &&
      credits == null &&
      term == null &&
      assessments.isEmpty;

  double get totalWeight =>
      assessments.fold(0, (total, entry) => total + entry.weight);
}

class SyllabusAssessment {
  const SyllabusAssessment({required this.name, required this.weight});

  final String name;
  final double weight;
}

// the response is untrusted the same way the document was: the server sanitises
// what it returns, and the client does not take that on trust
String? sanitizeImported(String? value, {required int limit}) {
  if (value == null) return null;
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (_isStripped(rune)) continue;
    buffer.writeCharCode(rune);
  }
  final collapsed = buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.isEmpty) return null;
  return collapsed.length <= limit ? collapsed : collapsed.substring(0, limit);
}

bool _isStripped(int rune) {
  // c0 and c1 controls, apart from the whitespace that collapses away below
  if (rune < 0x20 && rune != 0x09 && rune != 0x0a && rune != 0x0d) return true;
  if (rune >= 0x7f && rune <= 0x9f) return true;
  // zero width, bidi marks, embeddings, overrides and isolates
  if (rune >= 0x200b && rune <= 0x200f) return true;
  if (rune >= 0x202a && rune <= 0x202e) return true;
  if (rune >= 0x2066 && rune <= 0x2069) return true;
  return rune == 0xfeff;
}

double? sanitizeWeight(double? value) {
  if (value == null || !value.isFinite) return null;
  if (value <= 0 || value > Assignment.maximumWeight) return null;
  return value;
}

double? sanitizeCredits(double? value) {
  if (value == null || !value.isFinite) return null;
  if (value <= 0 || value > Course.maximumCredits) return null;
  return value;
}
