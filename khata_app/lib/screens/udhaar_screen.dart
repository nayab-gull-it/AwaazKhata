import 'package:flutter/material.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
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
    final uri = Uri(scheme: 'tel', path: normalized);
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
    final visibleEntries = query.isEmpty
        ? udhaar
        : udhaar
            .where((entry) => entry.customerName.toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                    return UdhaarCard(
                      entry: entry,
                      onMarkPaid: () {
                        context.read<AppState>().markUdhaarPaid(entry.id);
                      },
                      onCall: () => _callCustomer(context, entry.phoneNumber),
                      onEdit: () => _editEntry(context, entry),
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
