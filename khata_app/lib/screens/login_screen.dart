import 'package:flutter/material.dart';
import 'package:khata_app/screens/home_screen.dart';
import 'package:khata_app/services/session_service.dart';
import 'package:khata_app/theme/app_theme.dart';

/// Local-only login screen for the demo.
///
/// Collects the shop name (and optional phone number), saves it on the
/// device via [SessionService], and opens [HomeScreen]. No real
/// authentication happens — this just personalizes the app and lets
/// subsequent launches skip straight to [HomeScreen].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final shopName = _shopNameController.text.trim();
    if (shopName.isEmpty || _saving) return;

    setState(() => _saving = true);
    await SessionService.saveShop(
      shopName: shopName,
      shopPhone: _phoneController.text.trim(),
    );
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.greenAccent,
                  ),
                  child: const Icon(
                    Icons.record_voice_over_outlined,
                    color: AppTheme.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'AwaazKhata',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us about your shop to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _shopNameController,
                  decoration: const InputDecoration(
                    labelText: 'Shop name',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _shopNameController.text.trim().isEmpty || _saving
                            ? null
                            : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
