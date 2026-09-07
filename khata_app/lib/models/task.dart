/// Represents a task or reminder for the shopkeeper.
///
/// Tasks can be created manually or generated from voice commands
/// (e.g. "Kal subah 9 baje dukaan kholo").
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.dueAt,
    this.isCompleted = false,
    this.priority = TaskPriority.normal,
  });

  /// Unique identifier for this task.
  final String id;

  /// Short, actionable summary of the task.
  final String title;

  /// Optional extra details.
  final String? description;

  /// When the task was created.
  final DateTime createdAt;

  /// Optional deadline for the task.
  final DateTime? dueAt;

  /// Whether the task has been completed.
  final bool isCompleted;

  /// Importance level used for sorting and visual emphasis.
  final TaskPriority priority;

  /// Creates a copy with selected fields updated, preserving immutability.
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? dueAt,
    bool? isCompleted,
    TaskPriority? priority,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
    );
  }

  /// Serializes this task to JSON for local persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt?.toIso8601String(),
        'isCompleted': isCompleted,
        'priority': priority.name,
      };

  /// Deserializes a task from JSON stored by [toJson].
  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueAt: json['dueAt'] == null
            ? null
            : DateTime.parse(json['dueAt'] as String),
        isCompleted: json['isCompleted'] as bool? ?? false,
        priority: TaskPriority.values.byName(
          (json['priority'] as String?) ?? 'normal',
        ),
      );
}

/// Importance levels for tasks.
enum TaskPriority { low, normal, high }
