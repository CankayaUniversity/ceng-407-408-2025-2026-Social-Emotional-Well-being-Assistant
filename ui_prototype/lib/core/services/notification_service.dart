import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin? _notificationsPlugin =
      !kIsWeb ? FlutterLocalNotificationsPlugin() : null;

  Future<void> init() async {
    // Skip notification initialization on web
    if (kIsWeb) {
      print('[NotificationService] Skipping notification init on web platform');
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin?.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Bildirime tıklandığında yapılacak işlemler buraya gelebilir
      },
    );

    // Android 13+ için izin iste
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notificationsPlugin
          ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Skip notifications on web
    if (kIsWeb || _notificationsPlugin == null) {
      print('[NotificationService] Notification skipped on web: $title - $body');
      return;
    }

    final plugin = _notificationsPlugin;

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

    await plugin.show(id, title, body, notificationDetails);
  }

  Future<void> sendEmailAutomatically({
    required String recipientEmail,
    required String toName,
    required String userName,
    required String message,
  }) async {
    print('[DEBUG] NotificationService: Starting sendEmailAutomatically');
    print('[DEBUG] NotificationService: Recipient: $recipientEmail');
    print('[DEBUG] NotificationService: ToName: $toName, UserName: $userName');
    print('[DEBUG] NotificationService: ServiceID: ${AppConfig.emailjsServiceId}');
    print('[DEBUG] NotificationService: TemplateID: ${AppConfig.emailjsTemplateId}');
    print('[DEBUG] NotificationService: PublicKey exists: ${AppConfig.emailjsPublicKey.isNotEmpty}');

    if (AppConfig.emailjsPublicKey == 'YOUR_PUBLIC_KEY' || AppConfig.emailjsPublicKey.isEmpty) {
      print('[ERROR] NotificationService: EmailJS Public Key is not configured in AppConfig.dart');
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

      print('[DEBUG] NotificationService: EmailJS Response Status: ${response.statusCode}');
      print('[DEBUG] NotificationService: EmailJS Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw 'EmailJS Error: ${response.statusCode} ${response.body}';
      }
    } catch (error) {
      print('[ERROR] NotificationService: Failed to send automatic email: $error');
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
      query: _encodeQueryParameters(<String, String>{
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
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}