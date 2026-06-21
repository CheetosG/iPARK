// lib/main.dart
/// iPark Main Entry Point
///
/// This file initializes the Flutter application, sets up global error handling,
/// configures state management (Provider), and manages global application state
/// such as theme settings and real-time socket listeners.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'routes/app_router.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'providers/reservation_provider.dart';
import 'package:provider/provider.dart';
import 'services/error_reporter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'widgets/app_background.dart';

/// App initialization logic.
/// Handles binding, storage warm-up, error reporting, and launching the app.
Future<void> main() async {
  try {
    print('[DEBUG] main starting (async)...');

    // Ensure Flutter framework is initialized before any async operations
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize local notification service (shows alerts in the notification bar)
    await NotificationService.init();
    print('[DEBUG] WidgetsBinding initialized');

    // IMPORTANT: Await SharedPreferences here so the instance is cached in the
    // platform channel before runApp. Both SplashScreen and ReservationProvider
    // call getInstance() shortly after — if uncached, they race on the native
    // side and the first concurrent call blocks until the native I/O completes,
    // causing the splash screen to appear frozen.
    try {
      await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('[DEBUG WARNING] SharedPreferences pre-cache timed out');
          throw TimeoutException('SharedPreferences initialization timed out');
        },
      );
      print('[DEBUG] SharedPreferences pre-cached successfully');
    } catch (e) {
      print('[DEBUG WARNING] SharedPreferences pre-cache failed (non-fatal): $e');
    }

    // --- Global Error Handling ---

    // Catch errors from the Flutter framework (UI thread)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      ErrorReporter.instance.reportError(
        message: details.exceptionAsString(),
        stackTrace: details.stack.toString(),
        metadata: {'type': 'FlutterError'},
      );
    };

    // Catch errors from the platform/asynchronous tasks
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.instance.reportError(
        message: error.toString(),
        stackTrace: stack.toString(),
        metadata: {'type': 'PlatformError'},
      );
      return true;
    };

    // --- App Launch ---

    runApp(
      MultiProvider(
        providers: [
          // Global state for reservations and user data
          ChangeNotifierProvider(
            create: (_) {
              print('[DEBUG] ReservationProvider initialized');
              return ReservationProvider();
            },
          ),
        ],
        child: const IparkApp(initialRoute: '/splash'),
      ),
    );
    print('[DEBUG] runApp called successfully');
  } catch (e, stack) {
    debugPrint('Critical Main Error: $e');
    debugPrint(stack.toString());
  }
}

/// Main Application Widget.
/// Manages global configurations like navigation keys and initial routing.
class IparkApp extends StatefulWidget {
  // Global key used for navigation without a BuildContext
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final String initialRoute;
  const IparkApp({super.key, required this.initialRoute});

  @override
  IparkAppState createState() => IparkAppState();
}

class IparkAppState extends State<IparkApp> {
  // --- Application State ---
  ThemeMode _themeMode = ThemeMode.system; // Defaults to system theme
  ThemeMode get themeMode => _themeMode;

  // Subscription handles for cleanup during dispose
  StreamSubscription? _arrivalSub;
  StreamSubscription? _banSub;
  StreamSubscription? _roleSub;
  StreamSubscription? _leaveEarlySub;
  StreamSubscription? _reverifySub;

  @override
  void initState() {
    super.initState();

    // Initialize global listeners and configurations
    _loadThemeSettings();
    _initArrivalListener();
    _initBanListener();
    _initRoleListener();
    _initLeaveEarlyListener();
    _initReverifyListener();
  }

  /// Loads the user's preferred theme (Dark/Light) from local storage.
  Future<void> _loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
      if (mounted) {
        setState(() {
          _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
        });
      }
    } catch (e) {
      print('[MAIN INFO] Could not load theme yet: $e');
    }
  }

  /// Listen for arrival reminders from the server via Socket.IO.
  /// Shows BOTH a native notification bar alert AND an in-app dialog.
  void _initArrivalListener() {
    _arrivalSub = SocketService.arrivalNotificationStream.listen((data) {
      // 1. Show native notification bar notification (works in background)
      final String resId = data['reservationId']?.toString() ?? '';
      final int minutes = data['minutes'] ?? 15;
      final bool isFinal = data['type'] == 'warning';
      NotificationService.showArrivalReminderNotification(
        reservationId: resId,
        minutes: minutes,
        isFinal: isFinal,
      );
      // 2. Show in-app dialog if app is in foreground
      _showArrivalDialog(data);
    });
  }

  /// Listen for account ban events.
  /// Forces the user out and displays a descriptive dialog.
  void _initBanListener() {
    _banSub = SocketService.userBannedStream.listen((data) async {
      print('[MAIN] User banned event received: $data');
      final context = IparkApp.navigatorKey.currentContext;
      if (context == null) return;

      // 1. Wipe all local data to ensure session is destroyed
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Alert the user
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.gavel, color: Colors.red, size: 48),
          title: const Text(
            "Account Banned",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Text(
            data['message'] ??
                "Your account has been banned due to policy violations. Please contact support.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Redirect to login and clear navigation stack
                IparkApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              child: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Listen for real-time role updates (e.g., promoted to admin).
  /// Updates the UI and provider state immediately.
  void _initRoleListener() {
    _roleSub = SocketService.roleUpdatedStream.listen((data) async {
      final newRole = data['role'] ?? 'user';
      print('[MAIN] Role updated event received: $newRole');

      final context = IparkApp.navigatorKey.currentContext;
      if (context == null) return;

      final provider = Provider.of<ReservationProvider>(context, listen: false);
      await provider.setUserRole(newRole);

      // Notify the user via a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Permissions updated: You are now a $newRole"),
          backgroundColor: AppTheme.primaryLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  /// Displays a warning/reminder dialog when a user has a reservation but
  /// hasn't yet verified their arrival at the spot.
  void _showArrivalDialog(Map<String, dynamic> data) {
    final context = IparkApp.navigatorKey.currentContext;
    if (context == null) return;

    final String type = data['type'] ?? 'reminder';
    final String resId = data['reservationId']?.toString() ?? '';
    final int minutes = data['minutes'] ?? 15;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              type == 'warning'
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              color: type == 'warning' ? Colors.red : AppTheme.primaryLight,
            ),
            const SizedBox(width: 10),
            Text(type == 'warning' ? "Final Warning" : "Arrival Reminder"),
          ],
        ),
        content: Text(
          "It's been $minutes minutes since your reservation started, but you haven't verified your arrival yet. Would you like to cancel this reservation?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "I'm Arriving Now",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (resId.isNotEmpty) {
                final provider = Provider.of<ReservationProvider>(
                  context,
                  listen: false,
                );
                // Trigger cancellation on backend
                await provider.updateStatus(resId, 'cancelled');

                ScaffoldMessenger.of(
                  IparkApp.navigatorKey.currentContext!,
                ).showSnackBar(
                  const SnackBar(
                    content: Text("Reservation cancelled successfully"),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Cancel Reservation",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _initLeaveEarlyListener() {
    _leaveEarlySub = SocketService.askLeaveEarlyStream.listen((data) {
      // Native push notification is already triggered in socket_service.dart
      // so we only need to handle the in-app dialog here
      _showLeaveEarlyDialog(data);
    });
  }

  void _showLeaveEarlyDialog(Map<String, dynamic> data) {
    final context = IparkApp.navigatorKey.currentContext;
    if (context == null) return;

    final String resId = data['reservationId']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.departure_board_rounded,
                        color: AppTheme.primaryLight,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Leaving Spot?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "We detected that your car has left the spot. Are you leaving early?",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (isSubmitting)
                      const CircularProgressIndicator(
                        color: AppTheme.primaryLight,
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () async {
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final provider =
                                      Provider.of<ReservationProvider>(
                                        context,
                                        listen: false,
                                      );
                                  await provider.respondToLeaveEarly(
                                    resId,
                                    true,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  // Use navigatorKey context after pop to avoid unmounted crash
                                  final navCtx = IparkApp.navigatorKey.currentContext;
                                  if (navCtx != null) {
                                    ScaffoldMessenger.of(navCtx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Spot marked as available. Thank you!",
                                        ),
                                        backgroundColor: AppTheme.primaryLight,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryLight,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "Yes, I am leaving early",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              onPressed: () async {
                                setDialogState(() => isSubmitting = true);
                                try {
                                  final provider =
                                      Provider.of<ReservationProvider>(
                                        context,
                                        listen: false,
                                      );
                                  await provider.respondToLeaveEarly(
                                    resId,
                                    false,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  // Use navigatorKey context after pop to avoid unmounted crash
                                  final navCtx = IparkApp.navigatorKey.currentContext;
                                  if (navCtx != null) {
                                    ScaffoldMessenger.of(navCtx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Your spot is still reserved. See you soon!",
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.15),
                                ),
                                foregroundColor: Colors.white.withOpacity(0.8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                "No, keep my spot reserved",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Listen for reverify_required events from the server.
  /// Shows a dialog asking the user to re-enter their plate number.
  void _initReverifyListener() {
    _reverifySub = SocketService.reverifyRequiredStream.listen((data) {
      _showReverifyDialog(data);
    });
  }

  /// Displays a dialog for the user to re-verify their vehicle plate number.
  /// Called when the sensor detected the car left but the user chose to keep the spot.
  void _showReverifyDialog(Map<String, dynamic> data) {
    final context = IparkApp.navigatorKey.currentContext;
    if (context == null) return;

    final String resId = data['reservationId']?.toString() ?? '';
    final TextEditingController plateController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) {
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.orange,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Re-verify Plate",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Your car left the spot. Enter your plate number to re-open the gate and continue your reservation.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 15,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Plate Input Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: errorText != null
                            ? Colors.red.withOpacity(0.08)
                            : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorText != null
                              ? Colors.red.withOpacity(0.8)
                              : Colors.white.withOpacity(0.1),
                          width: errorText != null ? 1.5 : 1,
                        ),
                        boxShadow: errorText != null
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: TextField(
                        controller: plateController,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                        onChanged: (_) {
                          if (errorText != null) {
                            setDialogState(() => errorText = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: "ABC-1234",
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.15),
                            letterSpacing: 2,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    if (isSubmitting)
                      const CircularProgressIndicator(color: Colors.orange)
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () async {
                            final input = plateController.text.trim();
                            if (input.isEmpty) {
                              setDialogState(
                                () => errorText =
                                    "Please enter your plate number",
                              );
                              return;
                            }
                            setDialogState(() => isSubmitting = true);
                            try {
                              final provider = Provider.of<ReservationProvider>(
                                context,
                                listen: false,
                              );
                              final result = await provider.reverifyPlate(
                                resId,
                                input,
                              );
                              if (result['success'] == true) {
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Plate verified! Gate is opening.",
                                      ),
                                      backgroundColor: AppTheme.primaryLight,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } else {
                                setDialogState(() {
                                  isSubmitting = false;
                                  errorText =
                                      result['message'] ??
                                      "Incorrect plate number";
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorText = "Verification failed. Try again.";
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            "Re-verify & Open Gate",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    // Clean up streams to prevent memory leaks
    _arrivalSub?.cancel();
    _banSub?.cancel();
    _roleSub?.cancel();
    _leaveEarlySub?.cancel();
    _reverifySub?.cancel();
    super.dispose();
  }

  /// Global toggle to switch between Light and Dark mode.
  /// Persists the choice to local storage.
  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
        prefs.setBool('isDarkMode', true);
      } else {
        _themeMode = ThemeMode.light;
        prefs.setBool('isDarkMode', false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] IparkApp.build triggered');
    return MaterialApp(
      navigatorKey: IparkApp.navigatorKey,
      title: 'iPark',
      debugShowCheckedModeBanner: false,

      // Theme Configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,

      // Performance Fix: Eliminates theme transition lag by disabling animation during swap
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.easeInOut,

      // Routing Logic
      initialRoute: widget.initialRoute,
      onGenerateRoute: AppRouter.generateRoute,

      // Global UI wrapper (e.g., for background images/gradients)
      builder: (context, child) {
        return AppBackground(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
