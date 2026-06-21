// lib/services/reservation_api_service.dart
// ============================================================
// RESERVATION API SERVICE — HTTP client for reservation endpoints.
// Makes REST API calls to the Node.js backend for:
//   - Creating reservations (booking a spot)
//   - Fetching user activity (reservation history)
//   - Updating reservation status (verify arrival)
//   - Responding to "leave early" prompts
//   - Re-verifying plate numbers
//   - Validating promo codes
//
// Extends BaseApiService for shared auth headers and response parsing.
// ============================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'base_api_service.dart';

class ReservationApiService extends BaseApiService {
  // ----------------------------------------------------------
  // CREATE RESERVATION — Book a parking spot
  // POST /api/reservation
  // Sends: { spotId, mallId, carPlate, startTime, endTime, promoCode? }
  // Returns: { success, reservation, amount }
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> createReservation(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/reservation'),
        headers: await getHeaders(),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error creating reservation: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ----------------------------------------------------------
  // GET USER ACTIVITY — Fetch all reservations for the logged-in user
  // GET /api/reservation/my-activity
  // Returns: List of reservation objects (with mall name, spot number)
  // ----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getUserActivity() async {
    try {
      final response = await http.get(
        Uri.parse('${BaseApiService.baseUrl}/reservation/activity'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return List<Map<String, dynamic>>.from(handleResponse(response));
    } catch (e) {
      debugPrint('Error fetching activity: $e');
      return [];
    }
  }

  // ----------------------------------------------------------
  // UPDATE STATUS — Change reservation status (verify arrival, cancel)
  // PUT /api/reservation/:id/status
  // Sends: { status: "Active" | "Cancelled Early" | "Completed" }
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/reservation/$id/status'),
        headers: await getHeaders(),
        body: jsonEncode({'status': status}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error updating status: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ----------------------------------------------------------
  // RESPOND TO LEAVE EARLY — Answer "Are you leaving?" prompt
  // PUT /api/reservation/:id/leave-early
  // Sends: { leaveEarly: true | false }
  // true  → complete reservation, free spot
  // false → close gate, require plate re-verification
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> respondToLeaveEarly(String id, bool leaveEarly) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/reservation/$id/leave-early'),
        headers: await getHeaders(),
        body: jsonEncode({'leaveEarly': leaveEarly}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error responding to leave early: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ----------------------------------------------------------
  // RE-VERIFY PLATE — Re-enter plate to open gate after keeping spot
  // PUT /api/reservation/:id/reverify
  // Sends: { carPlate: "ABC1234" }
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> reverifyPlate(String id, String carPlate) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/reservation/$id/reverify'),
        headers: await getHeaders(),
        body: jsonEncode({'carPlate': carPlate}),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error re-verifying plate: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ----------------------------------------------------------
  // VALIDATE PROMO CODE — Check if a promo code is valid before booking
  // POST /api/reservation/validate-promo
  // Sends: { code: "SUMMER25" }
  // Returns: { success, discount, message }
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> validatePromoCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${BaseApiService.baseUrl}/reservation/validate-promo'),
        headers: await getHeaders(),
        body: jsonEncode({'code': code}),
      ).timeout(const Duration(seconds: 10));
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error validating promo: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ----------------------------------------------------------
  // OPEN GATE — Manually open the gate for an active reservation
  // PUT /api/reservation/:id/open-gate
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> openGate(String id) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/reservation/$id/open-gate'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error manually opening gate: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // ----------------------------------------------------------
  // CLOSE GATE — Manually close the gate for an active reservation
  // PUT /api/reservation/:id/close-gate
  // ----------------------------------------------------------
  Future<Map<String, dynamic>> closeGate(String id) async {
    try {
      final response = await http.put(
        Uri.parse('${BaseApiService.baseUrl}/reservation/$id/close-gate'),
        headers: await getHeaders(),
      ).timeout(BaseApiService.timeout);
      return handleResponse(response);
    } catch (e) {
      debugPrint('Error manually closing gate: $e');
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }
}
