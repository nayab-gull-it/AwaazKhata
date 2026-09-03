import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable row that shows a date/time value and lets the user pick a new
/// date and time via the platform pickers.
class DateTimePickerField extends StatelessWidget {
  const DateTimePickerField({
    required this.label,
    required this.dateTime,
    required this.format,
    required this.onChanged,
    super.key,
  });

  final String label;
  final DateTime dateTime;
  final DateFormat format;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pickDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dateTime),
    );

    if (pickedTime == null || !context.mounted) return;

    onChanged(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pickDateTime(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(format.format(dateTime)),
      ),
    );
  }
}
