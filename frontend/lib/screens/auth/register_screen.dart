// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../services/api_config.dart';

class RegisterScreen extends StatefulWidget {
  final String phoneNumber;

  const RegisterScreen({super.key, required this.phoneNumber});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _carPlateController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _completeRegistration() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }
    if (_nationalIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your national ID")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedPhone = widget.phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': normalizedPhone,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'nationalId': _nationalIdController.text.trim(),
          'carPlate': _carPlateController.text.trim(),
        }),
      );

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phoneNumber', normalizedPhone);
        await prefs.setString('name', _nameController.text.trim());
        await prefs.setString('email', _emailController.text.trim());
        await prefs.setString('nationalId', _nationalIdController.text.trim());
        await prefs.setString('carPlate', _carPlateController.text.trim());
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'user');
        final token = data['token'] as String?;
        if (token != null) {
           await prefs.setString('token', token);
        }

        final userId = data['user']?['_id'] as String?;
        if (userId != null) {
          await prefs.setString('userId', userId);
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Registration failed')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: "Register",
        showProfile: false,
        showBackButton: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ResponsiveWrapper(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Register Text
                  const Text(
                    "Complete Registration",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 500.ms).scale(),
  
                  const SizedBox(height: 10),
                  const Text(
                    "Please provide your details to continue",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
  
                  const SizedBox(height: 40),
  
                  // Name Field
                  _buildInputField(
                    label: "Full Name",
                    controller: _nameController,
                    icon: Icons.person,
                    hint: "Enter your full name",
                    isRequired: true,
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.2, end: 0),
  
                  const SizedBox(height: 16),
  
                  // Email Field
                  _buildInputField(
                    label: "Email Address",
                    controller: _emailController,
                    icon: Icons.email,
                    hint: "Enter your email",
                    isRequired: true,
                    keyboardType: TextInputType.emailAddress,
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.2, end: 0),
  
                  const SizedBox(height: 16),
  
                  // National ID Field
                  _buildInputField(
                    label: "National ID",
                    controller: _nationalIdController,
                    icon: Icons.sd_card,
                    hint: "Enter your national ID",
                    isRequired: true,
                    keyboardType: TextInputType.number,
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.2, end: 0),
  
                  const SizedBox(height: 16),
  
                  // Car Plate Field (Optional)
                  _buildInputField(
                    label: "Car Plate (Optional)",
                    controller: _carPlateController,
                    icon: Icons.directions_car,
                    hint: "Enter your car plate number",
                    isRequired: false,
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2, end: 0),
  
                  const SizedBox(height: 32),
  
                  // Complete Registration Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 10,
                        shadowColor: AppTheme.primaryLight.withValues(alpha: 0.5),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "COMPLETE REGISTRATION",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
  
                  const SizedBox(height: 20),
                  const Text(
                    "Smart Parking Solution",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 900.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool isRequired,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.primaryLight.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryLight.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryLight),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppTheme.primaryLight, width: 2),
          ),
        ),
      ),
    );
  }
}