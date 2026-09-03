import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/edit_task_dialog.dart';
import 'package:provider/provider.dart';

/// Screen that lists tasks and reminders.
///
/// Reads task data from [AppState], lets users toggle completion,
/// and open [EditTaskDialog] to edit a task.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  void _editTask(BuildContext context, Task task) {
    showDialog<void>(
      context: context,
      builder: (_) => EditTaskDialog(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<AppState>().tasks;

    if (tasks.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        message: 'No tasks yet.\nCreate reminders using your voice.',
      );
    }

    final sortedTasks = [...tasks]
      ..sort((a, b) {
        // Pending high-priority tasks surface first.
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.priority.index.compareTo(a.priority.index);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      itemCount: sortedTasks.length,
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return _TaskTile(
          task: task,
          onEdit: () => _editTask(context, task),
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, this.onEdit});

  final Task task;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM, h:mm a');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: AppTheme.greenAccent,
          onChanged: (_) {
            context.read<AppState>().toggleTaskCompletion(task.id);
          },
        ),
        title: Text(
          task.title,
          style: theme.textTheme.titleMedium?.copyWith(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? AppTheme.textSecondary : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.description!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                _PriorityChip(priority: task.priority),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Created ${dateFormat.format(task.createdAt)}',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.dueAt != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Due ${dateFormat.format(task.dueAt!)}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: onEdit != null
            ? IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit task',
                color: AppTheme.textSecondary,
              )
            : null,
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      TaskPriority.high => ('High', AppTheme.error),
      TaskPriority.normal => ('Normal', AppTheme.navyLight),
      TaskPriority.low => ('Low', AppTheme.greenAccent),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).hintColor),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
