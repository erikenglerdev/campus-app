// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// One local to-do item. Purely on-device — never sent anywhere.
@immutable
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.createdAt,
    this.done = false,
  });

  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;

  Todo copyWith({String? title, bool? done}) => Todo(
    id: id,
    title: title ?? this.title,
    done: done ?? this.done,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'done': done,
    'createdAt': createdAt.toIso8601String(),
  };

  static Todo? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['id'];
    final Object? title = json['title'];
    if (id is! String || title is! String) return null;
    final DateTime created =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return Todo(
      id: id,
      title: title,
      done: json['done'] == true,
      createdAt: created,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Todo &&
      other.id == id &&
      other.title == title &&
      other.done == done &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, title, done, createdAt);
}
