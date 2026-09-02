import 'errors.dart';

class Semester {
  Semester({required this.id, required this.name, this.position = 0}) {
    if (id.isEmpty) {
      throw const InvalidSemesterFailure('semester_id_empty');
    }
  }

  final String id;

  // blank for courses carried over from a store that predates semesters
  final String name;

  // higher sorts first, so the newest term is the one a student lands on
  final int position;

  bool get hasName => name.trim().isNotEmpty;

  Semester copyWith({String? name, int? position}) => Semester(
    id: id,
    name: name ?? this.name,
    position: position ?? this.position,
  );
}
