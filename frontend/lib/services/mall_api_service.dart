import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_api_service.dart';

class MallApiService extends BaseApiService {
  Future<List<Map<String, dynamic>>> getMalls() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/mall'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      
      final List<dynamic> data = handleResponse(response);
      final baseUrl = BaseApiService.baseUrl.replaceFirst('/api', '');
      
      return data.map((mall) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(mall);
        if (m['photoUrl'] != null && m['photoUrl'] != "" && !m['photoUrl'].toString().startsWith('http')) {
          m['photoUrl'] = "$baseUrl/${m['photoUrl']}";
        }
        return m;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching malls: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSpots(String mallId) async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/mall/$mallId/spots'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return List<Map<String, dynamic>>.from(handleResponse(response));
    } catch (e) {
      debugPrint('Error fetching spots: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSpotStatus(String mallId, String spotId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/mall/$mallId/spot/$spotId/status'),
        headers: await getHeaders(),
        body: jsonEncode({'status': status}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error updating spot status: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
