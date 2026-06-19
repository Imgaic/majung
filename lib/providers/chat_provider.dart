import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/chat_state.dart';
import '../utils/speech_dictionary.dart';
import '../services/calendar_service.dart';
import '../services/gemini_service.dart';

/// 채팅 상태와 대화 비즈니스 로직을 처리하는 Notifier Provider입니다.
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

class ChatNotifier extends Notifier<ChatState> {
  Timer? _feedbackTimer;

  @override
  ChatState build() {
    ref.onDispose(() {
      _feedbackTimer?.cancel();
    });
    return ChatState.initial();
  }

  /// 최초 마중이 환영 인사 메시지를 추가합니다. (이미 메시지가 존재하는 경우 중복 추가 방지)
  void initChat(bool isHonorific) {
    if (state.messages.isNotEmpty) return;

    state = state.copyWith(
      messages: [
        ChatMessage(
          id: 'm_init',
          sender: MessageSender.mascot,
          content: SpeechDictionary.get(SpeechKey.chatGreeting, isHonorific),
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  /// 전송 대기 중인 이미지 경로를 업데이트합니다.
  void updateSelectedImagePath(String? path) {
    state = state.copyWith(selectedImagePath: path);
  }

  /// 채팅방 데이터를 초기 상태로 리셋합니다.
  void clear() {
    _feedbackTimer?.cancel();
    state = ChatState.initial();
  }

  /// 사용자 메시지를 전송하고 Gemini AI Mascot의 실시간 답변을 수신합니다.
  Future<void> sendMessage(
    String text, {
    required String userName,
    required bool isHonorific,
  }) async {
    final textTrim = text.trim();
    final imagePath = state.selectedImagePath;

    if (textTrim.isEmpty && imagePath == null) return;

    final userMsg = ChatMessage(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      content: textTrim,
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );

    // 메시지 추가 및 입력창/미리보기 상태 클리어, 마중이 타이핑 시작
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      selectedImagePath: null,
      isMascotTyping: true,
    );

    try {
      // 캘린더 일정 연동 조회
      final todayEvents = await CalendarService.getTodayEvents();

      final List<Map<String, dynamic>> serializedMessages = state.messages.map((m) => {
        'sender': m.sender == MessageSender.user ? 'user' : 'mascot',
        'content': m.content,
      }).toList();

      // Gemini API 대화 요청
      final resultData = await GeminiService.chatWithMascot(
        messages: serializedMessages,
        userName: userName,
        isHonorific: isHonorific,
        todayEvents: todayEvents,
      );

      final reply = resultData['reply'] as String? ?? SpeechDictionary.get(SpeechKey.chatFallbackReply, isHonorific);
      final shouldRecommend = resultData['shouldRecommendActions'] as bool? ?? false;
      final List<dynamic>? recommendedList = resultData['recommendedActions'] as List<dynamic>?;

      final List<ChatMessage> updatedMessages = [
        ...state.messages,
        ChatMessage(
          id: 'm_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.mascot,
          content: reply,
          timestamp: DateTime.now(),
        ),
      ];

      List<String> nextRecommendedActions = state.recommendedActions;

      // AI가 행동 추천을 제시하기로 판단한 경우
      if (shouldRecommend && recommendedList != null && recommendedList.isNotEmpty) {
        nextRecommendedActions = recommendedList.map((e) => e as String).toList();

        updatedMessages.add(
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}_recommend',
            sender: MessageSender.mascot,
            content: SpeechDictionary.get(SpeechKey.activityRecommendationPrompt, isHonorific),
            timestamp: DateTime.now(),
            type: MessageType.activityRecommendation,
          ),
        );
      }

      state = state.copyWith(
        messages: updatedMessages,
        recommendedActions: nextRecommendedActions,
        isMascotTyping: false,
      );
    } catch (e) {
      debugPrint('chatWithMascot error: $e');
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}_error',
            sender: MessageSender.mascot,
            content: SpeechDictionary.get(SpeechKey.chatConnectionError, isHonorific),
            timestamp: DateTime.now(),
          ),
        ],
        isMascotTyping: false,
      );
    }
  }

  /// 추천 활동을 선택했을 때 피드백 전송 및 마중이 답변 처리
  void selectActivity(String activityLabel, bool isHonorific) {
    final userMsg = ChatMessage(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      content: SpeechDictionary.get(SpeechKey.userSelectActivity, isHonorific).replaceAll('{activity}', activityLabel),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      selectedActivity: activityLabel,
      messages: [...state.messages, userMsg],
      isMascotTyping: true,
    );

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      final replyMsg = ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.mascot,
        content: SpeechDictionary.get(SpeechKey.activitySelectedReply, isHonorific).replaceAll('{activity}', activityLabel),
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, replyMsg],
        isMascotTyping: false,
      );
    });
  }

  /// 활동 추천 건너뛰기 선택 시 피드백 전송 및 마중이 답변 처리
  void skipActivity(bool isHonorific) {
    final userMsg = ChatMessage(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      content: SpeechDictionary.get(SpeechKey.userSkipActivity, isHonorific),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isMascotTyping: true,
    );

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      final replyMsg = ChatMessage(
        id: 'm_${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.mascot,
        content: SpeechDictionary.get(SpeechKey.activitySkippedReply, isHonorific),
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, replyMsg],
        isMascotTyping: false,
      );
    });
  }
}
