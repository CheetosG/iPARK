// lib/services/notification_service.dart
// ============================================================
// NOTIFICATION SERVICE — Shows native Android notification bar alerts.
//
// Uses flutter_local_notifications to display real system notifications
// that appear in the notification bar even when the app is in background.
//
// Notification channels used:
//   - ipark_iot     → IoT sensor alerts (leave early, overtime)
//   - ipark_arrival → Arrival reminders
// ============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // -------------------------------------------------------
  // INITIALIZE — Call once in main() before runApp
  // -------------------------------------------------------
  static Future<void> init() async {
    if (_initialized) return;

    // Android init settings: uses the app launcher icon
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels (Android 8+)
    await _createChannels();

    // Request notification permission on Android 13+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NOTIFICATION] Service initialized');
  }

  // -------------------------------------------------------
  // CHANNELS — Defines the notification appearance categories
  // -------------------------------------------------------
  static Future<void> _createChannels() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel iotChannel = AndroidNotificationChannel(
      'ipark_iot',
      'iPark IoT Alerts',
      description: 'Alerts from parking spot sensors (leave early, overtime)',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel arrivalChannel = AndroidNotificationChannel(
      'ipark_arrival',
      'iPark Arrival Reminders',
      description: 'Reminders to verify your parking spot arrival',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel adminChannel = AndroidNotificationChannel(
      'ipark_admin_alerts',
      'Admin & Support Alerts',
      description: 'Important notifications for staff (new tickets, chat messages)',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await androidPlugin?.createNotificationChannel(iotChannel);
    await androidPlugin?.createNotificationChannel(arrivalChannel);
    await androidPlugin?.createNotificationChannel(adminChannel);
  }

  // -------------------------------------------------------
  // NOTIFICATION: "Are you leaving early?"
  // Shown when IR sensor detects the car left before endTime
  // -------------------------------------------------------
  static Future<void> showLeaveEarlyNotification({
    required String reservationId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ipark_iot',
      'iPark IoT Alerts',
      channelDescription: 'Alerts from parking spot sensors',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      ticker: 'iPark Alert',
      styleInformation: BigTextStyleInformation(
        'Our sensor detected that your car has left the spot. Are you leaving early? Open the app to confirm.',
        summaryText: 'Tap to respond',
      ),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      1001, // Fixed ID so duplicate events replace each other
      '🚗 Leaving Your Spot?',
      'We detected your car left. Tap to confirm if you\'re leaving early.',
      details,
      payload: 'leave_early:$reservationId',
    );

    debugPrint('[NOTIFICATION] Leave early notification shown for res: $reservationId');
  }

  // -------------------------------------------------------
  // NOTIFICATION: Arrival reminder
  // -------------------------------------------------------
  static Future<void> showArrivalReminderNotification({
    required String reservationId,
    required int minutes,
    required bool isFinal,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ipark_arrival',
      'iPark Arrival Reminders',
      channelDescription: 'Reminders to verify your spot arrival',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(
        isFinal
            ? 'It\'s been $minutes minutes since your reservation started and you haven\'t verified arrival. Your spot may be cancelled soon!'
            : 'Your reservation started $minutes minutes ago. Please verify your arrival in the app.',
        summaryText: 'Tap to open',
      ),
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      1002,
      isFinal ? '⚠️ Final Arrival Warning' : '📍 Arrival Reminder',
      'Your reservation started $minutes min ago. Verify now!',
      details,
      payload: 'arrival:$reservationId',
    );

    debugPrint('[NOTIFICATION] Arrival reminder shown ($minutes min) for res: $reservationId');
  }

  // -------------------------------------------------------
  // NOTIFICATION: Booking Confirmation
  // -------------------------------------------------------
  static Future<void> showBookingConfirmationNotification({
    required String reservationId,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ipark_arrival', // Reusing arrival channel for booking reminders
      'iPark Arrival Reminders',
      channelDescription: 'Reminders to verify your spot arrival',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      ticker: 'iPark Booking Confirmed',
      styleInformation: BigTextStyleInformation(
        'Your reservation has been completed successfully. Please make sure to arrive 15 minutes before your scheduled start time.',
        summaryText: 'Booking Confirmed',
      ),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      1005, // unique ID
      '✅ Reservation Complete',
      'Please arrive 15 min early.',
      details,
      payload: 'booking_confirmed:$reservationId',
    );

    debugPrint('[NOTIFICATION] Booking confirmation shown for res: $reservationId');
  }

  // -------------------------------------------------------
  // NOTIFICATION: Expiration / Ending reminder
  // -------------------------------------------------------
  static Future<void> showEndingNotification({
    required String reservationId,
    required int minutes,
    required bool isExpired,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ipark_iot', // Reusing IoT channel for high-priority alerts
      'iPark IoT Alerts',
      channelDescription: 'Alerts from parking spot sensors',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      ticker: 'iPark Time Reminder',
      styleInformation: BigTextStyleInformation(
        isExpired
            ? 'Your reservation time has expired. Please move your car or you will incur overtime charges.'
            : 'Your reservation will end in $minutes minutes. Please return to your vehicle soon.',
        summaryText: isExpired ? 'Time Expired' : 'Time Ending Soon',
      ),
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      1004, // unique ID
      isExpired ? '⏳ Time Expired!' : '⏳ Time Ending Soon',
      isExpired
          ? 'Your reservation has ended.'
          : 'You have $minutes minutes left.',
      details,
      payload: 'ending:$reservationId',
    );

    debugPrint('[NOTIFICATION] Ending reminder shown ($minutes min) for res: $reservationId');
  }

  // -------------------------------------------------------
  // NOTIFICATION: Overtime alert (for user)
  // -------------------------------------------------------
  static Future<void> showOvertimeNotification({
    required String reservationId,
    required String spotLabel,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ipark_iot',
      'iPark IoT Alerts',
      channelDescription: 'Alerts from parking spot sensors',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      ticker: 'iPark Overtime',
      styleInformation: BigTextStyleInformation(
        'Your parking time has expired but your car is still in the spot. Please move your vehicle as soon as possible.',
        summaryText: 'Overtime parking',
      ),
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      1003,
      '🚨 Overtime Parking!',
      'Your reservation ended but your car is still at $spotLabel.',
      details,
      payload: 'overtime:$reservationId',
    );

    debugPrint('[NOTIFICATION] Overtime notification shown for: $spotLabel');
  }

  // -------------------------------------------------------
  // NOTIFICATION: Admin / Support Alert
  // -------------------------------------------------------
  static Future<void> showAdminAlertNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ipark_admin_alerts',
      'Admin & Support Alerts',
      channelDescription: 'Important notifications for staff',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/launcher_icon',
      ticker: 'iPark Staff Alert',
      styleInformation: BigTextStyleInformation(''), // Body will override
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // Use a unique ID based on time to avoid overwriting multiple alerts
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _plugin.show(
      notificationId,
      '🔔 $title',
      body,
      details,
      payload: 'admin_alert:$type',
    );

    debugPrint('[NOTIFICATION] Admin alert shown: $title');
  }

  // -------------------------------------------------------
  // TAP HANDLER — Called when user taps a notification
  // Currently logs the payload; extend to navigate in-app
  // -------------------------------------------------------
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NOTIFICATION] Tapped: ${response.payload}');
    // Future: navigate to the relevant screen based on payload
  }
}
