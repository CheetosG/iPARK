import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'base_api_service.dart';

class AdminApiService extends BaseApiService {
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/admin/stats'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> addMall(Map<String, dynamic> data, {File? imageFile}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('${BaseApiService.baseUrl}/admin/add-mall'));
      request.headers.addAll(await getHeaders(isJson: false));
      
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('mallPhoto', imageFile.path));
      }
      
      final streamedResponse = await request.send().timeout(BaseApiService.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error adding mall: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> updateMall(String mallId, Map<String, dynamic> data, {File? imageFile}) async {
    try {
      // Note: Some servers/proxies might have issues with Multipart + PATCH, 
      // but standard Express with multer should handle it.
      var request = http.MultipartRequest('PATCH', Uri.parse('${BaseApiService.baseUrl}/admin/mall/$mallId'));
      request.headers.addAll(await getHeaders(isJson: false));
      
      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('mallPhoto', imageFile.path));
      }
      
      final streamedResponse = await request.send().timeout(BaseApiService.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error updating mall: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> addSupport(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/admin/add-support'),
        headers: await getHeaders(),
        body: jsonEncode({'phoneNumber': phoneNumber}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error adding support: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> createPromoCode(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/admin/create-promo'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error creating promo: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      debugPrint('Fetching all users from: ${BaseApiService.baseUrl}/admin/users');
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/admin/users'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      
      debugPrint('GetUsers response code: ${response.statusCode}');
      final data = handleResponse(response);
      
      if (data != null && data['users'] != null) {
        return List<Map<String, dynamic>>.from(data['users']);
      }
      return [];
    } catch (e) {
      debugPrint('Critical Error in getAllUsers: $e');
      rethrow; // Rethrow to handle it in UI
    }
  }

  Future<Map<String, dynamic>> getUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/admin/users/$userId'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      if (data != null && data['user'] != null) {
        return Map<String, dynamic>.from(data['user']);
      }
      return {};
    } catch (e) {
      debugPrint('Error fetching single user: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getUserReservations(String userId) async {
    try {
      debugPrint('Fetching user reservations for: $userId');
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/admin/users/$userId/history'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      
      debugPrint('GetUserReservations code: ${response.statusCode}');
      final data = handleResponse(response);
      
      if (data != null && data['reservations'] != null) {
        return List<Map<String, dynamic>>.from(data['reservations']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching user reservations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> toggleBanStatus(String userId) async {
    try {
      final response = await http.patch(
        Uri.parse('${BaseApiService.baseUrl}/admin/users/$userId/ban'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error toggling ban: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserRole(String userId, String role) async {
    try {
      final response = await http.patch(
        Uri.parse('${BaseApiService.baseUrl}/admin/users/$userId/role'),
        headers: await getHeaders(),
        body: jsonEncode({'role': role}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error updating role: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getSupportTickets() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/admin/messages'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      if (data != null && data['messages'] != null) {
        return List<Map<String, dynamic>>.from(data['messages']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching support tickets: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> resolveTicket(String ticketId, String responseText) async {
    try {
      final response = await http.patch(
        Uri.parse('${BaseApiService.baseUrl}/admin/messages/$ticketId'),
        headers: await getHeaders(),
        body: jsonEncode({'response': responseText}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error resolving ticket: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getChatConversations() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/chat/admin/conversations'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      if (data != null && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching chat conversations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAdminChatHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/chat/admin/history/$userId'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      final data = handleResponse(response);
      if (data != null && data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching admin chat history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> endChatSession(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/chat/admin/end-session/$userId'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error ending chat session: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
