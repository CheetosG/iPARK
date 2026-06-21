// lib/providers/reservation_provider.dart
// ============================================================
// RESERVATION PROVIDER — Central state manager for reservations.
// Uses Flutter's ChangeNotifier pattern so all screens that
// depend on reservation data automatically rebuild when it changes.
//
// This provider:
//   - Fetches reservations from the backend API
//   - Creates new reservations (booking flow)
//   - Updates reservation status (verify arrival, cancel, leave early)
//   - Handles plate re-verification
//   - Validates promo codes
//   - Manages navigation tab state and user role
// ============================================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/reservation_api_service.dart';
import '../services/notification_service.dart';

class ReservationProvider extends ChangeNotifier {
  // --- Dependencies ---
  final ReservationApiService _apiService = ReservationApiService();

  // --- State Variables ---
  List<Map<String, dynamic>> _reservations = [];  // All user's reservations
  bool _isLoading = false;                         // Loading spinner flag
  int _selectedTab = 0;                            // Bottom nav bar index (0=Home, 1=Activity, etc.)
  String _userRole = 'user';                       // Current user role (user/admin/support)
  String? _errorMessage;                           // Error message to show in UI

  // --- Public Getters (UI reads these) ---
  List<Map<String, dynamic>> get reservations => _reservations;
  bool get isLoading => _isLoading;
  int get selectedTab => _selectedTab;
  String get userRole => _userRole;
  String? get errorMessage => _errorMessage;

  // --- Constructor: Load role from saved preferences ---
  ReservationProvider() {
    // Defer to avoid competing with SplashScreen's SharedPreferences call
    // during startup, which can cause a deadlock on Android.
    Future.microtask(_loadInitialRole);
  }

  // Load user role from SharedPreferences (persisted across app restarts)
  Future<void> _loadInitialRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('role') ?? 'user';
      notifyListeners();
    } catch (e) {
      // Keep default 'user' role if prefs not available yet
      debugPrint('[ReservationProvider] Could not load role: $e');
    }
  }

  // Update user role (called when server emits 'role_updated' event)
  Future<void> setUserRole(String role) async {
    if (_userRole == role) return;
    _userRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', role);
    notifyListeners();
  }

  // Switch bottom navigation tab (Home/Activity/Rewards/Profile)
  void setTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // FETCH RESERVATIONS — Load all reservations from the backend
  // Called on app start, after creating/cancelling a reservation,
  // and when pull-to-refresh is triggered on the Activity screen.
  // ----------------------------------------------------------
  Future<void> fetchReservations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');
      
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 1. Fetch from backend
      final backendRes = await _apiService.getUserActivity();
      _reservations = List<Map<String, dynamic>>.from(backendRes);
      _errorMessage = null;
    } catch (e) {
      debugPrint("Error fetching reservations: $e");
      _errorMessage = "Failed to load activity. Please check your connection.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a reservation to the local list immediately (optimistic update)
  // This makes the UI feel instant before the server confirms
  void addReservation(Map<String, dynamic> reservation) {
    // Add to top of list for instant UI update
    _reservations.insert(0, reservation);
    notifyListeners();
  }

  // ----------------------------------------------------------
  // CREATE RESERVATION — Send booking request to backend
  // Called from the spots screen when user confirms a reservation.
  // On success, refreshes the full reservation list.
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.createReservation(data);
      if (response['success'] == true) {
        await fetchReservations();
        
        // Show local push notification confirming the booking
        final reservationId = response['reservation'] != null 
            ? response['reservation']['_id'] 
            : 'new_booking';
        NotificationService.showBookingConfirmationNotification(
            reservationId: reservationId.toString());

        return {'success': true, 'message': response['message'] ?? 'Success'};
      }
      return {'success': false, 'message': response['message'] ?? 'Failed to create reservation'};
    } catch (e) {
      debugPrint('[RESERVATION PROVIDER] Error: $e');
      return {'success': false, 'message': 'An unexpected error occurred: $e'};
    }
  }

  // ----------------------------------------------------------
  // UPDATE STATUS — Change reservation status (optimistic update)
  // Used for: verify arrival (→Active), cancel early, complete
  // Updates local state first for instant UI, then persists to backend.
  // ----------------------------------------------------------
  Future<void> updateStatus(String id, String newStatus) async {
    // Optimistic update
    final index = _reservations.indexWhere((r) => r['_id'] == id || r['id'] == id);
    if (index != -1) {
      _reservations[index]['status'] = newStatus;
      // If verifying arrival, the backend sets gateOpened to true. We do it locally so UI reacts instantly.
      if (newStatus.toLowerCase() == 'active') {
        _reservations[index]['gateOpened'] = true;
      }
      notifyListeners();
    }
    
    // Call API to persist change and fetch fresh data
    try {
      await _apiService.updateStatus(id, newStatus);
      await fetchReservations(); // Refresh to get the exact state (e.g. actualStartTime) from DB
    } catch (e) {
      debugPrint("Error persisting status update: $e");
    }
  }

  // ----------------------------------------------------------
  // RESPOND TO LEAVE EARLY — User answers "Are you leaving?"
  // leaveEarly=true → complete reservation, free spot
  // leaveEarly=false → close gate, require plate re-verification
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> respondToLeaveEarly(String id, bool leaveEarly) async {
    try {
      final result = await _apiService.respondToLeaveEarly(id, leaveEarly);
      if (result['success'] == true) {
        await fetchReservations();
      }
      return result;
    } catch (e) {
      debugPrint("Error responding to leave early: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  // ----------------------------------------------------------
  // RE-VERIFY PLATE — User re-enters plate to re-open the gate
  // Called after user chose "No, keeping my spot" and gate closed.
  // If plate matches → gate opens, reservation continues.
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> reverifyPlate(String id, String carPlate) async {
    try {
      final result = await _apiService.reverifyPlate(id, carPlate);
      if (result['success'] == true) {
        await fetchReservations();
      }
      return result;
    } catch (e) {
      debugPrint("Error re-verifying plate: $e");
      return {'success': false, 'message': e.toString()};
    }
  }

  // Validate a promo code (checks if it exists, is active, not used by this user)
  Future<Map<String, dynamic>> validatePromoCode(String code) async {
    return await _apiService.validatePromoCode(code);
  }

  // Manually open the gate for an active reservation
  Future<Map<String, dynamic>> openGate(String id) async {
    return await _apiService.openGate(id);
  }

  // Manually close the gate for an active reservation
  Future<Map<String, dynamic>> closeGate(String id) async {
    return await _apiService.closeGate(id);
  }
}
