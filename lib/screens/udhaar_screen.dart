import 'package:flutter/material.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/widgets/edit_udhaar_dialog.dart';
import 'package:khata_app/widgets/udhaar_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen that lists customer credit (udhaar) entries.
///
/// Reads udhaar data from [AppState] and renders each entry through
/// [UdhaarCard], with an edit action that opens [EditUdhaarDialog].
class UdhaarScreen extends StatelessWidget {
  const UdhaarScreen({super.key});

  Future<void> _callCustomer(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _editEntry(BuildContext context, UdhaarEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => EditUdhaarDialog(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final udhaar = context.watch<AppState>().udhaar;

    if (udhaar.isEmpty) {
      return const _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: 'No udhaar entries yet.\nRecord credit sales by voice.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 100),
      itemCount: udhaar.length,
      itemBuilder: (context, index) {
        final entry = udhaar[index];
        return UdhaarCard(
          entry: entry,
          onMarkPaid: () {
            context.read<AppState>().markUdhaarPaid(entry.id);
          },
          onCall: () => _callCustomer(entry.phoneNumber),
          onEdit: () => _editEntry(context, entry),
        );
      },
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
