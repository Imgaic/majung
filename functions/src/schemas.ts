/**
 * Gemini AI가 응답해야 하는 JSON 포맷 스키마 모음
 */

export const chatMascotSchema = `{
  "reply": "마중이로서의 다음 응답 대사 (줄바꿈 가능, 절대 이모티콘 사용 금지)",
  "shouldRecommendActions": boolean (추천 활동을 보여줄 타이밍인지 여부),
  "recommendedActions": ["행동1", "행동2", "행동3"] (shouldRecommendActions가 true일 때만. 각 항목 반드시 20자 이내 명사형, 초과 절대 금지)
}`;

export const diaryFeedbackSchema = `{
  "mood": number (1~5),
  "title": "일기 제목 string",
  "content": "일기 본문 string (1인칭 '나' 관점)",
  "mascotFeedback": "마중이가 사용자에게 건네는 따뜻한 피드백 문구 (줄바꿈 가능, 절대 이모티콘 사용 금지)",
  "recommendedActions": ["추천행동1", "추천행동2", "추천행동3"]
}`;

export const homeGreetingSchema = `{
  "greeting": "인사 문구 (줄바꿈은 \\n 사용)"
}`;

export const diaryReminderSchema = `{
  "title": "알림 제목 (사용자 이름 포함, 캘린더 일정이 있다면 자연스럽게 언급하며 공감하는 1문장 질문, 예: '민수님, 오늘 학회 발표하느라 떨리진 않으셨나요?' 또는 '지혜야, 오늘 피크닉 재미있었어?')"
}`;

export function getWeeklyReportSchema(isHonorific: boolean): string {
  const style = isHonorific ? "존댓말" : "반말";
  return `{
  "oneLiner": "한 줄 요약 (${style})",
  "content": "편지 본문 (${style}, 줄바꿈 \\n, 3~5문단)",
  "signature": "편지 서명 (${style})",
  "recommendationTitle": "추천 행동 제목",
  "recommendations": ["추천행동1 (20자 이내 명사형)", "추천행동2", "추천행동3"]
}`;
}

export function getMonthlyReportSchema(isHonorific: boolean): string {
  const style = isHonorific ? "존댓말" : "반말";
  return `{
  "oneLiner": "한 줄 요약 (${style})",
  "content": "편지 본문 (${style}, 줄바꿈 \\n, 3~5문단)",
  "signature": "편지 서명 (${style})",
  "wrapUp": "마무리 멘트 (${style})",
  "weeklySummaries": [
    {"weekTitle": "이달 초", "description": "첫째 주 요약"},
    {"weekTitle": "이달 중", "description": "중간 주 요약"},
    {"weekTitle": "이달 말", "description": "마지막 주 요약"}
  ]
}`;
}
