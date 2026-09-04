import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:provider/provider.dart';

/// Dialog for manually creating a task or reminder, as a fallback to
/// voice commands.
///
/// Collects a title, an optional description, and an optional due
/// date/time, then saves through the same [AppState.addTask] method the
/// voice pipeline uses.
class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _dueAt;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final description = _descriptionController.text.trim();

    context.read<AppState>().addTask(
          Task(
            id: 'task-${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            description: description.isEmpty ? null : description,
            dueAt: _dueAt,
            createdAt: DateTime.now(),
          ),
        );
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Task "$title" created'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, h:mm a');

    return AlertDialog(
      title: const Text('Add Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              _titleController.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
