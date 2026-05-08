import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin? _notificationsPlugin =
  !kIsWeb ? FlutterLocalNotificationsPlugin() : null;

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[NotificationService] Skipping notification init on web platform');
      return;
    }

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin?.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notificationsPlugin
          ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || _notificationsPlugin == null) {
      debugPrint('[NotificationService] Notification skipped on web: $title - $body');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'community_chat_channel',
      'Community Chat Notifications',
      channelDescription: 'Notifications for community chat rooms',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin!.show(id, title, body, notificationDetails);
  }

  Future<void> scheduleMedicineNotification({
    required int id,
    required String medicineName,
    required String timeHHmm,
  }) async {
    if (kIsWeb || _notificationsPlugin == null) {
      debugPrint('[NotificationService] Medicine notification skipped on web');
      return;
    }

    final scheduledDate = tz.TZDateTime.now(tz.local).add(
      const Duration(seconds: 10),
    );

    debugPrint("Scheduling medicine notification at: $scheduledDate");

    await _notificationsPlugin!.zonedSchedule(
      id,
      'İlaç zamanı 💊',
      '$medicineName alma saatin geldi.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_channel',
          'Medicine Reminders',
          channelDescription: 'Medicine reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelMedicineNotification(int id) async {
    if (kIsWeb || _notificationsPlugin == null) return;
    await _notificationsPlugin!.cancel(id);
  }

  Future<void> sendEmailAutomatically({
    required String recipientEmail,
    required String toName,
    required String userName,
    required String message,
  }) async {
    debugPrint('[DEBUG] NotificationService: Starting sendEmailAutomatically');

    if (AppConfig.emailjsPublicKey == 'YOUR_PUBLIC_KEY' ||
        AppConfig.emailjsPublicKey.isEmpty) {
      debugPrint('[ERROR] NotificationService: EmailJS Public Key is not configured');
      return;
    }

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': AppConfig.emailjsServiceId,
          'template_id': AppConfig.emailjsTemplateId,
          'user_id': AppConfig.emailjsPublicKey,
          'template_params': {
            'to_email': recipientEmail,
            'to_name': toName,
            'user_name': userName,
            'message': message,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw 'EmailJS Error: ${response.statusCode} ${response.body}';
      }
    } catch (error) {
      debugPrint('[ERROR] NotificationService: Failed to send automatic email: $error');
      rethrow;
    }
  }

  Future<void> sendEmail({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: recipient,
      query: _encodeQueryParameters({
        'subject': subject,
        'body': body,
      }),
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      throw 'Could not launch email app';
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
    )
        .join('&');
  }
}
