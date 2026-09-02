import 'package:flutter/material.dart';
import 'package:khata_app/config/app_config.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/screens/inventory_screen.dart';
import 'package:khata_app/screens/tasks_screen.dart';
import 'package:khata_app/screens/udhaar_screen.dart';
import 'package:khata_app/services/speech_service.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:khata_app/widgets/mic_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Main entry screen with bottom tab navigation.
///
/// Shows summary cards at the top, lets the user switch between
/// inventory, tasks, and udhaar screens, and provides a microphone
/// button for Urdu voice commands.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _recognizedPreview;

  final SpeechService _speechService = SpeechService();

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
  /// Starts listening when idle and stops listening when active. The
  /// recognized text is shown in a preview area for verification; it is
  /// not sent to the backend yet.
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
      // TEMP: extended window to rule out premature cutoff during testing.
      listenFor: const Duration(seconds: 15),
    );

    // Safety net: if the plugin never reports a final result, stop the UI
    // listening state after the configured listen duration.
    // TEMP: 16s to match the extended 15s listen window.
    await Future<void>.delayed(const Duration(seconds: 16));
    if (mounted && _isListening) {
      _setListening(false);
      if (_recognizedPreview == null) {
        _showMessage('No speech detected');
      }
    }
  }

  /// Handles incoming speech results.
  ///
  /// Updates the preview text and, when the result is final, stops
  /// listening and displays the raw text with its confidence score.
  // TEMP: confidence gate removed for accuracy diagnosis — always show the
  // raw result so we can see exactly what was detected and how confident
  // the plugin is. Restore the < 0.5 threshold after testing.
  void _onSpeechResult(SpeechResult result) {
    if (!mounted) return;

    setState(() {
      _recognizedPreview = result.text;
    });

    if (result.isFinal) {
      _setListening(false);

      _showMessage(
        '"${result.text}" (confidence: ${result.confidence.toStringAsFixed(2)})',
      );
    }
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
          onTap: _onMicTap,
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
