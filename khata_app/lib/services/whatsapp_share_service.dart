import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds and launches a WhatsApp share link for a udhaar bill.
class WhatsAppShareService {
  WhatsAppShareService._();

  /// Shares a udhaar bill summary with [phoneNumber] via wa.me.
  ///
  /// Numbers starting with "0" are converted to the Pakistan international
  /// format (+92); "+" and other non-digits are stripped. Shows a snackbar
  /// and does nothing when the number is missing or WhatsApp cannot be
  /// opened.
  static Future<void> shareUdhaarBill(
    BuildContext context, {
    required String phoneNumber,
    required String customerName,
    required double amount,
    required bool isPaid,
    required String dateText,
    String? description,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final digits = phoneNumber.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No phone number saved for WhatsApp')),
      );
      return;
    }
    // Local "03xx" numbers become international "923xx..." for wa.me.
    final international = digits.startsWith('0')
        ? '92${digits.substring(1)}'
        : digits;

    final statusLine = isPaid
        ? 'Status: Paid / Settled'
        : 'Status: Pending — please pay at your earliest.';
    final note = (description == null || description.trim().isEmpty)
        ? ''
        : '\nNote: ${description.trim()}';
    final message = 'AwaazKhata — Udhaar Bill\n'
        'Customer: $customerName\n'
        'Amount: Rs. ${_fmt(amount)}\n'
        '$dateText\n'
        '$statusLine'
        '$note';

    final uri = Uri.parse(
      'https://wa.me/$international?text=${Uri.encodeComponent(message)}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $e')),
        );
      }
    }
  }

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
