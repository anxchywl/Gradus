import 'package:flutter/foundation.dart';

import '../domain/assignment.dart';
import '../domain/course.dart';
import '../domain/errors.dart';
import '../domain/gpa.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';
import '../domain/semester.dart';
import '../domain/transcript.dart';

class GpaController extends ChangeNotifier {
  GpaController({
    required TranscriptRepository transcript,
    required GradeScaleRepository scales,
  }) : _repository = transcript,
       _scales = scales;

  final TranscriptRepository _repository;
  final GradeScaleRepository _scales;

  // a load refuses to write its result if this moved under it
  int _generation = 0;

  Transcript _transcript = Transcript.empty;

  // null is the all-semesters view, not an absent selection
  String? _selectedSemesterId;
  GpaResult _semesterResult = GpaResult.empty;
  GpaResult _cumulativeResult = GpaResult.empty;
  GradeScale? _scale;
  bool _isLoading = false;
  Object? _failure;

  List<Semester> get semesters =>
      List.unmodifiable(_transcript.orderedSemesters);

  List<Course> get allCourses => List.unmodifiable(_transcript.courses);

  List<Course> get entries => List.unmodifiable(
    _selectedSemesterId == null
        ? _transcript.courses
        : _transcript.coursesIn(_selectedSemesterId!),
  );

  String? get selectedSemesterId => _selectedSemesterId;

  bool get isAllSemestersSelected => _selectedSemesterId == null;

  Semester? get selectedSemester {
    for (final semester in _transcript.semesters) {
      if (semester.id == _selectedSemesterId) return semester;
    }
    return null;
  }

  GpaResult get semesterResult => _semesterResult;

  GpaResult get cumulativeResult => _cumulativeResult;

  GpaResult get result =>
      _selectedSemesterId == null ? _cumulativeResult : _semesterResult;

  GradeScale? get scale => _scale;
  bool get isLoading => _isLoading;
  Object? get failure => _failure;

  Course? courseById(String id) {
    for (final course in _transcript.courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  List<Course> coursesIn(String semesterId) =>
      List.unmodifiable(_transcript.coursesIn(semesterId));

  bool canRemoveSemester(String id) => _transcript.coursesIn(id).isEmpty;

  Future<void> load() async {
    final generation = ++_generation;
    _isLoading = true;
    _failure = null;
    notifyListeners();

    try {
      final scale = await _scales.active();
      final loaded = await _repository.load();
      if (generation != _generation) return;
      _scale = scale;
      _apply(loaded);
      _selectDefaultSemester();
    } on Exception catch (error) {
      if (generation != _generation) return;
      _failure = error;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void selectSemester(String? id) {
    if (_selectedSemesterId == id) return;
    _selectedSemesterId = id;
    _recompute();
    notifyListeners();
  }

  Future<void> addSemester(Semester semester) async {
    await _mutate(
      _transcript.copyWith(semesters: [..._transcript.semesters, semester]),
    );
    selectSemester(semester.id);
  }

  Future<void> updateSemester(Semester semester) => _mutate(
    _transcript.copyWith(
      semesters: [
        for (final entry in _transcript.semesters)
          if (entry.id == semester.id) semester else entry,
      ],
    ),
  );

  Future<void> removeSemester(String id) async {
    if (!canRemoveSemester(id)) {
      _failure = const SemesterNotEmptyFailure();
      notifyListeners();
      return;
    }
    if (_selectedSemesterId == id) _selectedSemesterId = null;
    await _mutate(
      _transcript.copyWith(
        semesters: [
          for (final entry in _transcript.semesters)
            if (entry.id != id) entry,
        ],
      ),
    );
  }

  Future<void> addCourse(Course course) =>
      _mutate(_transcript.copyWith(courses: [..._transcript.courses, course]));

  Future<void> updateCourse(Course course) => _mutate(
    _transcript.copyWith(
      courses: [
        for (final entry in _transcript.courses)
          if (entry.id == course.id) course else entry,
      ],
    ),
  );

  Future<void> removeCourse(String id) => _mutate(
    _transcript.copyWith(
      courses: [
        for (final entry in _transcript.courses)
          if (entry.id != id) entry,
      ],
    ),
  );

  Future<void> addAssignment(Assignment assignment) {
    final course = courseById(assignment.courseId);
    if (course == null) return Future<void>.value();
    return updateCourse(
      course.copyWith(assignments: [...course.assignments, assignment]),
    );
  }

  Future<void> updateAssignment(Assignment assignment) {
    final course = courseById(assignment.courseId);
    if (course == null) return Future<void>.value();
    return updateCourse(
      course.copyWith(
        assignments: [
          for (final entry in course.assignments)
            if (entry.id == assignment.id) assignment else entry,
        ],
      ),
    );
  }

  Future<void> removeAssignment(String courseId, String assignmentId) {
    final course = courseById(courseId);
    if (course == null) return Future<void>.value();
    return updateCourse(
      course.copyWith(
        assignments: [
          for (final entry in course.assignments)
            if (entry.id != assignmentId) entry,
        ],
      ),
    );
  }

  void reset() {
    _generation++;
    _transcript = Transcript.empty;
    _selectedSemesterId = null;
    _semesterResult = GpaResult.empty;
    _cumulativeResult = GpaResult.empty;
    _failure = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // a request still in flight must not notify a controller with no listeners
    _generation++;
    super.dispose();
  }

  Future<void> _mutate(Transcript next) async {
    final generation = _generation;
    final previous = _transcript;
    // the average updates before the write lands, so the list never lags a tap
    _apply(next);
    notifyListeners();
    try {
      await _repository.save(next);
    } on Exception catch (error) {
      if (generation != _generation) return;
      // the write failed, so what is on screen was never true
      _apply(previous);
      _failure = error;
      notifyListeners();
    }
  }

  void _apply(Transcript transcript) {
    _transcript = transcript;
    _recompute();
  }

  void _recompute() {
    final scale = _scale;
    if (scale == null) {
      _semesterResult = GpaResult.empty;
      _cumulativeResult = GpaResult.empty;
      return;
    }
    _cumulativeResult = calculateGpa(_transcript.courses, scale);
    final selected = _selectedSemesterId;
    _semesterResult = selected == null
        ? GpaResult.empty
        : calculateGpa(_transcript.coursesIn(selected), scale);
  }

  void _selectDefaultSemester() {
    if (_selectedSemesterId != null) return;
    final ordered = _transcript.orderedSemesters;
    if (ordered.isEmpty) return;
    _selectedSemesterId = ordered.first.id;
    _recompute();
  }
}
