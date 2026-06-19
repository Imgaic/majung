import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import '../main.dart'; // navigatorKey
import '../screens/chat/chat_screen.dart';
import '../screens/report/report_list_screen.dart';

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelTest = 'majung_test';
  static const _reminderNotifId = 1001;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == 'diary_reminder') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        } else if (payload == 'report') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const ReportListScreen()),
          );
        }
      },
    );
    _initialized = true;
  }

  static Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelTest,
        '마중 테스트 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }



  /// 예약된 일기 리마인더 알림을 취소합니다.
  static Future<void> cancelDiaryReminder() async {
    await initialize();
    await _plugin.cancel(_reminderNotifId);
  }
}
