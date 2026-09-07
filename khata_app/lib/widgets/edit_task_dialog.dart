import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/date_time_picker_field.dart';
import 'package:provider/provider.dart';

/// Dialog for editing an existing task or reminder.
///
/// Allows the user to change the title, description, priority, due date,
/// and creation timestamp, and saves the updated task through [AppState].
class EditTaskDialog extends StatefulWidget {
  const EditTaskDialog({required this.task, super.key});

  final Task task;

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _createdAt;
  DateTime? _dueAt;
  late TaskPriority _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description ?? '',
    );
    _createdAt = widget.task.createdAt;
    _dueAt = widget.task.dueAt;
    _priority = widget.task.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedTask = widget.task.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: _createdAt,
      dueAt: _dueAt,
      priority: _priority,
    );

    context.read<AppState>().updateTask(updatedTask);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
          'Are you sure you want to delete this task?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<AppState>().removeTask(widget.task.id);
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDueDateTime() async {
    final initialDate = _dueAt ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _dueAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _clearDueDate() {
    setState(() => _dueAt = null);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, h:mm a');

    return AlertDialog(
      title: const Text('Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: TaskPriority.values.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(_priorityLabel(priority)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 12),
            DateTimePickerField(
              label: 'Created at',
              dateTime: _createdAt,
              format: dateFormat,
              onChanged: (value) => setState(() => _createdAt = value),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDueDateTime,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Due at (optional)',
                  suffixIcon: _dueAt != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearDueDate,
                        )
                      : const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _dueAt != null ? dateFormat.format(_dueAt!) : 'Not set',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _priorityLabel(TaskPriority priority) {
    return switch (priority) {
      TaskPriority.high => 'High',
      TaskPriority.normal => 'Normal',
      TaskPriority.low => 'Low',
    };
  }
}
