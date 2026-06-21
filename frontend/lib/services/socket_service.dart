// lib/services/socket_service.dart
// ============================================================
// SOCKET SERVICE — Manages real-time communication with the backend.
// Uses Socket.IO to receive instant notifications like:
//   - Spot color changes (green/red/yellow)
//   - Arrival reminders (15min / 30min)
//   - "Are you leaving early?" prompts from IoT sensors
//   - "Re-verify your plate" after choosing to keep spot
//   - User ban notifications
//   - Role changes (user → support)
//   - New support tickets (admin)
//   - System error alerts (admin)
//   - Mall added/updated events
//
// Each event has its own StreamController so different parts of
// the UI can independently listen for specific events.
// ============================================================

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import 'notification_service.dart';

class SocketService {
  static IO.Socket? socket;

  // Stores the userId so we can re-identify on every reconnect
  static String? _pendingUserId;

  // --- Broadcast Stream Controllers ---
  // Each controller handles one type of server event.
  // .broadcast() allows multiple listeners (e.g., multiple screens).
  
  static final _spotStatusController = StreamController<Map<String, dynamic>>.broadcast();       // Spot color changes
  static final _ticketController = StreamController<Map<String, dynamic>>.broadcast();           // New support tickets (admin)
  static final _systemErrorController = StreamController<Map<String, dynamic>>.broadcast();      // Backend/frontend errors (admin)
  static final _arrivalNotificationController = StreamController<Map<String, dynamic>>.broadcast(); // "Verify your arrival" reminders
  static final _mallController = StreamController<Map<String, dynamic>>.broadcast();             // Mall added/updated events
  static final _userBannedController = StreamController<Map<String, dynamic>>.broadcast();       // User got banned → force logout
  static final _roleUpdatedController = StreamController<Map<String, dynamic>>.broadcast();      // Role changed (user→support)
  static final _askLeaveEarlyController = StreamController<Map<String, dynamic>>.broadcast();    // IoT: car left spot, ask user
  static final _reverifyRequiredController = StreamController<Map<String, dynamic>>.broadcast(); // After keeping spot, re-verify plate

  // --- Public Streams ---
  
  static Stream<Map<String, dynamic>> get spotStatusStream => _spotStatusController.stream;
  static Stream<Map<String, dynamic>> get ticketStream => _ticketController.stream;
  static Stream<Map<String, dynamic>> get systemErrorStream => _systemErrorController.stream;
  static Stream<Map<String, dynamic>> get arrivalNotificationStream => _arrivalNotificationController.stream;
  static Stream<Map<String, dynamic>> get mallStream => _mallController.stream;
  static Stream<Map<String, dynamic>> get userBannedStream => _userBannedController.stream;
  static Stream<Map<String, dynamic>> get roleUpdatedStream => _roleUpdatedController.stream;
  static Stream<Map<String, dynamic>> get askLeaveEarlyStream => _askLeaveEarlyController.stream;
  static Stream<Map<String, dynamic>> get reverifyRequiredStream => _reverifyRequiredController.stream;

  /// Initializes the socket connection with the provided server URL.
  static void connect(String url) {
    // IMPORTANT: disableAutoConnect() so we can register all listeners
    // BEFORE the socket connects. Otherwise, if autoConnect fires first,
    // the 'identify_user' in onConnect might miss some events.
    socket = IO.io(url, IO.OptionBuilder()
      .setTransports(['websocket'])
      .setExtraHeaders({'ngrok-skip-browser-warning': 'true'})
      .disableAutoConnect()           // ← register listeners first
      .enableReconnection()
      .setReconnectionAttempts(20)
      .setReconnectionDelay(2000)
      .build()
    );

    // --- Lifecycle Callbacks ---

    socket!.onConnect((_) {
      print('[SOCKET] Connected to $url');
      // Re-identify user immediately on every connect/reconnect.
      // This is critical: the server needs the identify_user event to
      // add this socket to the user's room so targeted events (like
      // ask_leave_early) can reach this device.
      if (_pendingUserId != null) {
        print('[SOCKET] Auto-identifying user on connect: $_pendingUserId');
        socket!.emit('identify_user', {'userId': _pendingUserId});
      }
    });

    socket!.onDisconnect((_) {
      print('[SOCKET] Disconnected');
    });

    socket!.onConnectError((err) {
      print('[SOCKET] Connect Error: $err');
    });

    socket!.onReconnect((_) {
      print('[SOCKET] Reconnected! Re-identifying user...');
      if (_pendingUserId != null) {
        socket!.emit('identify_user', {'userId': _pendingUserId});
      }
    });

    // --- Socket.IO Event Listeners ---
    // Each listener receives JSON data from the server and pushes it
    // to the corresponding StreamController for the UI to consume.

    // Spot color changed (green/red/yellow) — updates the spots grid
    socket!.on('spot_status_changed', (data) {
      print('[SOCKET] spot_status_changed: $data');
      _spotStatusController.add(Map<String, dynamic>.from(data));
    });

    // New support ticket submitted by a user (admin dashboard)
    socket!.on('new_ticket', (data) {
      print('[SOCKET] new_ticket: $data');
      _ticketController.add(Map<String, dynamic>.from(data));
    });

    // Backend or frontend error occurred (admin dashboard)
    socket!.on('system_error_alert', (data) {
      print('[SOCKET] system_error_alert: $data');
      _systemErrorController.add(Map<String, dynamic>.from(data));
    });

    // "You haven't verified your arrival!" reminder (15min/30min)
    socket!.on('arrival_notification', (data) {
      print('[SOCKET] arrival_notification: $data');
      _arrivalNotificationController.add(Map<String, dynamic>.from(data));
    });

    // Ending / expiration reminder sent by backend cron job
    socket!.on('ending_notification', (data) {
      print('[SOCKET] ending_notification: $data');
      NotificationService.showEndingNotification(
        reservationId: data['reservationId']?.toString() ?? '',
        minutes: data['minutes'] ?? 0,
        isExpired: data['isExpired'] == true,
      );
    });

    // A new mall was added (refreshes home screen)
    socket!.on('mall_added', (data) {
      print('[SOCKET] mall_added: $data');
      _mallController.add(Map<String, dynamic>.from(data));
    });

    // An existing mall was updated (refreshes home screen)
    socket!.on('mall_updated', (data) {
      print('[SOCKET] mall_updated: $data');
      _mallController.add(Map<String, dynamic>.from(data));
    });

    // User has been banned → forces logout and shows ban screen
    socket!.on('user_banned', (data) {
      print('[SOCKET] user_banned: $data');
      _userBannedController.add(Map<String, dynamic>.from(data));
    });
    
    // User's role was changed by admin (e.g., user → support)
    socket!.on('role_updated', (data) {
      print('[SOCKET] role_updated: $data');
      _roleUpdatedController.add(Map<String, dynamic>.from(data));
    });

    // IoT sensor detected car left → show "Are you leaving early?" dialog
    // AND a native push notification (works even when app is in background)
    socket!.on('ask_leave_early', (data) {
      print('[SOCKET] ask_leave_early: $data');
      // Trigger native notification bar push
      NotificationService.showLeaveEarlyNotification(
        reservationId: data['reservationId']?.toString() ?? '',
      );
      // Also push to stream so in-app dialog shows when foreground
      _askLeaveEarlyController.add(Map<String, dynamic>.from(data));
    });

    // Admin/Support Push Notifications
    socket!.on('admin_support_alert', (data) {
      print('[SOCKET] admin_support_alert: $data');
      NotificationService.showAdminAlertNotification(
        title: data['title'] ?? 'Staff Alert',
        body: data['body'] ?? 'You have a new alert',
        type: data['type'] ?? 'general',
      );
    });

    // User chose "No, keeping spot" → show re-verify plate dialog
    socket!.on('reverify_required', (data) {
      print('[SOCKET] reverify_required: $data');
      _reverifyRequiredController.add(Map<String, dynamic>.from(data));
    });

    // NOW connect — all listeners are registered
    socket!.connect();
  }

  /// Associates the current socket connection with a specific user ID on the server.
  /// Saves the userId so it is re-sent automatically on every reconnect.
  static void identifyUser(String userId) {
    _pendingUserId = userId; // Always save so reconnects work
    if (socket != null && socket!.connected) {
      print('[SOCKET] Identifying user: $userId');
      socket!.emit('identify_user', {'userId': userId});
    } else {
      // Socket not ready yet — will be sent automatically in onConnect
      print('[SOCKET] Socket not ready. Will identify user on connect: $userId');
    }
  }

  /// Emits a request to update a spot's status (Admin only feature).
  static void updateSpotStatus(String spotId, String status) {
    socket?.emit('update_spot_status', {'spotId': spotId, 'status': status});
  }

  /// Closes all stream controllers and cleans up resources.
  static void dispose() {
    _spotStatusController.close();
    _ticketController.close();
    _systemErrorController.close();
    _arrivalNotificationController.close();
    _mallController.close();
    _userBannedController.close();
    _roleUpdatedController.close();
    _askLeaveEarlyController.close();
    _reverifyRequiredController.close();
  }
}

