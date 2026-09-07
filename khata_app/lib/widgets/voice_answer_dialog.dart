import 'dart:async';

import 'package:flutter/material.dart';
import 'package:khata_app/services/tts_service.dart';
import 'package:khata_app/theme/app_theme.dart';

/// One list entry shown in a [VoiceAnswerDialog], e.g. a matching
/// customer with their balance, or a low-stock item with its quantity.
class VoiceAnswerRow {
  const VoiceAnswerRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// Read-only dialog that answers a query-type voice command directly.
///
/// Unlike [VoiceConfirmationDialog], this has no confirm/cancel flow —
/// it just states the answer (headline plus optional detail lines and
/// a list of result rows) and offers a single Close action, so the
/// shopkeeper gets an immediate answer without any extra taps.
///
/// The headline (and, when present, the row subtitles) are also spoken
/// aloud via [TtsService], so the answer is heard as well as read.
/// Speech is cancelled when the dialog is dismissed.
class VoiceAnswerDialog extends StatefulWidget {
  const VoiceAnswerDialog({
    required this.icon,
    required this.title,
    required this.headline,
    this.details = const [],
    this.rows = const [],
    super.key,
  });

  final IconData icon;

  /// Dialog title, typically the action label (e.g. "Customer Balance").
  final String title;

  /// The main answer, shown large and bold.
  final String headline;

  /// Secondary lines below the headline (phone, price, stock level, ...).
  final List<String> details;

  /// Optional result rows, e.g. one per matching customer or item.
  final List<VoiceAnswerRow> rows;

  /// Convenience method to show this dialog.
  static Future<void> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String headline,
    List<String> details = const [],
    List<VoiceAnswerRow> rows = const [],
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => VoiceAnswerDialog(
        icon: icon,
        title: title,
        headline: headline,
        details: details,
        rows: rows,
      ),
    );
  }

  @override
  State<VoiceAnswerDialog> createState() => _VoiceAnswerDialogState();
}

class _VoiceAnswerDialogState extends State<VoiceAnswerDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(_speakAnswer());
  }

  @override
  void dispose() {
    unawaited(TtsService.instance.stop());
    super.dispose();
  }

  /// Builds the spoken text: headline, detail lines, then row summaries.
  Future<void> _speakAnswer() async {
    final parts = <String>[widget.headline];
    parts.addAll(widget.details);
    for (final row in widget.rows) {
      parts.add('${row.title}. ${row.subtitle}');
    }
    await TtsService.instance.speak(parts.join('. '));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(widget.icon, color: AppTheme.navy),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.headline,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            for (final detail in widget.details)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            if (widget.rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              for (final row in widget.rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    row.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    row.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
