import 'package:flutter/foundation.dart';

import '../core/enums/api_state_enum.dart';
import '../models/course_model.dart';
import '../repositories/course_repository.dart';

/// State-management layer for courses.
///
/// Architecture: UI → [CourseController] → [CourseRepository] → API / Hive
class CourseController extends ChangeNotifier {
  CourseController({CourseRepository? repository})
      : _repository = repository ?? CourseRepository();

  final CourseRepository _repository;

  // ─── State ────────────────────────────────────────────────────────────────
  ApiState _listState = ApiState.initial;
  ApiState _mutationState = ApiState.initial;
  List<CourseModel> _courses = [];
  String? _errorMessage;
  bool _isFromCache = false;
  bool _isOffline = false;

  // ─── Getters ──────────────────────────────────────────────────────────────
  ApiState get listState => _listState;
  ApiState get mutationState => _mutationState;
  List<CourseModel> get courses => List.unmodifiable(_courses);
  String? get errorMessage => _errorMessage;
  bool get isListLoading => _listState.isLoading;
  bool get isMutating => _mutationState.isLoading;
  bool get isFromCache => _isFromCache;
  bool get isOffline => _isOffline;

  List<CourseModel> filteredCourses(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return courses;

    return _courses.where((course) {
      return course.title.toLowerCase().contains(trimmed) ||
          course.body.toLowerCase().contains(trimmed) ||
          course.id.toString().contains(trimmed);
    }).toList();
  }

  // ─── READ ─────────────────────────────────────────────────────────────────

  Future<void> fetchCourses({int limit = 20}) async {
    _listState = ApiState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.fetchCourses(limit: limit);
      _courses = result.courses;
      _isFromCache = result.isFromCache;
      _isOffline = result.isOffline;
      _listState =
          _courses.isEmpty ? ApiState.empty : ApiState.success;
    } on OfflineCacheException catch (e) {
      _listState = ApiState.error;
      _isOffline = true;
      _errorMessage = e.message;
    } catch (e) {
      _listState = ApiState.error;
      _errorMessage = _friendlyError(e);
    }
    notifyListeners();
  }

  // ─── CREATE ───────────────────────────────────────────────────────────────

  Future<bool> createCourse({
    required String title,
    required String description,
  }) async {
    _mutationState = ApiState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final localId = _nextLocalId();
      final created = await _repository.createCourse(
        title: title.trim(),
        description: description.trim(),
        localId: localId,
      );

      _courses.insert(0, created);
      if (_listState.isEmpty) _listState = ApiState.success;

      _mutationState = ApiState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _mutationState = ApiState.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── UPDATE (optimistic) ──────────────────────────────────────────────────

  Future<bool> updateCourse(CourseModel updated) async {
    final index = _courses.indexWhere((c) => c.id == updated.id);
    if (index == -1) return false;

    final previous = _courses[index];
    _courses[index] = updated;
    _mutationState = ApiState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.updateCourse(updated);
      _courses[index] = result;
      _mutationState = ApiState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _courses[index] = previous;
      await _repository.restoreCourseAt(previous);
      _mutationState = ApiState.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── DELETE (optimistic) ──────────────────────────────────────────────────

  Future<bool> deleteCourse(int id) async {
    final index = _courses.indexWhere((c) => c.id == id);
    if (index == -1) return false;

    final removed = _courses[index];
    _courses.removeAt(index);
    if (_courses.isEmpty) _listState = ApiState.empty;
    _mutationState = ApiState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteCourse(id);
      _mutationState = ApiState.success;
      notifyListeners();
      return true;
    } catch (e) {
      _courses.insert(index, removed);
      if (_listState.isEmpty) _listState = ApiState.success;
      await _repository.restoreCourse(removed);
      _mutationState = ApiState.error;
      _errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void clearMutationState() {
    _mutationState = ApiState.initial;
    _errorMessage = null;
    notifyListeners();
  }

  int _nextLocalId() {
    if (_courses.isEmpty) return 10001;
    final maxId = _courses.map((c) => c.id).reduce((a, b) => a > b ? a : b);
    return maxId + 1;
  }

  String _friendlyError(Object e) {
    if (e is OfflineCacheException) return e.message;

    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('connection')) {
      return 'No internet connection. Showing cached data when available.';
    }
    if (msg.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (msg.contains('apiexception')) {
      return 'Server error. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}
