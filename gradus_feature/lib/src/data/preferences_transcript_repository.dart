import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/assignment.dart';
import '../domain/course.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';
import '../domain/semester.dart';
import '../domain/transcript.dart';

// keys carry schema and account, so a layout change discards old entries
class PreferencesTranscriptRepository implements TranscriptRepository {
  PreferencesTranscriptRepository({
    required this.accountId,
    required GradeScale scale,
    this.anonymousAccountId,
    SharedPreferences? preferences,
  }) : _scale = scale,
       _preferences = preferences;

  // renaming this prefix would discard every stored transcript
  static const String _schema = 'gpa_v2';

  // read once to carry a pre-semester transcript forward, never written
  static const String _legacySchema = 'gpa_v1';

  // deliberately unnamed, the old store recorded no term to name
  static const String migratedSemesterId = 'semester_migrated';

  final String accountId;

  // the id a host uses before it knows who the student is; null when the host
  // has always known, which is every account after the first adoption
  final String? anonymousAccountId;

  final GradeScale _scale;
  SharedPreferences? _preferences;

  String get _key => '${_schema}_${accountId}_transcript';

  String get _legacyKey => '${_legacySchema}_${accountId}_courses';

  String get _anonymousKey => '${_schema}_${anonymousAccountId}_transcript';

  // written on the anonymous account, not the adopting one, so the claim is
  // visible to every other account that looks
  String get _adoptionKey => '${_schema}_${anonymousAccountId}_adopted';

  Future<SharedPreferences> _store() async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<Transcript> load() async {
    final store = await _store();
    final raw = store.getString(_key);
    if (raw == null || raw.isEmpty) {
      return await _adopted(store) ?? await _migrated(store);
    }
    return _transcriptFrom(raw);
  }

  Transcript _transcriptFrom(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return Transcript.empty;

    final semesters = <Semester>[];
    final rawSemesters = decoded['semesters'];
    if (rawSemesters is List) {
      for (final entry in rawSemesters) {
        if (entry is! Map<String, dynamic>) continue;
        final semester = _semesterFrom(entry);
        if (semester != null) semesters.add(semester);
      }
    }

    final known = {for (final semester in semesters) semester.id};
    final courses = <Course>[];
    final rawCourses = decoded['courses'];
    if (rawCourses is List) {
      for (final entry in rawCourses) {
        if (entry is! Map<String, dynamic>) continue;
        final course = _courseFrom(entry);
        // a single unreadable entry must not lose the rest of the transcript
        if (course == null) continue;
        // a course whose term is gone would be invisible in every view
        if (!known.contains(course.semesterId)) continue;
        courses.add(course);
      }
    }

    return Transcript(semesters: semesters, courses: courses);
  }

  @override
  Future<void> save(Transcript transcript) async {
    // one key, one write: the whole transcript lands or none of it does
    await (await _store()).setString(
      _key,
      jsonEncode({
        'semesters': transcript.semesters.map(_jsonFromSemester).toList(),
        'courses': transcript.courses.map(_jsonFromCourse).toList(),
      }),
    );
  }

  // a transcript written before the host knew who the student was belongs to
  // the first account that arrives. the anonymous copy is left where it is,
  // like the pre-semester layout, but the marker stops a second account
  // inheriting a stranger's courses off a shared device
  Future<Transcript?> _adopted(SharedPreferences store) async {
    final anonymous = anonymousAccountId;
    if (anonymous == null || anonymous == accountId) return null;
    if (store.getString(_adoptionKey) != null) return null;

    final raw = store.getString(_anonymousKey);
    if (raw == null || raw.isEmpty) return null;

    final transcript = _transcriptFrom(raw);
    // nothing to claim, and claiming it would spend the one adoption there is
    if (transcript.semesters.isEmpty && transcript.courses.isEmpty) return null;

    await save(transcript);
    await store.setString(_adoptionKey, accountId);
    return transcript;
  }

  // the old key is left alone, so a downgrade still has what it had
  Future<Transcript> _migrated(SharedPreferences store) async {
    final raw = store.getString(_legacyKey);
    if (raw == null || raw.isEmpty) return Transcript.empty;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return Transcript.empty;

    final courses = <Course>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['id'];
      final title = entry['title'];
      final credits = entry['credits'];
      if (id is! String || title is! String || credits is! num) continue;
      try {
        courses.add(
          Course(
            id: id,
            semesterId: migratedSemesterId,
            title: title,
            credits: credits.toDouble(),
            grade: _gradeFrom(entry['grade']),
          ),
        );
      } on Exception {
        continue;
      }
    }

    if (courses.isEmpty) return Transcript.empty;

    final transcript = Transcript(
      semesters: [Semester(id: migratedSemesterId, name: '')],
      courses: courses,
    );
    await save(transcript);
    return transcript;
  }

  Map<String, dynamic> _jsonFromSemester(Semester semester) => {
    'id': semester.id,
    'name': semester.name,
    'position': semester.position,
  };

  Map<String, dynamic> _jsonFromCourse(Course course) => {
    'id': course.id,
    'semesterId': course.semesterId,
    'code': course.code,
    'title': course.title,
    'credits': course.credits,
    'grade': course.grade?.letter,
    'assignments': course.assignments.map(_jsonFromAssignment).toList(),
  };

  Map<String, dynamic> _jsonFromAssignment(Assignment assignment) => {
    'id': assignment.id,
    'courseId': assignment.courseId,
    'name': assignment.name,
    'weight': assignment.weight,
    'maximumScore': assignment.maximumScore,
    'earnedScore': assignment.earnedScore,
  };

  Semester? _semesterFrom(Map<String, dynamic> entry) {
    final id = entry['id'];
    final name = entry['name'];
    if (id is! String || name is! String) return null;
    final position = entry['position'];
    try {
      return Semester(
        id: id,
        name: name,
        position: position is num ? position.toInt() : 0,
      );
    } on Exception {
      return null;
    }
  }

  Course? _courseFrom(Map<String, dynamic> entry) {
    final id = entry['id'];
    final semesterId = entry['semesterId'];
    final title = entry['title'];
    final credits = entry['credits'];
    if (id is! String ||
        semesterId is! String ||
        title is! String ||
        credits is! num) {
      return null;
    }

    final assignments = <Assignment>[];
    final rawAssignments = entry['assignments'];
    if (rawAssignments is List) {
      for (final raw in rawAssignments) {
        if (raw is! Map<String, dynamic>) continue;
        final assignment = _assignmentFrom(raw, id);
        if (assignment != null) assignments.add(assignment);
      }
    }

    final code = entry['code'];

    try {
      return Course(
        id: id,
        semesterId: semesterId,
        code: code is String ? code : '',
        title: title,
        credits: credits.toDouble(),
        grade: _gradeFrom(entry['grade']),
        assignments: assignments,
      );
    } on Exception {
      return null;
    }
  }

  Assignment? _assignmentFrom(Map<String, dynamic> entry, String courseId) {
    final id = entry['id'];
    final name = entry['name'];
    final weight = entry['weight'];
    final maximumScore = entry['maximumScore'];
    if (id is! String ||
        name is! String ||
        weight is! num ||
        maximumScore is! num) {
      return null;
    }

    final earned = entry['earnedScore'];
    try {
      return Assignment(
        id: id,
        // the stored owner is ignored so a hand-edited file cannot move work
        courseId: courseId,
        name: name,
        weight: weight.toDouble(),
        maximumScore: maximumScore.toDouble(),
        earnedScore: earned is num ? earned.toDouble() : null,
      );
    } on Exception {
      return null;
    }
  }

  Grade? _gradeFrom(Object? letter) {
    if (letter is! String) return null;
    try {
      return _scale.byLetter(letter);
    } on Exception {
      // the scale changed under a stored grade; keep the course, drop the grade
      return null;
    }
  }
}
