import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../main.dart';

class BaseApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static const Duration timeout = Duration(seconds: 30);

  Future<Map<String, String>> getHeaders({bool isJson = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      if (isJson) 'Content-Type': 'application/json',
      if (ApiConfig.shouldAddNgrokHeader) 'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  dynamic handleResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      // Check if it's an HTML response (common for server/ngrok error pages)
      if (response.body.contains('<!DOCTYPE html>') || response.body.contains('<html>')) {
        throw Exception('Server returned an error page. Please check if the backend is running correctly. [CODE: BE-NET-502]');
      }
      throw Exception('Received an invalid response from the server. [CODE: BE-DAT-001]');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String message = 'An error occurred';
    String? errorCode;
    if (body is Map) {
      if (body.containsKey('message')) message = body['message'];
      if (body.containsKey('errorCode')) errorCode = body['errorCode'];
    }

    // Attach errorCode to the message so it can be parsed later if needed
    final errorBuffer = StringBuffer(message);
    if (errorCode != null) {
      errorBuffer.write(' [CODE: $errorCode]');
    }

    switch (response.statusCode) {
      case 401:
        throw Exception('Session expired. Please login again. [CODE: BE-AUTH-401]');
      case 403:
        if (body is Map && body['isBanned'] == true) {
          // Immediate Logout for banned users
          _handleBannedUser();
          throw Exception('Your account has been banned. Please contact support. [CODE: BE-AUTH-BAN]');
        }
        throw Exception('You do not have permission to perform this action. [CODE: BE-AUTH-403]');
      case 404:
        throw Exception('$message [CODE: ${errorCode ?? 'BE-NET-404'}]');
      case 500:
        throw Exception('$message [CODE: ${errorCode ?? 'BE-SYS-500'}]');
      default:
        throw Exception(errorBuffer.toString());
    }
  }

  Future<void> _handleBannedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Use the global navigator key to force redirect to login
    final context = IparkApp.navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your account has been banned. Please contact support."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }

    IparkApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
