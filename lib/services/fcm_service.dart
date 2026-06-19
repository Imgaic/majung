import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../main.dart'; // isFirebaseEnabled
import 'package:flutter/material.dart';
import 'local_notification_service.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/report/report_list_screen.dart';

// FCM과 캘린더는 모바일(Android/iOS)에서만 지원
bool get _isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// 백그라운드 메시지 핸들러는 최상위 함수여야 함 (isolate 제약)
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('FCM 백그라운드: ${message.notification?.title}');
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize({
    required String uid,
    bool requestPermission = false,
  }) async {
    if (!isFirebaseEnabled) return;

    // FCM은 모바일(Android/iOS)에서만 지원
    if (!_isMobilePlatform) return;

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    bool authorized = false;
    if (requestPermission) {
      // 알림 권한 요청 (iOS / Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } else {
      // 알림 권한을 요청하지 않고 상태만 확인
      final settings = await _messaging.getNotificationSettings();
      authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }

    if (!authorized) {
      debugPrint('FCM: 알림 권한 미승인 상태 (requestPermission: $requestPermission)');
      return;
    }

    // FCM 토큰 Firestore에 저장
    await _syncToken(uid);

    // 토큰 갱신 시 자동 재동기화
    _messaging.onTokenRefresh.listen((token) => _saveToken(uid, token));

    // 포그라운드 메시지 수신 → Firestore 알림 컬렉션에 저장 및 로컬 알림 노출
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM 포그라운드: ${message.notification?.title}');
      _saveNotificationToFirestore(uid, message);

      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title != null && body != null) {
        final type = message.data['type'];
        final payload = type == 'daily_reminder' 
            ? 'diary_reminder' 
            : (type == 'weekly_report' || type == 'monthly_report' ? 'report' : null);
        
        LocalNotificationService.show(
          title: title,
          body: body,
          payload: payload,
        );
      }
    });

    // 앱이 백그라운드 상태일 때 알림을 클릭하여 연 경우
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM 백그라운드 클릭 유입: ${message.notification?.title}');
      _handleNotificationClick(message);
    });

    // 앱이 완전히 종료된 상태에서 알림을 클릭하여 시작된 경우
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('FCM 종료 상태 클릭 유입: ${message.notification?.title}');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationClick(message);
        });
      }
    });
  }

  static Future<void> _syncToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (e) {
      debugPrint('FCM: 토큰 조회 실패: $e');
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
      debugPrint('FCM: 토큰 저장 완료');
    } catch (e) {
      debugPrint('FCM: 토큰 저장 실패: $e');
    }
  }

  /// 오늘 기기 캘린더 일정을 Firestore에 동기화 (Cloud Function의 리마인더가 참조)
  static Future<void> syncTodayEvents({
    required String uid,
    required List<String> events,
  }) async {
    if (!isFirebaseEnabled || !_isMobilePlatform) return;
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final date = '${now.year}.${pad(now.month)}.${pad(now.day)}';
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'todayEvents': events,
        'todayEventsDate': date,
      }, SetOptions(merge: true));
      debugPrint('FCM: 오늘 일정 동기화 완료 (${events.length}건)');
    } catch (e) {
      debugPrint('FCM: 오늘 일정 동기화 실패: $e');
    }
  }

  // 포그라운드 FCM 메시지를 Firestore 알림 목록에 저장
  static Future<void> _saveNotificationToFirestore(
    String uid,
    RemoteMessage message,
  ) async {
    final title = message.notification?.title ?? '';
    if (title.isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final date = DateTime.now().toIso8601String().split('T').first;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .set({'id': id, 'title': title, 'date': date, 'isUnread': true});
    } catch (e) {
      debugPrint('FCM: 알림 저장 실패: $e');
    }
  }

  static void _handleNotificationClick(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'daily_reminder') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    } else if (type == 'weekly_report' || type == 'monthly_report') {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const ReportListScreen()),
      );
    }
  }
}
