import 'package:flutter/foundation.dart';

import '../domain/course.dart';
import '../domain/gpa.dart';
import '../domain/grade.dart';
import '../domain/repositories.dart';

/// Owns the working set of courses and the derived average.
///
/// Depends on the repository interfaces only; the implementations are chosen
/// once, in [GpaScope].
class GpaController extends ChangeNotifier {
  GpaController({
    required CourseRepository courses,
    required GradeScaleRepository scales,
  }) : _courses = courses,
       _scales = scales;

  final CourseRepository _courses;
  final GradeScaleRepository _scales;

  /// A load captures this and refuses to write its result if it moved, so a
  /// response that was already in flight when the account changed is discarded.
  int _generation = 0;

  List<Course> _entries = const [];
  GpaResult _result = GpaResult.empty;
  GradeScale? _scale;
  bool _isLoading = false;
  Object? _failure;

  List<Course> get entries => List.unmodifiable(_entries);
  GpaResult get result => _result;
  GradeScale? get scale => _scale;
  bool get isLoading => _isLoading;
  Object? get failure => _failure;

  Future<void> load() async {
    final generation = ++_generation;
    _isLoading = true;
    _failure = null;
    notifyListeners();

    try {
      final scale = await _scales.active();
      final loaded = await _courses.load();
      if (generation != _generation) return;
      _scale = scale;
      _apply(loaded);
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

  Future<void> add(Course course) => _mutate([..._entries, course]);

  Future<void> update(Course course) => _mutate([
    for (final entry in _entries)
      if (entry.id == course.id) course else entry,
  ]);

  Future<void> remove(String id) => _mutate([
    for (final entry in _entries)
      if (entry.id != id) entry,
  ]);

  /// Discards everything belonging to the previous account.
  void reset() {
    _generation++;
    _entries = const [];
    _result = GpaResult.empty;
    _failure = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _mutate(List<Course> next) async {
    final generation = _generation;
    final previous = _entries;
    // the average updates before the write lands, so the list never lags a tap
    _apply(next);
    notifyListeners();
    try {
      await _courses.save(next);
    } on Exception catch (error) {
      if (generation != _generation) return;
      // the write failed, so what is on screen was never true
      _apply(previous);
      _failure = error;
      notifyListeners();
    }
  }

  void _apply(List<Course> courses) {
    _entries = courses;
    _result = calculateGpa(courses);
  }
}
