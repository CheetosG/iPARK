import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_api_service.dart';
import '../models/user_model.dart';

class UserApiService extends BaseApiService {
  Future<User> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/user/profile'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      return User.fromJson(data['user']);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/user/profile'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(File imageFile) async {
    try {
      final url = Uri.parse('${BaseApiService.baseUrl}/user/profile-photo');
      final request = http.MultipartRequest('POST', url);
      
      final headers = await getHeaders(isJson: false);
      request.headers.addAll(headers);
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<List<Map<String, dynamic>>> getPointHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/user/points/history'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      return List<Map<String, dynamic>>.from(data['history']);
    } catch (e) {
      debugPrint('Error fetching points history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> exchangePoints(int amount, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/user/points/exchange'),
        headers: await getHeaders(),
        body: jsonEncode({
          'amount': amount,
          'reason': reason
        }),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error exchanging points: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> submitSupportTicket(String subject, String message) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/user/support'),
        headers: await getHeaders(),
        body: jsonEncode({'subject': subject, 'message': message}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error submitting support ticket: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getMySupportTickets() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/user/support'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      if (data != null && data['tickets'] != null) {
        return List<Map<String, dynamic>>.from(data['tickets']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching user tickets: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/chat/history'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      if (data != null && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching chat history: $e');
      return [];
    }
  }
}
