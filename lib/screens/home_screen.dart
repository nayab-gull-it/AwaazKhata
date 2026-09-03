import 'package:flutter/material.dart';
import 'package:khata_app/config/app_config.dart';
import 'package:khata_app/models/inventory_item.dart';
import 'package:khata_app/models/parsed_action.dart';
import 'package:khata_app/models/task.dart';
import 'package:khata_app/models/udhaar_entry.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/screens/inventory_screen.dart';
import 'package:khata_app/screens/tasks_screen.dart';
import 'package:khata_app/screens/udhaar_screen.dart';
import 'package:khata_app/services/backend_api_service.dart';
import 'package:khata_app/services/speech_service.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/mic_button.dart';
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

      final confirmedAction = await VoiceConfirmationDialog.show(
        context,
        parsedAction,
      );

      if (confirmedAction != null && mounted) {
        _applyAction(confirmedAction);
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

  /// Applies a confirmed voice action to the AppState.
  ///
  /// Routes to the appropriate tab if the action is a navigation command,
  /// otherwise adds the parsed entry to the relevant list.
  void _applyAction(ParsedAction action) {
    final appState = context.read<AppState>();

    switch (action.type) {
      case VoiceActionType.addInventory:
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
        _switchToTab(0);

      case VoiceActionType.addUdhaar:
        final id = 'udh-${DateTime.now().millisecondsSinceEpoch}';
        appState.addUdhaar(
          UdhaarEntry(
            id: id,
            customerName: action.customerName ?? 'Unknown',
            phoneNumber: action.phoneNumber ?? '',
            amount: action.amount ?? 0.0,
            description: action.description,
            createdAt: DateTime.now(),
          ),
        );
        _showMessage('Recorded udhaar for "${action.customerName}"');
        _switchToTab(2);

      case VoiceActionType.addTask:
        final id = 'task-${DateTime.now().millisecondsSinceEpoch}';
        appState.addTask(
          Task(
            id: id,
            title: action.title ?? 'New Task',
            description: action.description,
            createdAt: DateTime.now(),
          ),
        );
        _showMessage('Created task "${action.title}"');
        _switchToTab(1);

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
              onPressed: () {
                // TODO: Open settings/profile screen.
              },
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
