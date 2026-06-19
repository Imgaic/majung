import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { SYSTEM_INSTRUCTION, getGeminiClient, ChatMessage, getKstDateInfo } from "../config";
import { chatMascotSchema, homeGreetingSchema, diaryReminderSchema } from "../schemas";

export const chatWithMascot = functions.https.onCall(async (data, _context) => {
  const { messages, userName, isHonorific, todayEvents } = data as {
    messages: ChatMessage[];
    userName: string;
    isHonorific: boolean;
    todayEvents: string[];
  };

  if (!messages || !Array.isArray(messages)) {
    throw new functions.https.HttpsError("invalid-argument", "messages list is required.");
  }

  const ai = getGeminiClient();

  let conversationHistory = "";
  for (const msg of messages) {
    const senderName = msg.sender === "user" ? userName : "마중이";
    conversationHistory += `${senderName}: ${msg.content}\n`;
  }

  const prompt = `
${SYSTEM_INSTRUCTION}

[사용자 프로필 및 일정 컨텍스트]
- 사용자 이름: ${userName}
- 적용할 말투: ${isHonorific ? "존댓말" : "반말"}
- 오늘 기기 일정 목록: ${todayEvents && todayEvents.length > 0 ? todayEvents.join(", ") : "없음"}

[지금까지의 대화 기록]
${conversationHistory}

위 대화 기록을 바탕으로 사용자의 마지막 말에 마중이(대화 참여자)로서 공감하는 다음 한마디 대답(reply)을 생성해 주세요.
또한, 사용자와 충분한 대화(턴이 2~3회 이상 진행됨)가 이루어졌거나 대화가 잘 마무리되는 느낌이 드는 시점이라고 판단될 경우, 기분 전환을 위한 구체적이고 실천하기 쉬운 행동(활동) 3가지를 함께 추천할 시점인지 결정해 주세요.
추천 행동 작성 규칙 (절대 준수):
- 각 항목은 띄어쓰기 포함 20자 이내. 20자 초과 절대 금지.
- 반드시 명사형 어미('~하기', '~마시기', '~읽기' 등)로 마무리. 동사형 절대 금지.
- 3가지는 반드시 서로 다른 영역에서 선택 (예: 신체활동 / 창작·취미 / 휴식·감각 중 각 1개씩)
- 대화 내용과 감정 맥락을 반드시 반영한 맞춤 추천. 뻔한 추천 금지.
- 구체적이고 신선한 예시: "10분 스트레칭하기", "좋아하는 영화 보기", "낙서장에 감정 그리기", "향초 켜고 쉬기", "친구에게 안부 전하기", "새 레시피로 요리하기"

출력은 반드시 아래 스키마를 만족하는 JSON 형태여야 합니다:
${chatMascotSchema}
`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-3.1-flash-lite",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate AI response.");
  }
});

export const generateHomeGreeting = functions.https.onCall(async (data, _context) => {
  const { userName, isHonorific, todayEvents } = data as {
    userName: string;
    isHonorific: boolean;
    todayEvents: string[];
  };

  const ai = getGeminiClient();

  const styleRule = isHonorific
    ? "반드시 존댓말(~요, ~습니다, ~세요)만 사용하세요. 반말 절대 금지."
    : "반드시 반말(~야, ~어, ~잖아, ~자)만 사용하세요. 존댓말 절대 금지.";

  const eventsContext = todayEvents && todayEvents.length > 0
    ? `오늘 일정: ${todayEvents.join(", ")}`
    : "오늘 등록된 일정 없음";

  const prompt = `
${SYSTEM_INSTRUCTION}

[말투 규칙 - 최우선 적용]
${styleRule}

[사용자 정보]
- 이름: ${userName}
- ${eventsContext}

마중이로서 ${userName}에게 건네는 짧고 따뜻한 홈 화면 인사 문구를 생성해 주세요.
규칙:
- 2~3문장 이내로 짧게 작성
- 오늘 일정이 있으면 자연스럽게 언급 (없으면 일반적인 따뜻한 인사)
- 이모티콘 절대 금지
- 말투 규칙 반드시 준수

출력은 반드시 아래 JSON 형태:
${homeGreetingSchema}
`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-3.1-flash-lite",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate home greeting.");
  }
});

/**
 * 마중이로서 오늘 일정 목록과 말투에 어울리는 따뜻한 일기 작성 리마인더 제목을 Gemini를 통해 동적으로 생성합니다.
 */
async function generateReminderContent(
  userName: string,
  isHonorific: boolean,
  todayEvents: string[]
): Promise<{ title: string }> {
  const ai = getGeminiClient();

  const styleRule = isHonorific
    ? "반드시 존댓말(~요, ~습니다, ~세요)만 사용하세요. 반말 절대 금지."
    : "반드시 반말(~야, ~어, ~잖아, ~자)만 사용하세요. 존댓말 절대 금지.";

  const eventsContext = todayEvents && todayEvents.length > 0
    ? `오늘 일정: ${todayEvents.join(", ")}`
    : "오늘 등록된 일정 없음";

  const prompt = `
${SYSTEM_INSTRUCTION}

[말투 규칙 - 최우선 적용]
${styleRule}

[사용자 정보]
- 이름: ${userName}
- ${eventsContext}

마중이로서 ${userName}에게 건네는 따뜻한 일기 작성 리마인더 푸시 알림 제목을 생성해 주세요.
규칙:
- 제목(title): 사용자 이름 포함하여 오늘 하루 어땠는지 묻는 짧은 질문 (예: "민수님, 오늘 하루는 어떠셨어요?" 또는 "지혜야, 오늘 하루 어땠어?")
- 만약 오늘 일정이 기재되어 있다면, 해당 일정을 자연스럽게 언급하여 묻는 한 문장의 짧은 질문으로 작성해 주세요. (예: "민수님, 오늘 학회 발표하느라 떨리진 않으셨나요?" 또는 "지혜야, 오늘 피크닉 재미있었어?")
- 이모티콘 절대 금지
- 말투 규칙 반드시 준수

출력은 반드시 아래 JSON 형태:
${diaryReminderSchema}
`;

  const response = await ai.models.generateContent({
    model: "gemini-3.1-flash-lite",
    contents: prompt,
    config: { responseMimeType: "application/json" },
  });

  return JSON.parse(response.text ?? "");
}

export const generateDiaryReminder = functions.https.onCall(async (data, _context) => {
  const { userName, isHonorific, todayEvents } = data as {
    userName: string;
    isHonorific: boolean;
    todayEvents: string[];
  };

  try {
    const { title } = await generateReminderContent(userName, isHonorific, todayEvents);
    const body = isHonorific
      ? "마중이가 기다리고 있어요. 오늘의 이야기를 들려주세요."
      : "마중이가 기다리고 있어. 오늘 있었던 일 얘기해줘.";
    return { title, body };
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate diary reminder.");
  }
});

export const dailyDiaryReminder = functions.pubsub
  .schedule("0 20 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async (_context) => {
    const kst = getKstDateInfo();
    const today = kst.dateString;

    const usersSnapshot = await admin.firestore()
      .collection("users")
      .where("notificationEnabled", "==", true)
      .get();

    const promises = usersSnapshot.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      const fcmToken: string | undefined = userData.fcmToken;
      const userName: string = userData.name || "사용자";
      const isHonorific = (userData.selectedStyle ?? 0) !== 0;

      if (!fcmToken) return;

      const diarySnapshot = await admin.firestore()
        .collection("users").doc(uid)
        .collection("diaries")
        .where("date", ">=", today)
        .where("date", "<=", today + "\uF8FF")
        .get();

      if (!diarySnapshot.empty) return;

      const todayEvents = userData.todayEvents as string[] | undefined;
      const todayEventsDate = userData.todayEventsDate as string | undefined;
      const hasEvents = Array.isArray(todayEvents) && todayEvents.length > 0 && todayEventsDate === today;

      try {
        const { title } = await generateReminderContent(
          userName,
          isHonorific,
          hasEvents ? todayEvents! : []
        );

        const body = isHonorific
          ? "마중이가 기다리고 있어요. 오늘의 이야기를 들려주세요."
          : "마중이가 기다리고 있어. 오늘 있었던 일 얘기해줘.";

        await admin.messaging().send({
          token: fcmToken,
          notification: { title, body },
          data: { type: "daily_reminder" },
        });
      } catch (e) {
        console.error(`FCM 리마인드 발송 실패 (uid: ${uid}):`, e);
      }
    });

    await Promise.allSettled(promises);
    console.log(`dailyDiaryReminder: ${usersSnapshot.size}명 처리 완료`);
  });
