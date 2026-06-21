// lib/screens/auth/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/socket_service.dart';
import '../../services/api_config.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _failSafeTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startFailSafeTimer();
    _initializeApp();
  }

  void _startFailSafeTimer() {
    // 6s is enough: SharedPreferences is pre-cached in main(), so this
    // should complete in well under 1s on a healthy device.
    _failSafeTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _hasNavigated) return;
      print('[SPLASH] FAIL-SAFE TRIGGERED: Forcing navigation to /login');
      _navigateTo('/login');
    });
  }

  void _navigateTo(String route) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _failSafeTimer?.cancel();
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    print('[SPLASH] _initializeApp starting...');

    try {
      // SharedPreferences is pre-cached in main() so this should be near-instant.
      // Timeout is 2s as a safety net for very slow devices.
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('[SPLASH WARNING] SharedPreferences timeout, proceeding with null checks');
          throw TimeoutException('SharedPreferences took too long');
        },
      );
      
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String? userId = prefs.getString('userId');
      print('[SPLASH] Auth Status: isLoggedIn=$isLoggedIn');

      // 2. Socket Connection (Non-blocking)
      print('[SPLASH] Connecting to Socket: ${ApiConfig.socketUrl}');
      SocketService.connect(ApiConfig.socketUrl);
      
      if (userId != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          SocketService.identifyUser(userId);
        });
      }

      // 3. Minimum Display Time (reduced to 1.5s for snappier startup)
      final elapsed = DateTime.now().difference(startTime);
      const minDisplay = Duration(milliseconds: 1500);
      if (elapsed < minDisplay) {
        await Future.delayed(minDisplay - elapsed);
      }

      print('[SPLASH] Navigating to ${isLoggedIn ? '/home' : '/login'}');
      _navigateTo(isLoggedIn ? '/home' : '/login');
      
    } catch (e) {
      debugPrint('[SPLASH ERROR] $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Startup Note: ${e.toString().replaceAll('Exception: ', '')}"),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (snackError) {
          debugPrint('[SPLASH SNACKBAR ERROR] $snackError');
        }
        
        // Wait a bit for the user to see the note, then proceed to login anyway
        await Future.delayed(const Duration(seconds: 2));
        _navigateTo('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[SPLASH] SplashScreen.build triggered');
    return Scaffold(
      backgroundColor: Colors.white, // Match new app icon theme
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          print('[SPLASH] Manual tap bypass triggered');
          _navigateTo('/login');
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with subtle zoom & fade in
              Image.asset(
                'assets/images/ipark_logo.png',
                width: 150,
              ).animate()
               .fadeIn(duration: 800.ms)
               .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack),
              
              const SizedBox(height: 24),
              
              // Loading indicator (clean and themed)
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
                ),
              ).animate()
               .fadeIn(delay: 500.ms),
              
              const SizedBox(height: 24),
              
              // Helper text that fades in after a delay to offer manual bypass
              Text(
                "Tap screen to skip loading if stuck",
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.6),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ).animate()
               .fadeIn(delay: 2500.ms),
            ],
          ),
        ),
      ),
    );
  }
  @override
  void dispose() {
    _failSafeTimer?.cancel();
    super.dispose();
  }
}
