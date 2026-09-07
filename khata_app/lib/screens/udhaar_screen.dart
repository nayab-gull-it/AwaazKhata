import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/screens/customer_ledger_screen.dart';
import 'package:khata_app/screens/pending_clients_screen.dart';
import 'package:khata_app/services/whatsapp_share_service.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/add_udhaar_dialog.dart';
import 'package:khata_app/widgets/edit_udhaar_dialog.dart';
import 'package:khata_app/widgets/udhaar_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen that lists customer credit (udhaar) entries.
///
/// Reads udhaar data from [AppState], filters by customer name via a search
/// bar, renders each entry through [UdhaarCard], and exposes edit and manual
/// add actions.
class UdhaarScreen extends StatefulWidget {
  const UdhaarScreen({super.key});

  @override
  State<UdhaarScreen> createState() => _UdhaarScreenState();
}

class _UdhaarScreenState extends State<UdhaarScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _callCustomer(BuildContext context, String phoneNumber) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number saved')),
        );
      }
      return;
    }
    // Keep only digits and the leading '+'; strip spaces/dashes/parentheses.
    final dialable = normalized.startsWith('+')
        ? '+${normalized.substring(1).replaceAll(RegExp(r'\D'), '')}'
        : normalized.replaceAll(RegExp(r'\D'), '');
    if (dialable.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone number is not valid')),
        );
      }
      return;
    }

    final uri = Uri(scheme: 'tel', path: dialable);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place call: $e')),
        );
      }
    }
  }

  void _editEntry(BuildContext context, UdhaarEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => EditUdhaarDialog(entry: entry),
    );
  }

  void _openLedger(BuildContext context, UdhaarEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerLedgerScreen(
          customerName: entry.customerName,
          phoneNumber: entry.phoneNumber,
        ),
      ),
    );
  }

  Future<void> _shareBill(BuildContext context, UdhaarEntry entry) async {
    final dateFormat = DateFormat('d MMM yyyy');
    await WhatsAppShareService.shareUdhaarBill(
      context,
      phoneNumber: entry.phoneNumber,
      customerName: entry.customerName,
      amount: entry.amount,
      isPaid: entry.isPaid,
      dateText:
          'Recorded on ${dateFormat.format(entry.createdAt)}',
      description: entry.description,
    );
  }

  Future<void> _deleteEntry(BuildContext context, UdhaarEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Udhaar Entry'),
        content: Text(
          'Delete udhaar record for "${entry.customerName}"?',
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

    if (confirmed == true && context.mounted) {
      context.read<AppState>().removeUdhaar(entry.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted udhaar for "${entry.customerName}"')),
      );
    }
  }

  void _addEntry() {
    showDialog<void>(
      context: context,
      builder: (_) => const AddUdhaarDialog(),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final udhaar = context.watch<AppState>().udhaar;
    final query = _query.trim().toLowerCase();
    final visibleEntries = (query.isEmpty
            ? udhaar
            : udhaar
                .where(
                    (entry) => entry.customerName.toLowerCase().contains(query))
                .toList())
        .toList()
      ..sort((a, b) {
        // Active (unpaid) customers first; settled entries at the bottom.
        if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
        // Within each group, most recent transaction first.
        return b.createdAt.compareTo(a.createdAt);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search customers by name',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                            tooltip: 'Clear search',
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PendingClientsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.people_outline),
                tooltip: 'Pending clients',
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              if (visibleEntries.isEmpty)
                _EmptyState(
                  icon: query.isEmpty
                      ? Icons.account_balance_wallet_outlined
                      : Icons.search_off,
                  message: query.isEmpty
                      ? 'No udhaar entries yet.\n'
                          'Record credit sales by voice or manually.'
                      : 'No customers match "${_query.trim()}".\n'
                          'Try a different name or clear the search.',
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 100),
                  itemCount: visibleEntries.length,
                  itemBuilder: (context, index) {
                    final entry = visibleEntries[index];
                    return InkWell(
                      onTap: () => _openLedger(context, entry),
                      child: UdhaarCard(
                        entry: entry,
                        onMarkPaid: () {
                          context.read<AppState>().markUdhaarPaid(entry.id);
                        },
                        onCall: () => _callCustomer(context, entry.phoneNumber),
                        onEdit: () => _editEntry(context, entry),
                        onDelete: () => _deleteEntry(context, entry),
                        onShare: () => _shareBill(context, entry),
                      ),
                    );
                  },
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: _addEntry,
                  tooltip: 'Add udhaar entry',
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ],
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
