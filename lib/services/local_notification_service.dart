import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../utils/calendar_service.dart';

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelReminder = 'majung_reminder';
  static const _channelTest = 'majung_test';
  static const _reminderNotifId = 1001;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _initialized = true;
  }

  static Future<void> show({required String title, required String body}) async {
    await initialize();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelTest,
        '마중 테스트 알림',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  /// 오늘 지난 캘린더 일정을 기반으로 일기 리마인더 알림을 [hour]:[minute]에 예약합니다.
  /// 이미 예약된 리마인더는 취소 후 새로 등록합니다.
  static Future<void> scheduleDiaryReminder({
    required bool isHonorific,
    int hour = 21,
    int minute = 0,
  }) async {
    await initialize();
    await _plugin.cancel(_reminderNotifId);

    final pastEvents = await CalendarService.getPastTodayEvents();

    final String title;
    final String body;

    if (pastEvents.isNotEmpty) {
      final eventName = pastEvents.first;
      title = isHonorific
          ? '오늘 $eventName 어떠셨어요?'
          : '오늘 $eventName 어땠어?';
      body = isHonorific
          ? '마중이가 이야기 듣고 싶어해요. 오늘의 이야기를 들려주세요.'
          : '마중이가 기다리고 있어. 오늘 있었던 일 얘기해줘.';
    } else {
      title = isHonorific ? '오늘 하루는 어떠셨어요?' : '오늘 하루 어땠어?';
      body = isHonorific
          ? '마중이가 기다리고 있어요. 오늘의 이야기를 들려주세요.'
          : '마중이가 기다리고 있어. 오늘 있었던 일 얘기해줘.';
    }

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelReminder,
        '일기 리마인더',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _reminderNotifId,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
