import 'package:flutter/material.dart';
import 'package:khata_app/providers/app_state.dart';
import 'package:khata_app/screens/splash_screen.dart';
import 'package:khata_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AwaazKhataApp());
}

/// Root widget of the AwaazKhata application.
///
/// Sets up the global [AppState] provider and applies the centralized
/// app theme.
class AwaazKhataApp extends StatelessWidget {
  const AwaazKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'AwaazKhata',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
