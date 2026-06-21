// lib/services/api_config.dart
import 'dart:io';

class ApiConfig {
  // 1. SET THIS TO TRUE FOR NGROK, FALSE FOR LOCAL
  static const bool useNgrok = false;

  // 2. YOUR NGROK URL (WITHOUT /API)
  static const String ngrokUrl = 'https://cold-news-behave.loca.lt';

  // 3. YOUR LOCAL URL (DEFAULT 10.0.2.2 FOR ANDROID EMULATOR)
  // Changed to 192.168.1.2 to allow physical devices on the local WiFi network
  // to connect to the backend server.
  static String get localUrl {
    if (Platform.isAndroid) return 'http://192.168.1.2:5000';
    return 'http://192.168.1.2:5000';
  }

  // --- DERIVED URLS ---
  
  static String get baseUrl => useNgrok ? "${ngrokUrl.trim()}/api" : "$localUrl/api";
  
  static String get socketUrl => useNgrok ? ngrokUrl.trim() : localUrl;

  static bool get shouldAddNgrokHeader => useNgrok && socketUrl.contains('ngrok');
}
