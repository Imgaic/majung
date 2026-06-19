import * as functions from "firebase-functions/v1";
import { SYSTEM_INSTRUCTION, getGeminiClient, ChatMessage } from "../config";
import { diaryFeedbackSchema } from "../schemas";

export const generateDiaryAndFeedback = functions.https.onCall(async (data, _context) => {
  const {
    messages,
    userName,
    isHonorific,
    todayEvents,
    selectedActivity,
    isDirectWrite,
    directWriteData,
  } = data as {
    messages?: ChatMessage[];
    userName: string;
    isHonorific: boolean;
    todayEvents: string[];
    selectedActivity?: string;
    isDirectWrite: boolean;
    directWriteData?: { title: string; content: string; mood: number };
  };

  const ai = getGeminiClient();
  let prompt = "";

  if (isDirectWrite) {
    if (!directWriteData) {
      throw new functions.https.HttpsError("invalid-argument", "directWriteData is required when isDirectWrite is true.");
    }
    prompt = `
${SYSTEM_INSTRUCTION}

[사용자 프로필 및 일정 컨텍스트]
- 사용자 이름: ${userName}
- 적용할 말투: ${isHonorific ? "존댓말" : "반말"}
- 오늘 기기 일정 목록: ${todayEvents && todayEvents.length > 0 ? todayEvents.join(", ") : "없음"}

[사용자가 직접 작성한 일기 데이터]
- 감정 단계: ${directWriteData.mood} (1: 아주 좋음 ~ 5: 아주 나쁨)
- 제목: ${directWriteData.title}
- 내용: ${directWriteData.content}

위 일기 내용(제목, 본문, 감정)을 면밀히 분석하여, 사용자의 감정에 공감하고 조언을 건네는 따뜻한 마중이의 답장(mascotFeedback)과 기분 전환에 도움이 될만한 3가지 추천 행동 목록(recommendedActions)을 생성해 주세요.
추천 행동 작성 규칙 (반드시 준수):
- 각 항목은 띄어쓰기 포함 15자 이내로 작성
- 반드시 명사형 어미('~하기', '~마시기', '~산책하기', '~읽기' 등)로 마무리
- 동사형 문장('~하세요', '~해봐', '~해보세요') 사용 절대 금지
- 올바른 예시: "가벼운 산책하기", "좋아하는 음악 듣기", "따뜻한 차 마시기"

출력은 반드시 아래 스키마를 만족하는 JSON 형태여야 합니다:
${diaryFeedbackSchema}
`;
  } else {
    if (!messages || !Array.isArray(messages)) {
      throw new functions.https.HttpsError("invalid-argument", "messages list is required.");
    }
    let conversationHistory = "";
    for (const msg of messages) {
      const senderName = msg.sender === "user" ? userName : "마중이";
      conversationHistory += `${senderName}: ${msg.content}\n`;
    }

    prompt = `
${SYSTEM_INSTRUCTION}

[사용자 프로필 및 일정 컨텍스트]
- 사용자 이름: ${userName}
- 적용할 말투: ${isHonorific ? "존댓말" : "반말"}
- 오늘 기기 일정 목록: ${todayEvents && todayEvents.length > 0 ? todayEvents.join(", ") : "없음"}
- 사용자가 선택하여 실천하기로 한 추천 행동: ${selectedActivity || "없음"}

[나눈 대화 기록]
${conversationHistory}

위 대화 기록을 기반으로 아래 항목들을 생성해 주세요:
1. 사용자의 하루를 마중이 관점이 아닌, 사용자 1인칭 '나' 시점의 솔직하고 담백한 일기 본문(content)으로 재구성해 주세요.
2. 일기 본문에 잘 어울리는 감성적인 일기 제목(title)을 정해 주세요.
3. 대화 속 사용자의 감정 상태를 종합 진단하여 감정 단계(mood: 1~5 정수)를 결정해 주세요.
   - mood 기준: 1=아주 좋음, 2=좋음, 3=보통, 4=나쁨, 5=아주 나쁨
4. 마중이로서 대화를 마무리하며 사용자에게 건네는 따뜻한 답장 피드백(mascotFeedback)을 작성해 주세요.
5. 추천 행동(recommendedActions) 작성 규칙:
   - 각 항목은 띄어쓰기 포함 15자 이내
   - 반드시 명사형 어미로 마무리
   - 동사형 문장 사용 절대 금지

출력은 반드시 아래 스키마를 만족하는 JSON 형태여야 합니다:
${diaryFeedbackSchema}
`;
  }

  try {
    const response = await ai.models.generateContent({
      model: "gemini-3.1-flash-lite",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate diary and feedback.");
  }
});
