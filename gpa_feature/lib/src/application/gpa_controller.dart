import 'package:flutter/foundation.dart';

import '../domain/course.dart';
import '../domain/gpa.dart';
import '../domain/repositories.dart';

/// Owns the working set of courses and the derived average.
///
/// Depends on the repository interface only; the implementation is chosen once,
/// in [GpaScope].
class GpaController extends ChangeNotifier {
  GpaController({required CourseRepository courses}) : _courses = courses;

  final CourseRepository _courses;

  /// A load captures this and refuses to write its result if it moved, so a
  /// response that was already in flight when the account changed is discarded.
  int _generation = 0;

  List<Course> _entries = const [];
  GpaResult _result = GpaResult.empty;
  bool _isLoading = false;
  Object? _failure;

  List<Course> get entries => List.unmodifiable(_entries);
  GpaResult get result => _result;
  bool get isLoading => _isLoading;
  Object? get failure => _failure;

  Future<void> load() async {
    final generation = ++_generation;
    _isLoading = true;
    _failure = null;
    notifyListeners();

    try {
      final loaded = await _courses.load();
      if (generation != _generation) return;
      _entries = loaded;
      _result = calculateGpa(loaded);
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

  /// Discards everything belonging to the previous account.
  void reset() {
    _generation++;
    _entries = const [];
    _result = GpaResult.empty;
    _failure = null;
    _isLoading = false;
    notifyListeners();
  }
}
