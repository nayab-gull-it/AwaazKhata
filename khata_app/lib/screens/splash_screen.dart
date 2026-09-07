import 'package:flutter/material.dart';
import 'package:khata_app/screens/home_screen.dart';
import 'package:khata_app/screens/login_screen.dart';
import 'package:khata_app/services/session_service.dart';
import 'package:khata_app/theme/app_theme.dart';

/// Branded launch screen shown briefly on app start.
///
/// Goes straight to [HomeScreen] when the shopkeeper is already logged
/// in on this device, otherwise shows the logo for ~2 seconds and then
/// opens [LoginScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame to finish before navigating so we never
    // call Navigator.replace during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final loggedIn = await SessionService.isLoggedIn();
      debugPrint('[SplashScreen] isLoggedIn=$loggedIn');
      if (!mounted) return;

      if (loggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('[SplashScreen] isLoggedIn failed: $e');
      debugPrintStack(stackTrace: stackTrace, label: '[SplashScreen]');
    }

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.greenAccent,
              ),
              child: const Icon(
                Icons.record_voice_over_outlined,
                color: AppTheme.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'AwaazKhata',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Voice-first khata for your shop',
              style: TextStyle(
                color: AppTheme.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
