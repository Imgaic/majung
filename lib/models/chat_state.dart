import 'chat_message.dart';

/// 채팅방 화면의 UI 상태와 데이터 모델을 나타내는 불변(Immutable) 상태 클래스입니다.
class ChatState {
  /// 현재까지의 대화 메시지 리스트
  final List<ChatMessage> messages;

  /// 마중이의 AI 응답 생성 중(타이핑 중) 상태 여부
  final bool isMascotTyping;

  /// 사용자가 첨부하여 전송 대기 중인 이미지 파일 경로
  final String? selectedImagePath;

  /// 사용자가 기분전환으로 선택한 추천 활동 라벨
  final String? selectedActivity;

  /// 현재 대화 단계에서 제시된 기분전환 추천 활동 리스트
  final List<String> recommendedActions;

  const ChatState({
    required this.messages,
    this.isMascotTyping = false,
    this.selectedImagePath,
    this.selectedActivity,
    this.recommendedActions = const [
      '좋아하는 노래 들으며 산책하기',
      '따뜻한 물로 샤워하기',
      '따뜻한 차 한 잔 마시기',
    ],
  });

  /// 초기 기본 상태 객체를 반환합니다.
  factory ChatState.initial() {
    return const ChatState(
      messages: [],
      isMascotTyping: false,
      selectedImagePath: null,
      selectedActivity: null,
      recommendedActions: [
        '좋아하는 노래 들으며 산책하기',
        '따뜻한 물로 샤워하기',
        '따뜻한 차 한 잔 마시기',
      ],
    );
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isMascotTyping,
    String? selectedImagePath,
    String? selectedActivity,
    List<String>? recommendedActions,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isMascotTyping: isMascotTyping ?? this.isMascotTyping,
      selectedImagePath: selectedImagePath ?? this.selectedImagePath,
      selectedActivity: selectedActivity ?? this.selectedActivity,
      recommendedActions: recommendedActions ?? this.recommendedActions,
    );
  }
}
