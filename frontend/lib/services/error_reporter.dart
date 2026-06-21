import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'api_config.dart';

class ErrorReporter {
  static final ErrorReporter instance = ErrorReporter._();
  ErrorReporter._();

  bool _isReporting = false;

  void showErrorDialog(BuildContext context, String message, {String? errorCode}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("System Message"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (errorCode != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Error Code: $errorCode",
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Dismiss"),
          ),
        ],
      ),
    );
  }

  Future<void> reportError({
    required String message,
    String? errorCode,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isReporting) return;
    _isReporting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final String url = '${ApiConfig.baseUrl}/admin/report-client-error';

      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'errorCode': errorCode ?? 'FE-GEN-001',
          'message': message,
          'stack': stackTrace,
          'metadata': {
            ...?metadata,
            'device': Platform.operatingSystem,
            'version': '1.0.0',
            'timestamp': DateTime.now().toIso8601String(),
          }
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Failed to report error to server: $e');
    } finally {
      _isReporting = false;
    }
  }
}
