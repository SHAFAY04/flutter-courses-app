import '../core/services/connectivity_service.dart';
import '../data/local/course_local_storage.dart';
import '../models/course_model.dart';
import '../services/course_api_service.dart';

/// Result of a course list fetch — tells the UI whether data came from cache.
class CourseFetchResult {
  final List<CourseModel> courses;
  final bool isFromCache;
  final bool isOffline;

  const CourseFetchResult({
    required this.courses,
    this.isFromCache = false,
    this.isOffline = false,
  });
}

/// Repository layer: chooses between remote API and local Hive storage.
/// UI and controllers never call [CourseApiService] or [CourseLocalStorage]
/// directly.
class CourseRepository {
  CourseRepository({
    CourseApiService? api,
    CourseLocalStorage? local,
    ConnectivityService? connectivity,
  })  : _api = api ?? CourseApiService.instance,
        _local = local ?? CourseLocalStorage.instance,
        _connectivity = connectivity ?? ConnectivityService.instance;

  final CourseApiService _api;
  final CourseLocalStorage _local;
  final ConnectivityService _connectivity;

  static const int _remoteIdLimit = 100;

  // ─── READ ─────────────────────────────────────────────────────────────────

  Future<CourseFetchResult> fetchCourses({int limit = 20}) async {
    final online = await _connectivity.isConnected();

    if (online) {
      try {
        final courses = await _api.fetchCourses(limit: limit);
        await _local.saveCourses(courses);
        return CourseFetchResult(courses: courses);
      } catch (_) {
        final cached = await _local.getCourses();
        if (cached.isNotEmpty) {
          return CourseFetchResult(
            courses: cached,
            isFromCache: true,
            isOffline: false,
          );
        }
        rethrow;
      }
    }

    final cached = await _local.getCourses();
    if (cached.isEmpty) {
      throw const OfflineCacheException(
        'No cached courses available. Connect to the internet to load data.',
      );
    }

    return CourseFetchResult(
      courses: cached,
      isFromCache: true,
      isOffline: true,
    );
  }

  // ─── CREATE ───────────────────────────────────────────────────────────────

  Future<CourseModel> createCourse({
    required String title,
    required String description,
    required int localId,
  }) async {
    final optimistic = CourseModel(
      id: localId,
      userId: 1,
      title: title,
      body: description,
    );

    await _local.upsertCourse(optimistic);

    final online = await _connectivity.isConnected();
    if (!online) return optimistic;

    try {
      await _api.createCourse(title: title, description: description);
      return optimistic;
    } catch (_) {
      return optimistic;
    }
  }

  // ─── UPDATE ───────────────────────────────────────────────────────────────

  Future<CourseModel> updateCourse(CourseModel course) async {
    await _local.upsertCourse(course);

    final online = await _connectivity.isConnected();
    if (!online || course.id > _remoteIdLimit) {
      return course;
    }

    final remote = await _api.updateCourse(course);
    await _local.upsertCourse(remote);
    return remote;
  }

  /// Persists the optimistic change locally, then attempts the remote call.
  /// Throws if the remote delete fails while online so the controller can
  /// roll back the UI.
  Future<void> deleteCourse(int id) async {
    await _local.removeCourse(id);

    final online = await _connectivity.isConnected();
    if (!online || id > _remoteIdLimit) return;

    await _api.deleteCourse(id);
  }

  /// Re-insert a course after a failed optimistic delete rollback.
  Future<void> restoreCourse(CourseModel course) async {
    await _local.upsertCourse(course);
  }

  /// Restore previous course data after a failed optimistic update rollback.
  Future<void> restoreCourseAt(CourseModel previous) async {
    await _local.upsertCourse(previous);
  }

  Future<void> persistCourses(List<CourseModel> courses) async {
    await _local.saveCourses(courses);
  }
}

class OfflineCacheException implements Exception {
  final String message;
  const OfflineCacheException(this.message);

  @override
  String toString() => message;
}
