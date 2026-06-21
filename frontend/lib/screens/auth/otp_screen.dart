// lib/screens/auth/otp_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/api_config.dart';
import 'package:provider/provider.dart';
import '../../providers/reservation_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _timeLeft = 60;
  bool _canResend = false;
  Timer? _timer; // ✅ Store timer reference

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        setState(() {
          _timeLeft = 60;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = widget.phoneNumber.replaceAll(RegExp(r'[\s\-\$\$]'), '');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': normalizedPhone}),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        if (!mounted) return;
        setState(() {
          _timeLeft = 60;
          _canResend = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New OTP sent to ${widget.phoneNumber}')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend OTP: $e')),
      );
    }
  }

Future<void> _verifyAndNavigate() async {
  final otp = _otpControllers.map((controller) => controller.text).join();
  
  if (otp.length != 6) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter all 6 digits')),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final normalizedPhone = widget.phoneNumber.replaceAll(RegExp(r'[\s\-\$\$]'), '');
    
    print('[FRONTEND DEBUG] Sending OTP: $otp for phone: $normalizedPhone');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phoneNumber': normalizedPhone,
        'otp': otp,
      }),
    );

    if (!mounted) return;
    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phoneNumber', normalizedPhone);
      await prefs.setBool('isLoggedIn', true);

      final isNew = data['isNew'] as bool? ?? false;
      
      if (!mounted) return;
      if (isNew) {
        await prefs.setString('role', 'user');
        Navigator.pushReplacementNamed(
          context, 
          '/register',
          arguments: normalizedPhone,
        );
      } else {
        final role = data['user']?['role'] as String? ?? 'user';
        final token = data['token'] as String?;
        if (token != null) {
           await prefs.setString('token', token);
        }
        await prefs.setString('role', role);
        
        final userId = data['user']?['_id'] as String?;
        if (userId != null) {
          await prefs.setString('userId', userId);
        }

        // Sync role with global Provider immediately
        if (!mounted) return;
        Provider.of<ReservationProvider>(context, listen: false).setUserRole(role);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      final message = data['message'] as String? ?? 'Invalid OTP';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _onChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyAndNavigate();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  void dispose() {
    // ✅ Cancel timer before disposing
    _timer?.cancel();
    
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Verify Phone Text
                  const Text(
                    "Verify Phone",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryLight,
                    ),
                  ).animate().fadeIn(duration: 500.ms).scale(),

                  const SizedBox(height: 10),
                  Text(
                    "Enter the 6-digit code sent to ${widget.phoneNumber}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 40),

                  // 6 OTP Boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 50,
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppTheme.primaryLight,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryLight.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryLight,
                          ),
                          decoration: const InputDecoration(
                            counterText: "",
                            border: InputBorder.none,
                          ),
                          onChanged: (value) => _onChanged(index, value),
                        ).animate().fadeIn(delay: (index * 100).ms).scale(),
                      );
                    }),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 30),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndNavigate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 10,
                        shadowColor: AppTheme.primaryLight.withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "VERIFY",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 20),

                  // Resend Code Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive code? ",
                        style: TextStyle(color: Colors.grey),
                      ),
                      GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          _canResend ? "Resend Code" : "Resend in $_timeLeft s",
                          style: TextStyle(
                            color: _canResend ? AppTheme.primaryLight : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 20),
                  const Text(
                    "Smart Parking Solution",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 1000.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}