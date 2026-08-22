import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/course.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';

/// Stores the student's own courses on their own device.
///
/// Keys carry the schema version and the account, so a layout change discards
/// old entries instead of misreading them, and one student's courses never
/// surface for another.
class PreferencesCourseRepository implements CourseRepository {
  PreferencesCourseRepository({
    required this.accountId,
    required GradeScale scale,
    SharedPreferences? preferences,
  }) : _scale = scale,
       _preferences = preferences;

  static const String _schema = 'gpa_v1';

  final String accountId;
  final GradeScale _scale;
  SharedPreferences? _preferences;

  String get _key => '${_schema}_${accountId}_courses';

  Future<SharedPreferences> _store() async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<List<Course>> load() async {
    final raw = (await _store()).getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    final courses = <Course>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final course = _courseFrom(entry);
      // a single unreadable entry must not lose the rest of the transcript
      if (course != null) courses.add(course);
    }
    return courses;
  }

  @override
  Future<void> save(List<Course> courses) async {
    final payload = courses.map(_jsonFrom).toList();
    await (await _store()).setString(_key, jsonEncode(payload));
  }

  Map<String, dynamic> _jsonFrom(Course course) => {
    'id': course.id,
    'title': course.title,
    'credits': course.credits,
    'grade': course.grade?.letter,
  };

  Course? _courseFrom(Map<String, dynamic> entry) {
    final id = entry['id'];
    final title = entry['title'];
    final credits = entry['credits'];
    if (id is! String || title is! String || credits is! num) return null;

    final letter = entry['grade'];
    Grade? grade;
    if (letter is String) {
      try {
        grade = _scale.byLetter(letter);
      } on Exception {
        // the scale changed under a stored grade; keep the course, drop the grade
        grade = null;
      }
    }

    try {
      return Course(
        id: id,
        title: title,
        credits: credits.toDouble(),
        grade: grade,
      );
    } on Exception {
      return null;
    }
  }
}
