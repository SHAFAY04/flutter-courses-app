import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/course_model.dart';

/// Hive-backed persistence for course data (offline cache).
class CourseLocalStorage {
  CourseLocalStorage._();
  static final CourseLocalStorage instance = CourseLocalStorage._();

  static const String _boxName = 'courses_box';
  static const String _coursesKey = 'courses';

  Box<String>? _box;

  Future<void> init() async {
    _box ??= await Hive.openBox<String>(_boxName);
  }

  Box<String> get _safeBox {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('CourseLocalStorage.init() must be called first.');
    }
    return box;
  }

  Future<List<CourseModel>> getCourses() async {
    final raw = _safeBox.get(_coursesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CourseModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCourses(List<CourseModel> courses) async {
    final encoded = jsonEncode(courses.map((c) => c.toStorageMap()).toList());
    await _safeBox.put(_coursesKey, encoded);
  }

  Future<void> upsertCourse(CourseModel course) async {
    final courses = await getCourses();
    final index = courses.indexWhere((c) => c.id == course.id);
    if (index == -1) {
      courses.insert(0, course);
    } else {
      courses[index] = course;
    }
    await saveCourses(courses);
  }

  Future<void> removeCourse(int id) async {
    final courses = await getCourses();
    courses.removeWhere((c) => c.id == id);
    await saveCourses(courses);
  }

  Future<void> clear() async {
    await _safeBox.delete(_coursesKey);
  }
}
