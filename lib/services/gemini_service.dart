import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// 파이어베이스 클라우드 펑션(Firebase Cloud Functions)을 호출하여
/// 구글 제미나이(Google Gemini) AI 피드백 및 리포트 등의 응답을 받아오는 서비스 클래스.
class GeminiService {
  
  /// 실시간 대화 응답 및 행동 추천 생성 API
  static Future<Map<String, dynamic>> chatWithMascot({
    required List<Map<String, dynamic>> messages,
    required String userName,
    required bool isHonorific,
    required List<String> todayEvents,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('chatWithMascot')
          .call({
        'messages': messages,
        'userName': userName,
        'isHonorific': isHonorific,
        'todayEvents': todayEvents,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('GeminiService: chatWithMascot Cloud Functions 에러: $e');
      rethrow;
    }
  }

  /// 대화 요약 일기 및 감정/피드백 자동 생성 API
  static Future<Map<String, dynamic>> generateDiaryAndFeedback({
    required String userName,
    required bool isHonorific,
    required List<String> todayEvents,
    required bool isDirectWrite,
    List<Map<String, dynamic>> messages = const [],
    String? selectedActivity,
    Map<String, dynamic>? directWriteData,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateDiaryAndFeedback')
          .call({
        'userName': userName,
        'isHonorific': isHonorific,
        'todayEvents': todayEvents,
        'isDirectWrite': isDirectWrite,
        'messages': messages,
        'selectedActivity': selectedActivity,
        'directWriteData': directWriteData,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('GeminiService: generateDiaryAndFeedback Cloud Functions 에러: $e');
      rethrow;
    }
  }

  /// 주간/월간 편지 리포트 생성 API
  static Future<Map<String, dynamic>> generateReport({
    required String userName,
    required bool isWeekly,
    required String dateRange,
    required List<Map<String, dynamic>> diaries,
    required bool isHonorific,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateReport')
          .call({
        'userName': userName,
        'isWeekly': isWeekly,
        'dateRange': dateRange,
        'diaries': diaries,
        'isHonorific': isHonorific,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('GeminiService: generateReport Cloud Functions 에러: $e');
      rethrow;
    }
  }

  /// 홈 화면 마중이의 따뜻한 인사말 생성 API
  static Future<Map<String, dynamic>> generateHomeGreeting({
    required String userName,
    required bool isHonorific,
    required List<String> todayEvents,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateHomeGreeting')
          .call({
        'userName': userName,
        'isHonorific': isHonorific,
        'todayEvents': todayEvents,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('GeminiService: generateHomeGreeting Cloud Functions 에러: $e');
      rethrow;
    }
  }

  /// 일기 리마인더 알림 문구 동적 생성 API
  static Future<Map<String, dynamic>> generateDiaryReminder({
    required String userName,
    required bool isHonorific,
    required List<String> todayEvents,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateDiaryReminder')
          .call({
        'userName': userName,
        'isHonorific': isHonorific,
        'todayEvents': todayEvents,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      debugPrint('GeminiService: generateDiaryReminder Cloud Functions 에러: $e');
      rethrow;
    }
  }
}
