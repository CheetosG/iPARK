// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  // Use same public URL as the rest of the app
  final String baseUrl = ApiConfig.baseUrl;

  // 1. Send OTP
  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Connection timed out. Please check if the server is running. [CODE: BE-NET-TIMEOUT]');
      }
      throw Exception('Failed to send OTP: $e');
    }
  }

  // 2. Verify OTP & Get User
  Future<User> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber, 'otp': otp}),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body);

      if (data['success'] || data['isNew'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phoneNumber', phoneNumber);
        await prefs.setBool('isLoggedIn', true);
        
        if (data['isNew'] == true) {
          await prefs.setString('role', 'user');
          return User(
            id: '',
            phoneNumber: phoneNumber,
            name: '',
            email: '',
            nationalId: '',
            carPlate: '',
            role: 'user',
            points: 0,
            isVerified: true,
            createdAt: DateTime.now(),
          );
        } else {
          // Existing user — save token and userId
          final token = data['token'] as String?;
          if (token != null) await prefs.setString('token', token);
          final userId = data['user']?['_id'] as String?;
          if (userId != null) await prefs.setString('userId', userId);
          await prefs.setString('role', data['user']?['role'] ?? 'user');
          return User.fromJson(data['user']);
        }
      } else {
        throw Exception('Invalid OTP');
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Connection timed out. Please check if the server is running. [CODE: BE-NET-TIMEOUT]');
      }
      throw Exception('Verification failed: $e');
    }
  }

  // 3. Register New User
  Future<User> registerUser(String phoneNumber, String name) async {
    // In a real app, you would POST to /api/auth/register
    // For this demo, we assume the verify step already created the user in DB
    // or you handle registration logic here.
    return User(
      id: '',
      phoneNumber: phoneNumber,
      name: name,
      email: '',
      nationalId: '',
      carPlate: '',
      role: 'user',
      points: 0,
      isVerified: true,
      createdAt: DateTime.now(),
    );
  }

  // 4. Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // 5. Get Current User from Local Storage
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final phoneNumber = prefs.getString('phoneNumber');
    if (phoneNumber == null) return null;
    
    // In a real app, fetch user details from API again or store full JSON
    // For demo, we return a placeholder based on stored phone
    return User(
      id: '',
      phoneNumber: phoneNumber,
      name: 'User',
      email: '',
      nationalId: '',
      carPlate: '',
      role: 'user',
      points: 0,
      isVerified: true,
      createdAt: DateTime.now(),
    );
  }
}