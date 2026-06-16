/// Maps directly to the JSONPlaceholder `/posts` endpoint.
/// https://jsonplaceholder.typicode.com/posts
class CourseModel {
  final int id;
  final int userId;
  final String title;
  final String body; // used as description

  const CourseModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  // ─── Serialisation ────────────────────────────────────────────────────────
  factory CourseModel.fromMap(Map<String, dynamic> map) => CourseModel(
        id: map['id'] as int,
        userId: map['userId'] as int,
        title: map['title'] as String,
        body: map['body'] as String,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'title': title,
        'body': body,
      };

  /// Full map including [id] for Hive / JSON persistence.
  Map<String, dynamic> toStorageMap() => {
        'id': id,
        ...toMap(),
      };

  CourseModel copyWith({
    int? id,
    int? userId,
    String? title,
    String? body,
  }) =>
      CourseModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        body: body ?? this.body,
      );

  @override
  String toString() =>
      'CourseModel(id: $id, userId: $userId, title: $title)';
}
