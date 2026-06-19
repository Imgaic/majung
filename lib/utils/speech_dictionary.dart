/// 말투 스타일에 따른 고정 문구 키 정의
enum SpeechKey {
  /// 일기 생성 로딩 메시지
  loadingDiary,

  /// 대화 종료 컨펌 타이틀
  finishConfirmTitle,

  /// 일기 제목 입력 힌트
  placeholderDiaryTitle,

  /// 일기 본문 입력 힌트
  placeholderDiaryContent,

  /// 직접 쓰기 플러그인 안내 메시지
  directWritePlaceholder,

  /// 일기 삭제 컨펌 타이틀
  deleteConfirmTitle,

  /// 활동 모음 서브 헤더 타이틀
  behaviorRecommendationSubHeader,

  /// 일기 하루 3개 제한 안내 메시지
  dailyLimitAlert,

  /// 서비스 회원 탈퇴 컨펌 타이틀
  withdrawConfirmTitle,

  /// 활동 추천 섹션 대문 타이틀
  behaviorRecommendationTitle,

  /// 직접 작성 일기 완성 컨펌 타이틀
  completeDiaryConfirmTitle,

  /// 주간 리포트 추천 활동 부연 멘트
  weeklyReportRecommendationFooter,

  /// 주간 리포트 앱바 타이틀 접미사
  weeklyReportTitleSuffix,

  /// 월간 리포트 앱바 타이틀 접미사
  monthlyReportTitleSuffix,

  /// 채팅 첫 인사 메시지
  chatGreeting,

  /// AI 응답 실패 시 폴백 메시지
  chatFallbackReply,

  /// 행동 추천 안내 메시지
  activityRecommendationPrompt,

  /// 활동 선택 후 마중이 응답
  activitySelectedReply,

  /// 활동 건너뛰기 후 마중이 응답
  activitySkippedReply,

  /// 채팅 통신 장애 에러 메시지
  chatConnectionError,

  /// 사용자의 활동 선택 말풍선 멘트
  userSelectActivity,

  /// 사용자의 활동 건너뛰기 말풍선 멘트
  userSkipActivity,
}

/// 말투 설정(존댓말/반말)에 대응하여 고정 텍스트 문구를 일괄 관리하는 사전(Dictionary) 클래스.
/// 피그마 원안의 문구 및 일관성을 유지하고, UI 내의 인라인 하드코딩 분기를 배제하여 유지보수성을 극대화합니다.
class SpeechDictionary {
  static const Map<SpeechKey, Map<bool, String>> _dictionary = {
    SpeechKey.loadingDiary: {
      true: '대화 내용을 바탕으로\n일기를 작성하고 있어요!',
      false: '대화 내용을 바탕으로\n일기를 작성하고 있어!',
    },
    SpeechKey.finishConfirmTitle: {
      true: '대화를 끝마치고\n일기를 자동 생성할까요?',
      false: '대화를 끝마치고\n일기를 자동 생성할까?',
    },
    SpeechKey.placeholderDiaryTitle: {true: '일기 제목을 써주세요', false: '일기 제목을 써줘'},
    SpeechKey.placeholderDiaryContent: {
      true: '일기 본문을 써주세요.',
      false: '일기 본문을 써줘',
    },
    SpeechKey.directWritePlaceholder: {
      true: '직접 쓰기 모드는 준비 중입니다. 대화 모드로 대화를 이어나가 주세요.',
      false: '직접 쓰기 모드는 준비 중이야. 대화 모드로 대화를 이어나가 줘.',
    },
    SpeechKey.deleteConfirmTitle: {
      true: '이 일기를 정말 삭제할까요?',
      false: '이 일기를 정말 삭제할거야?',
    },
    SpeechKey.behaviorRecommendationSubHeader: {
      true: '마음에 들었던 행동들에\n하트를 눌러주세요!',
      false: '마음에 들었던 행동들에\n하트를 눌러줘!',
    },
    SpeechKey.dailyLimitAlert: {
      true: '일기는 하루에 최대 3개까지만\n저장할 수 있어요.\n오늘의 일기 중 하나를 삭제해 주세요.',
      false: '일기는 하루에 최대 3개까지만\n저장할 수 있어.\n오늘의 일기 중 하나를 삭제해 줘.',
    },
    SpeechKey.withdrawConfirmTitle: {true: '정말 탈퇴하시겠습니까?', false: '정말 탈퇴할래?'},
    SpeechKey.behaviorRecommendationTitle: {
      true: '이런 걸 해보시는 건 어떠세요?',
      false: '이런 걸 해봐!',
    },
    SpeechKey.completeDiaryConfirmTitle: {
      true: '일기를 완성할까요?',
      false: '일기를 완성할까?',
    },
    SpeechKey.weeklyReportRecommendationFooter: {
      true: '이런 활동들을 하시면 좋을 것 같아요. 다음 주도 화이팅이에요!',
      false: '이런 활동들을 하면 좋을 거 같아. 다음 주도 화이팅이야!',
    },
    SpeechKey.weeklyReportTitleSuffix: {true: '는 어땠을까요?', false: '는 어땠을까?'},
    SpeechKey.monthlyReportTitleSuffix: {true: '은 어땠을까요?', false: '은 어땠을까?'},
    SpeechKey.chatGreeting: {
      true: '오늘 하루는 어떠셨어요?',
      false: '오늘 무슨 일 있었어?',
    },
    SpeechKey.chatFallbackReply: {
      true: '오늘 하루도 힘내세요.',
      false: '오늘 하루도 힘내자.',
    },
    SpeechKey.activityRecommendationPrompt: {
      true: '이런 행동은 어떠세요?\n기분이 바뀔지도 몰라요',
      false: '이런 행동은 어때?\n기분이 바뀔지도 몰라',
    },
    SpeechKey.activitySelectedReply: {
      true: '탁월한 선택이에요! 오늘 저녁엔 {activity} 활동을 해보세요. 한결 기분이 가벼워질 거예요.',
      false: '탁월한 선택이야! 오늘 저녁엔 {activity} 활동을 해보자. 한결 기분이 가벼워질 거야.',
    },
    SpeechKey.activitySkippedReply: {
      true: '알겠어요. 굳이 뭔가를 하지 않아도 편안히 쉬는 것도 훌륭한 해결책이에요. 오늘 푹 쉬세요!',
      false: '알겠어. 굳이 뭔가를 하지 않아도 편안히 쉬는 것도 훌륭한 해결책이야. 오늘 푹 쉬자!',
    },
    SpeechKey.chatConnectionError: {
      true: '죄송해요. 마중이와 대화 연결이 잠시 불안정해요. 잠시 후 다시 말씀해 주시겠어요?',
      false: '미안해. 마중이와 대화 연결이 잠시 불안정하네. 조금 후에 다시 얘기해 줄래?',
    },
    SpeechKey.userSelectActivity: {
      true: '{activity} 활동을 추천받아 볼게요!',
      false: '{activity} 활동을 추천받아 볼래!',
    },
    SpeechKey.userSkipActivity: {
      true: '이번에는 건너뛸게요.',
      false: '이번에는 건너뛸래.',
    },
  };

  /// 말투 스타일(존댓말 true / 반말 false)과 키를 사용하여 사전에 정의된 고정 멘트를 반환합니다.
  static String get(SpeechKey key, bool isHonorific) {
    return _dictionary[key]?[isHonorific] ?? '';
  }
}
