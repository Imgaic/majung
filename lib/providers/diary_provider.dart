import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_service.dart';
import '../models/diary_data.dart';
import '../models/chat_message.dart';
import 'diary_list_provider.dart';
import 'activity_recommendation_provider.dart';

/// 일기 비즈니스 상태 관리 및 데이터 연산을 담당하는 Notifier 및 Provider.
class DiaryNotifier extends Notifier<DiaryData?> {
  @override
  DiaryData? build() {
    return null;
  }

  /// 대화 내역(업로드된 이미지 목록 등)과 온보딩 설정을 바탕으로 새로운 일기 생성
  Future<void> generateDiary({
    required String date,
    required List<String> imagePaths,
    required String userName,
    required bool isHonorific,
    String? selectedActivity,
    List<String> recommendedActions = const [],
    List<ChatMessage> chatMessages = const [],
    List<String> todayEvents = const [],
  }) async {
    final diaries = ref.read(diaryListProvider);
    final finalDateKey = _getAvailableDateKey(date, diaries);

    // AI API Call via Cloud Functions
    final List<Map<String, dynamic>> serializedMessages = chatMessages.map((m) => {
      'sender': m.sender == MessageSender.user ? 'user' : 'mascot',
      'content': m.content,
    }).toList();

    Map<String, dynamic> resultData;
    try {
      resultData = await GeminiService.generateDiaryAndFeedback(
        messages: serializedMessages,
        userName: userName,
        isHonorific: isHonorific,
        todayEvents: todayEvents,
        selectedActivity: selectedActivity,
        isDirectWrite: false,
      );
    } catch (e) {
      debugPrint('GeminiService generateDiary error: $e');
      throw Exception('일기 생성 중 오류가 발생했습니다: $e');
    }

    final int mood = resultData['mood'] as int? ?? 5;
    final String title = resultData['title'] as String? ?? '오늘의 일기';
    final String content = resultData['content'] as String? ?? '';
    final String mascotFeedback = resultData['mascotFeedback'] as String? ?? '';
    final List<String> generatedActions = (resultData['recommendedActions'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? recommendedActions;

    final newDiary = DiaryData(
      date: finalDateKey,
      title: title,
      content: content,
      mood: mood,
      imagePaths: imagePaths,
      mascotFeedback: mascotFeedback,
      recommendedAction: selectedActivity ?? '',
      recommendedActions: generatedActions,
    );

    state = newDiary;
    await ref.read(diaryListProvider.notifier).addOrUpdateDiary(newDiary);

    if (selectedActivity != null && selectedActivity.isNotEmpty) {
      await ref.read(activityListProvider.notifier).addActivity(selectedActivity, date: finalDateKey);
    }
  }

  /// 일기 제목, 내용, 감정 단계 및 이미지 경로를 수정할 수 있는 비즈니스 로직
  Future<void> updateDiary({
    String? title,
    String? content,
    int? mood,
    List<String>? imagePaths,
    String? recommendedAction,
    List<String>? recommendedActions,
  }) async {
    if (state != null) {
      final updated = state!.copyWith(
        title: title,
        content: content,
        mood: mood,
        imagePaths: imagePaths,
        recommendedAction: recommendedAction,
        recommendedActions: recommendedActions,
      );
      state = updated;
      await ref.read(diaryListProvider.notifier).addOrUpdateDiary(updated);

      if (recommendedAction != null && recommendedAction.isNotEmpty) {
        await ref.read(activityListProvider.notifier).addActivity(recommendedAction, date: updated.date);
      }
    }
  }

  /// 일기를 삭제하는 비즈니스 로직 (연결된 행동 추천 날짜 이력도 함께 제거)
  Future<void> deleteDiary() async {
    if (state != null) {
      final date = state!.date;
      final selectedAction = state!.recommendedAction;
      final actions = List<String>.from(state!.recommendedActions);
      state = null;
      
      await ref.read(diaryListProvider.notifier).deleteDiary(date);
      
      // 선택한 추천 활동 제거
      if (selectedAction.isNotEmpty) {
        await ref.read(activityListProvider.notifier).removeActivityDate(selectedAction, date);
      }
      
      // 추천 후보 목록들 날짜 제거 (하위 호환 및 연쇄 제거 보장)
      for (final title in actions) {
        await ref.read(activityListProvider.notifier).removeActivityDate(title, date);
      }
    }
  }

  /// 신규 일기를 저장하는 비즈니스 로직 (직접 작성 대응)
  Future<void> saveNewDiary(DiaryData diary) async {
    final diaries = ref.read(diaryListProvider);
    String finalDateKey = diary.date;
    if (!diary.date.contains('-')) {
      finalDateKey = _getAvailableDateKey(diary.date, diaries);
    }

    final newDiary = diary.copyWith(date: finalDateKey);
    state = newDiary;
    await ref.read(diaryListProvider.notifier).addOrUpdateDiary(newDiary);

    if (newDiary.recommendedAction.isNotEmpty) {
      await ref.read(activityListProvider.notifier).addActivity(newDiary.recommendedAction, date: finalDateKey);
    }
  }

  /// 이미 생성된 일기(isDirectWrite)에 대해 마중이의 답장(mascotFeedback)을 생성하여 업데이트
  Future<void> generateMascotFeedbackOnly({
    required String userName,
    required bool isHonorific,
    List<String> todayEvents = const [],
  }) async {
    if (state == null) return;

    Map<String, dynamic> resultData;
    try {
      resultData = await GeminiService.generateDiaryAndFeedback(
        userName: userName,
        isHonorific: isHonorific,
        todayEvents: todayEvents,
        isDirectWrite: true,
        directWriteData: {
          'title': state!.title,
          'content': state!.content,
          'mood': state!.mood,
        },
      );
    } catch (e) {
      debugPrint('GeminiService generateMascotFeedbackOnly error: $e');
      throw Exception('답장을 생성하는 데 실패했습니다: $e');
    }

    final String feedback = resultData['mascotFeedback'] as String? ?? '';
    final List<String> generatedActions = (resultData['recommendedActions'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? const [];

    final updated = state!.copyWith(
      mascotFeedback: feedback,
      recommendedActions: generatedActions,
    );
    state = updated;
    await ref.read(diaryListProvider.notifier).addOrUpdateDiary(updated);
  }

  /// 선택된 일기 상태를 세팅합니다 (상세 보기 진입 용도)
  void setSelectedDiary(DiaryData diary) {
    state = diary;
  }

  /// 오늘 날짜 기준 덮어쓰기 없이 사용 가능한 접미사 문서 키 탐색 (항상 가장 최신의 일기 번호를 부여)
  String _getAvailableDateKey(String baseDate, List<DiaryData> diaries) {
    final todayDiaries = diaries.where((d) => d.date.startsWith(baseDate)).toList();
    if (todayDiaries.isEmpty) {
      return baseDate;
    }

    int maxSuffix = -1;
    for (final d in todayDiaries) {
      if (d.date == baseDate) {
        if (maxSuffix < 0) maxSuffix = 0;
      } else if (d.date.startsWith('$baseDate-')) {
        final suffixStr = d.date.substring(baseDate.length + 1);
        final suffixVal = int.tryParse(suffixStr);
        if (suffixVal != null && suffixVal > maxSuffix) {
          maxSuffix = suffixVal;
        }
      }
    }

    final nextSuffix = maxSuffix + 1;
    return nextSuffix == 0 ? baseDate : '$baseDate-$nextSuffix';
  }
}

final diaryProvider = NotifierProvider<DiaryNotifier, DiaryData?>(DiaryNotifier.new);
