import 'package:flutter/material.dart';
import 'package:khata_app/config/app_config.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/models/parsed_action.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/screens/inventory_screen.dart';
import 'package:khata_app/screens/login_screen.dart';
import 'package:khata_app/screens/tasks_screen.dart';
import 'package:khata_app/screens/udhaar_screen.dart';
import 'package:khata_app/services/backend_api_service.dart';
import 'package:khata_app/services/session_service.dart';
import 'package:khata_app/services/speech_service.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/mic_button.dart';
import 'package:khata_app/widgets/voice_answer_dialog.dart';
import 'package:khata_app/widgets/voice_confirmation_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Main entry screen with bottom tab navigation.
///
/// Shows summary cards at the top, lets the user switch between
/// inventory, tasks, and udhaar screens, and provides a microphone
/// button for Urdu voice commands. The full voice pipeline runs here:
/// speech → backend parsing → confirmation dialog → AppState mutation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  String? _recognizedPreview;

  final SpeechService _speechService = SpeechService();
  final BackendApiService _backendApi = BackendApiService();

  final List<Widget> _screens = const [
    InventoryScreen(),
    TasksScreen(),
    UdhaarScreen(),
  ];

  final List<String> _titles = const [
    'Inventory',
    'Tasks',
    'Udhaar',
  ];

  final List<IconData> _icons = const [
    Icons.inventory_2_outlined,
    Icons.check_circle_outline,
    Icons.account_balance_wallet_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _initSpeechAndPermission();
  }

  /// Initializes speech recognition and requests microphone permission.
  ///
  /// If permission is denied, shows a snackbar explaining why the mic
  /// is required before the user can use voice commands.
  Future<void> _initSpeechAndPermission() async {
    final permissionStatus = await Permission.microphone.request();

    if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionMessage();
      }
      return;
    }

    final available = await _speechService.initialize();
    if (mounted) {
      setState(() => _speechAvailable = available);
    }
  }

  /// Toggles the microphone listening state.
  ///
  /// Starts listening when idle and stops listening when active.
  Future<void> _onMicTap() async {
    if (_isListening) {
      await _speechService.stopListening();
      _setListening(false);
      return;
    }

    final permissionStatus = await Permission.microphone.status;
    if (!permissionStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) _showPermissionMessage();
        return;
      }
    }

    if (!_speechAvailable) {
      final available = await _speechService.initialize();
      if (!available) {
        if (mounted) {
          _showMessage('Speech recognition is not available on this device.');
        }
        return;
      }
      setState(() => _speechAvailable = true);
    }

    setState(() {
      _isListening = true;
      _recognizedPreview = null;
    });

    await _speechService.startListening(
      onResult: _onSpeechResult,
      localeId: AppConfig.appLocale,
      listenFor: const Duration(seconds: 10),
    );

    // Safety net: if the plugin never reports a final result, stop the UI
    // listening state after the configured listen duration.
    await Future<void>.delayed(const Duration(seconds: 11));
    if (mounted && _isListening) {
      _setListening(false);
      if (_recognizedPreview == null) {
        _showMessage('Sorry, please repeat');
      }
    }
  }

  /// Handles incoming speech results.
  ///
  /// Updates the preview text and, when the result is final with acceptable
  /// confidence, sends the transcript to the backend for parsing.
  void _onSpeechResult(SpeechResult result) {
    if (!mounted) return;

    setState(() {
      _recognizedPreview = result.text;
    });

    if (result.isFinal) {
      _setListening(false);

      if (result.confidence < 0.5) {
        _showMessage('Sorry, please repeat');
        return;
      }

      _processVoiceCommand(result.text);
    }
  }

  /// Sends the transcript to the backend, shows a confirmation dialog,
  /// and applies the confirmed action to AppState.
  Future<void> _processVoiceCommand(String transcript) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final parsedAction = await _backendApi.parseVoiceCommand(transcript);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Query commands are answered directly with a read-only dialog
      // instead of navigating to a screen.
      if (parsedAction.isQuery) {
        _answerQuery(parsedAction);
        return;
      }

      final appState = context.read<AppState>();
      final isUdhaarAction = parsedAction.type == VoiceActionType.addUdhaar ||
          parsedAction.type == VoiceActionType.reduceUdhaar;
      final udhaarCandidates = isUdhaarAction
          ? appState.findUdhaarMatches(parsedAction.customerName ?? '')
          : const <UdhaarEntry>[];
      final inventoryCandidates =
          parsedAction.type == VoiceActionType.addInventory
              ? appState.findInventoryMatches(parsedAction.name ?? '')
              : const <InventoryItem>[];

      final result = await VoiceConfirmationDialog.show(
        context,
        parsedAction,
        udhaarCandidates: udhaarCandidates,
        inventoryCandidates: inventoryCandidates,
      );

      if (result != null && mounted) {
        _applyAction(result);
      }
    } on BackendException catch (e) {
      debugPrint('[HomeScreen] BackendException: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showMessage(e.message);
      }
    } catch (e) {
      debugPrint('[HomeScreen] Unexpected error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showMessage("Couldn't process that, try again");
      }
    }
  }

  /// Answers a query-type action directly with a read-only dialog.
  void _answerQuery(ParsedAction action) {
    debugPrint('[HomeScreen] answering query action=${action.type}');
    final appState = context.read<AppState>();

    switch (action.type) {
      case VoiceActionType.queryBalance:
        _answerBalanceQuery(action, appState);

      case VoiceActionType.queryItemStock:
        _answerItemStockQuery(action, appState);

      case VoiceActionType.queryItemPrice:
        _answerItemPriceQuery(action, appState);

      case VoiceActionType.queryLowStock:
        _answerLowStockQuery(appState);

      case VoiceActionType.queryInventoryCount:
        _answerInventoryCountQuery(appState);

      default:
        break;
    }
  }

  /// Balance lookup: single match shows the amount, multiple matches list
  /// every close-name customer with their balance so the shopkeeper can
  /// read the one they meant without an extra selection step.
  void _answerBalanceQuery(ParsedAction action, AppState appState) {
    const icon = Icons.account_balance_wallet_outlined;
    const title = 'Customer Balance';
    final queryName = action.customerName ?? action.name ?? '';

    if (queryName.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: "Couldn't hear a customer name in that command",
      );
      return;
    }

    final matches = appState.findUdhaarMatches(queryName);

    if (matches.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: 'No udhaar record found for "$queryName"',
      );
      return;
    }

    if (matches.length == 1) {
      final entry = matches.single;
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: '${entry.customerName} owes Rs. ${_fmtRs(entry.amount)}',
        details: [
          if (entry.phoneNumber.isNotEmpty) 'Phone: ${entry.phoneNumber}',
          'Recorded on ${_fmtDate(entry.createdAt)}',
          if (entry.description != null && entry.description!.isNotEmpty)
            'Note: ${entry.description}',
        ],
      );
      return;
    }

    VoiceAnswerDialog.show(
      context,
      icon: icon,
      title: title,
      headline: '${matches.length} customers match "$queryName"',
      rows: [
        for (final entry in matches)
          VoiceAnswerRow(
            title: entry.customerName,
            subtitle: 'Owes Rs. ${_fmtRs(entry.amount)}',
          ),
      ],
    );
  }

  void _answerItemStockQuery(ParsedAction action, AppState appState) {
    const icon = Icons.inventory_2_outlined;
    const title = 'Item Stock';
    final queryName = action.name ?? '';

    if (queryName.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: "Couldn't hear a product name in that command",
      );
      return;
    }

    final matches = appState.findInventoryMatches(queryName);

    if (matches.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: '"$queryName" is not in your inventory',
      );
      return;
    }

    if (matches.length == 1) {
      final item = matches.single;
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: '${item.name}: ${item.quantity} ${item.unit} in stock',
        details: [
          'Sale price: Rs. ${_fmtRs(item.salePrice)} per ${item.unit}',
          if (item.isLowStock)
            'Low on stock — minimum level is ${item.minStockLevel}',
        ],
      );
      return;
    }

    VoiceAnswerDialog.show(
      context,
      icon: icon,
      title: title,
      headline: '${matches.length} items match "$queryName"',
      rows: [
        for (final item in matches)
          VoiceAnswerRow(
            title: item.name,
            subtitle: '${item.quantity} ${item.unit} in stock · '
                'Rs. ${_fmtRs(item.salePrice)}',
          ),
      ],
    );
  }

  void _answerItemPriceQuery(ParsedAction action, AppState appState) {
    const icon = Icons.local_offer_outlined;
    const title = 'Item Price';
    final queryName = action.name ?? '';

    if (queryName.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: "Couldn't hear a product name in that command",
      );
      return;
    }

    final matches = appState.findInventoryMatches(queryName);

    if (matches.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: '"$queryName" is not in your inventory',
      );
      return;
    }

    if (matches.length == 1) {
      final item = matches.single;
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline:
            '${item.name}: Rs. ${_fmtRs(item.salePrice)} per ${item.unit}',
        details: [
          '${item.quantity} ${item.unit} in stock',
          if (item.isLowStock)
            'Low on stock — minimum level is ${item.minStockLevel}',
        ],
      );
      return;
    }

    VoiceAnswerDialog.show(
      context,
      icon: icon,
      title: title,
      headline: '${matches.length} items match "$queryName"',
      rows: [
        for (final item in matches)
          VoiceAnswerRow(
            title: item.name,
            subtitle: 'Rs. ${_fmtRs(item.salePrice)} per ${item.unit} · '
                '${item.quantity} in stock',
          ),
      ],
    );
  }

  void _answerLowStockQuery(AppState appState) {
    const icon = Icons.warning_amber_outlined;
    const title = 'Low Stock';
    final lowItems =
        appState.inventory.where((item) => item.isLowStock).toList();

    if (lowItems.isEmpty) {
      VoiceAnswerDialog.show(
        context,
        icon: icon,
        title: title,
        headline: 'No items are low on stock',
      );
      return;
    }

    VoiceAnswerDialog.show(
      context,
      icon: icon,
      title: title,
      headline: '${lowItems.length} '
          '${lowItems.length == 1 ? 'item is' : 'items are'} low on stock',
      rows: [
        for (final item in lowItems)
          VoiceAnswerRow(
            title: item.name,
            subtitle: '${item.quantity} ${item.unit} left · '
                'minimum ${item.minStockLevel}',
          ),
      ],
    );
  }

  void _answerInventoryCountQuery(AppState appState) {
    final items = appState.inventory;
    final lowCount = items.where((item) => item.isLowStock).length;
    VoiceAnswerDialog.show(
      context,
      icon: Icons.calculate_outlined,
      title: 'Inventory Count',
      headline: 'You have ${items.length} '
          '${items.length == 1 ? 'item' : 'items'} in inventory',
      details: [
        if (lowCount > 0) '$lowCount low on stock',
      ],
    );
  }

  String _fmtRs(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  String _fmtDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  /// Applies a confirmed voice action to the AppState.
  ///
  /// Udhaar and inventory actions update an existing record when the user
  /// picked one in the confirmation dialog, and only create a new record
  /// otherwise. Navigation commands just switch tabs.
  void _applyAction(VoiceConfirmationResult result) {
    final action = result.action;
    final appState = context.read<AppState>();

    switch (action.type) {
      case VoiceActionType.addInventory:
        final target = result.inventoryTarget;
        if (target != null) {
          var updated = target;
          final salePrice = action.salePrice ?? 0;
          if (salePrice > 0) updated = updated.copyWith(salePrice: salePrice);
          final purchasePrice = action.purchasePrice ?? 0;
          if (purchasePrice > 0) {
            updated = updated.copyWith(purchasePrice: purchasePrice);
          }
          // A parsed quantity of 1 is the backend default for unspecified
          // quantities, so only add stock when more was actually spoken.
          final qty = action.quantity ?? 0;
          if (qty > 1) {
            updated = updated.copyWith(quantity: updated.quantity + qty);
          }
          appState.updateInventoryItem(updated);
          _showMessage('Updated "${target.name}"');
        } else {
          final id = 'inv-${DateTime.now().millisecondsSinceEpoch}';
          appState.addInventoryItem(
            InventoryItem(
              id: id,
              name: action.name ?? 'New Item',
              category: action.category ?? 'General',
              quantity: action.quantity ?? 1,
              unit: action.unit ?? 'pcs',
              purchasePrice: action.purchasePrice ?? 0.0,
              salePrice: action.salePrice ?? 0.0,
              createdAt: DateTime.now(),
            ),
          );
          _showMessage('Added "${action.name}" to inventory');
        }
        _switchToTab(0);

      case VoiceActionType.addUdhaar:
        final target = result.udhaarTarget;
        final amount = action.amount ?? 0.0;
        if (target != null) {
          final newTotal = target.amount + amount;
          appState.updateUdhaar(target.copyWith(amount: newTotal));
          _showMessage('Updated udhaar for "${target.customerName}" — '
              'new total Rs. ${newTotal.toStringAsFixed(0)}');
        } else {
          final id = 'udh-${DateTime.now().millisecondsSinceEpoch}';
          appState.addUdhaar(
            UdhaarEntry(
              id: id,
              customerName: action.customerName ?? 'Unknown',
              phoneNumber: action.phoneNumber ?? '',
              amount: amount,
              description: action.description,
              createdAt: DateTime.now(),
            ),
          );
          _showMessage('Recorded udhaar for "${action.customerName}"');
        }
        _switchToTab(2);

      case VoiceActionType.reduceUdhaar:
        final target = result.udhaarTarget;
        if (target == null) {
          _showMessage("Couldn't apply the payment — no matching udhaar "
              'record was selected');
          return;
        }
        final paid = action.amount ?? 0.0;
        final remaining = target.amount - paid;
        final newAmount = remaining > 0 ? remaining : 0.0;
        final settled = newAmount <= 0;
        appState.updateUdhaar(
          target.copyWith(
            amount: newAmount,
            isPaid: settled ? true : target.isPaid,
            paidAt: settled ? DateTime.now() : target.paidAt,
          ),
        );
        _showMessage(settled
            ? 'Payment recorded — "${target.customerName}" is fully settled'
            : 'Payment recorded — "${target.customerName}" owes '
                'Rs. ${newAmount.toStringAsFixed(0)}');
        _switchToTab(2);

      case VoiceActionType.addTask:
        final id = 'task-${DateTime.now().millisecondsSinceEpoch}';
        appState.addTask(
          Task(
            id: id,
            title: action.title ?? 'New Task',
            description: action.description,
            createdAt: DateTime.now(),
            priority: action.priority,
          ),
        );
        _showMessage('Created ${action.priority.name} priority task '
            '"${action.title}"');
        _switchToTab(1);

      case VoiceActionType.queryBalance ||
           VoiceActionType.queryItemStock ||
           VoiceActionType.queryItemPrice ||
           VoiceActionType.queryLowStock ||
           VoiceActionType.queryInventoryCount:
        // Query actions are answered by _answerQuery before the
        // confirmation dialog is ever shown; answering here too keeps
        // this path correct if it is ever reached.
        _answerQuery(action);

      case VoiceActionType.navigate:
        final tabIndex = _tabIndexFromTarget(action.targetTab);
        _switchToTab(tabIndex);

      case VoiceActionType.unknown:
        _showMessage("Couldn't understand that command");
    }
  }

  /// Switches the bottom navigation to the given tab index (0, 1, or 2).
  void _switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  /// Maps a target tab name from the backend to a tab index.
  int _tabIndexFromTarget(String? target) {
    return switch (target?.toLowerCase()) {
      'inventory' => 0,
      'tasks' => 1,
      'udhaar' => 2,
      _ => 0,
    };
  }

  void _setListening(bool listening) {
    if (mounted) {
      setState(() => _isListening = listening);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPermissionMessage() {
    _showMessage(
      'Microphone permission is needed for voice commands. '
      'Please enable it in app settings.',
    );
  }

  /// Opens the settings dialog, which shows the logged-in shop and
  /// offers to log out (clearing the locally saved login info).
  Future<void> _openSettings() async {
    final info = await SessionService.shopInfo();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReadOnlyInfo(label: 'Shop', value: info.shopName),
            if (info.shopPhone.isNotEmpty)
              _ReadOnlyInfo(label: 'Phone', value: info.shopPhone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await SessionService.clear();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Stop any active listening session and release plugin resources.
    _speechService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
            ),
        ],
      ),
      body: Column(
        children: [
          _SummaryCards(
            lowStockCount: appState.lowStockCount,
            pendingTaskCount: appState.pendingTaskCount,
            pendingUdhaar: appState.totalPendingUdhaar,
          ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MicButton(
          isListening: _isListening,
          onTap: _isProcessing ? null : _onMicTap,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_screens.length, (index) {
              final isSelected = index == _currentIndex;
              return IconButton(
                onPressed: () => setState(() => _currentIndex = index),
                icon: Icon(
                  _icons[index],
                  color: isSelected ? AppTheme.navy : AppTheme.textSecondary,
                ),
                tooltip: _titles[index],
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Small label/value row used by the settings dialog.
class _ReadOnlyInfo extends StatelessWidget {
  const _ReadOnlyInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal summary cards shown below the app bar.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.lowStockCount,
    required this.pendingTaskCount,
    required this.pendingUdhaar,
  });

  final int lowStockCount;
  final int pendingTaskCount;
  final double pendingUdhaar;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.navy,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              icon: Icons.warning_amber_outlined,
              label: 'Low Stock',
              value: '$lowStockCount',
              color: AppTheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.pending_actions_outlined,
              label: 'Pending Tasks',
              value: '$pendingTaskCount',
              color: AppTheme.greenAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Pending Udhaar',
              value: 'Rs. ${pendingUdhaar.toStringAsFixed(0)}',
              color: AppTheme.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
