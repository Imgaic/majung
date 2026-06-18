import * as functions from "firebase-functions/v1";
import { GoogleGenAI } from "@google/genai";
import * as admin from "firebase-admin";

admin.initializeApp();

function getGeminiClient(): GoogleGenAI {
  return new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY ?? "" });
}

const SYSTEM_INSTRUCTION = `
당신은 감정 일기 도우미 캐릭터 '마중이'입니다. 당신은 사용자와 친근하고 따뜻하게 대화하며 공감해주고, 대화 내용을 요약해 일기로 만들고 하루의 피드백을 주며, 사용자 기분 전환에 도움이 될 만한 3가지 구체적인 활동(Recommended Actions)을 추천합니다.

대화 및 피드백 작성 시 아래 규칙을 반드시 준수하세요:
1. 어떠한 경우에도 이모티콘(예: 😊, 🌿, 🧺 등)을 절대 사용하지 마세요. 오직 정갈한 한국어 텍스트와 적절한 줄바꿈(\\n)만 사용하여 따뜻한 감정을 전달하세요.
2. 유저가 선택한 말투에 맞게 100% 존댓말(isHonorific이 true인 경우) 또는 100% 반말(isHonorific이 false인 경우)을 일관되게 사용하세요.
   - 존댓말(isHonorific=true): 문장 끝을 반드시 ~요, ~습니다, ~세요, ~겠어요 등으로 끝내세요. ~야, ~어, ~잖아, ~자 등 반말 어미 절대 사용 금지.
   - 반말(isHonorific=false): 문장 끝을 반드시 ~야, ~어, ~잖아, ~자, ~네, ~거야 등으로 끝내세요. ~요, ~습니다, ~세요 등 존댓말 어미 절대 사용 금지.
   - 존댓말 예시: "오늘 하루도 참 고생 많으셨어요. 힘든 일은 털어버리고 푹 쉬시길 바랄게요."
   - 반말 예시: "오늘 하루도 정말 고생 많았어. 힘든 일은 다 털어버리고 푹 쉬자."
3. 오늘 일정 목록(todayEvents)이 제공되고 비어있지 않다면, 대화 중이나 피드백 중에 해당 일정을 자연스럽게 언급하여 상황 맞춤 공감을 작성해 주세요. (예: "오늘 면접 있으셨던데 보시느라 많이 긴장되셨을 것 같아요." 또는 "오늘 PT 발표하느라 애썼어.")
`;

interface ChatMessage {
  sender: "user" | "mascot";
  content: string;
}

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
{
  "reply": "마중이로서의 다음 응답 대사 (줄바꿈 가능, 절대 이모티콘 사용 금지)",
  "shouldRecommendActions": boolean (추천 활동을 보여줄 타이밍인지 여부),
  "recommendedActions": ["행동1", "행동2", "행동3"] (shouldRecommendActions가 true일 때만. 각 항목 반드시 20자 이내 명사형, 초과 절대 금지)
}
`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-2.0-flash",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate AI response.");
  }
});

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
{
  "mood": ${directWriteData.mood},
  "title": "${directWriteData.title}",
  "content": "${directWriteData.content}",
  "mascotFeedback": "마중이가 사용자에게 건네는 따뜻한 위로와 피드백 문구 (줄바꿈 가능, 절대 이모티콘 사용 금지)",
  "recommendedActions": ["추천행동1", "추천행동2", "추천행동3"]
}
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
{
  "mood": number (1~5),
  "title": "일기 제목 string",
  "content": "일기 본문 string (1인칭 '나' 관점)",
  "mascotFeedback": "마중이가 사용자에게 건네는 따뜻한 피드백 문구 (줄바꿈 가능, 절대 이모티콘 사용 금지)",
  "recommendedActions": ["추천행동1", "추천행동2", "추천행동3"]
}
`;
  }

  try {
    const response = await ai.models.generateContent({
      model: "gemini-2.0-flash",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate diary and feedback.");
  }
});

export const generateReport = functions.https.onCall(async (data, _context) => {
  const { userName, isWeekly, dateRange, diaries } = data as {
    userName: string;
    isWeekly: boolean;
    dateRange: string;
    diaries: Array<{ date: string; title: string; content: string; mood: number }>;
  };

  const ai = getGeminiClient();
  const reportType = isWeekly ? "주간" : "월간";
  const diaryText = diaries.map((d) => `[${d.date}] 감정:${d.mood} 제목:${d.title}\n${d.content}`).join("\n\n");

  const weeklySchema = `{
  "title": "${reportType} 편지 제목",
  "oneLiner_honorific": "한 줄 요약 (존댓말)",
  "oneLiner_casual": "한 줄 요약 (반말)",
  "content_honorific": "편지 본문 (존댓말, 줄바꿈 \\n, 3~5문단)",
  "content_casual": "편지 본문 (반말, 줄바꿈 \\n, 3~5문단)",
  "signature_honorific": "편지 서명 (존댓말)",
  "signature_casual": "편지 서명 (반말)",
  "recommendationTitle": "추천 행동 제목",
  "recommendations": ["추천행동1 (20자 이내 명사형)", "추천행동2", "추천행동3"]
}`;

  const monthlySchema = `{
  "title": "${reportType} 편지 제목",
  "oneLiner_honorific": "한 줄 요약 (존댓말)",
  "oneLiner_casual": "한 줄 요약 (반말)",
  "content_honorific": "편지 본문 (존댓말, 줄바꿈 \\n, 3~5문단)",
  "content_casual": "편지 본문 (반말, 줄바꿈 \\n, 3~5문단)",
  "signature_honorific": "편지 서명 (존댓말)",
  "signature_casual": "편지 서명 (반말)",
  "wrapUp_honorific": "마무리 멘트 (존댓말)",
  "wrapUp_casual": "마무리 멘트 (반말)",
  "weeklySummaries": [
    {"weekTitle": "이달 초", "description": "첫째 주 요약"},
    {"weekTitle": "이달 중", "description": "중간 주 요약"},
    {"weekTitle": "이달 말", "description": "마지막 주 요약"}
  ]
}`;

  const prompt = `
${SYSTEM_INSTRUCTION}

[사용자 이름: ${userName}]
[기간: ${dateRange}]
[일기 목록]
${diaryText || "이 기간에 작성된 일기가 없습니다."}

위 일기들을 바탕으로 ${userName}에게 보내는 따뜻한 ${reportType} 편지 리포트를 생성해주세요.
이모티콘 절대 금지. 존댓말/반말 버전을 모두 작성하세요.

출력은 반드시 아래 JSON 형태:
${isWeekly ? weeklySchema : monthlySchema}
`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-2.0-flash",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate report.");
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
{
  "greeting": "인사 문구 (줄바꿈은 \\n 사용)"
}
`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-2.0-flash",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate home greeting.");
  }
});

export const scheduledWeeklyReport = functions.pubsub
  .schedule("0 0 * * 1")
  .timeZone("Asia/Seoul")
  .onRun(async (_context) => {
    const ai = getGeminiClient();
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, "0");

    const to = new Date(now);
    to.setDate(to.getDate() - 1);
    const from = new Date(to);
    from.setDate(from.getDate() - 6);

    const fmt = (d: Date) => `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())}`;
    const dateRange = `${fmt(from)} ~ ${fmt(to)}`;
    const fromStr = fmt(from);
    const toStr = fmt(to);

    const usersSnapshot = await admin.firestore().collection("users").get();

    await Promise.allSettled(usersSnapshot.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      const userName: string = userData.name || "사용자";

      const diarySnapshot = await admin.firestore()
        .collection("users").doc(uid)
        .collection("diaries")
        .where("date", ">=", fromStr)
        .where("date", "<=", toStr)
        .get();

      if (diarySnapshot.empty) return;

      const diaries = diarySnapshot.docs.map((d) => d.data());
      const diaryText = diaries.map((d) => `[${d.date}] 감정:${d.mood} 제목:${d.title}\n${d.content}`).join("\n\n");

      const prompt = `
${SYSTEM_INSTRUCTION}
[사용자: ${userName}] [기간: ${dateRange}]
[일기 목록]
${diaryText}

위 일기를 바탕으로 따뜻한 주간 편지 리포트를 JSON으로 생성. 이모티콘 금지.
{
  "title": "주간 편지 제목",
  "oneLiner_honorific": "한 줄 요약 (존댓말)",
  "oneLiner_casual": "한 줄 요약 (반말)",
  "content_honorific": "편지 본문 (존댓말, \\n 줄바꿈)",
  "content_casual": "편지 본문 (반말, \\n 줄바꿈)",
  "signature_honorific": "서명 (존댓말)",
  "signature_casual": "서명 (반말)",
  "recommendationTitle": "추천 제목",
  "recommendations": ["추천1 (20자 이내 명사형)", "추천2", "추천3"]
}`;

      try {
        const response = await ai.models.generateContent({
          model: "gemini-2.0-flash",
          contents: prompt,
          config: { responseMimeType: "application/json" },
        });
        const result = JSON.parse(response.text ?? "");
        const reportId = `weekly_${fromStr.replace(/\./g, "")}`;

        await admin.firestore()
          .collection("users").doc(uid)
          .collection("reports").doc(reportId)
          .set({
            id: reportId,
            title: result.title,
            dateRange,
            isWeekly: true,
            isRead: false,
            isNew: true,
            oneLiner: { true: result.oneLiner_honorific, false: result.oneLiner_casual },
            content: { true: result.content_honorific, false: result.content_casual },
            signature: { true: result.signature_honorific, false: result.signature_casual },
            recommendationTitle: result.recommendationTitle,
            recommendations: result.recommendations,
          });
      } catch (e) {
        console.error(`주간 리포트 생성 실패: uid=${uid}`, e);
      }
    }));
  });

export const scheduledMonthlyReport = functions.pubsub
  .schedule("0 0 1 * *")
  .timeZone("Asia/Seoul")
  .onRun(async (_context) => {
    const ai = getGeminiClient();
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, "0");

    const firstOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastOfLastMonth = new Date(firstOfThisMonth.getTime() - 86400000);
    const firstOfLastMonth = new Date(lastOfLastMonth.getFullYear(), lastOfLastMonth.getMonth(), 1);

    const fmt = (d: Date) => `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())}`;
    const fromStr = fmt(firstOfLastMonth);
    const toStr = fmt(lastOfLastMonth);
    const dateRange = `${fromStr} ~ ${toStr}`;
    const monthLabel = `${lastOfLastMonth.getFullYear()}년 ${lastOfLastMonth.getMonth() + 1}월`;

    const usersSnapshot = await admin.firestore().collection("users").get();

    await Promise.allSettled(usersSnapshot.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      const userName: string = userData.name || "사용자";

      const diarySnapshot = await admin.firestore()
        .collection("users").doc(uid)
        .collection("diaries")
        .where("date", ">=", fromStr)
        .where("date", "<=", toStr)
        .get();

      if (diarySnapshot.empty) return;

      const diaries = diarySnapshot.docs.map((d) => d.data());
      const diaryText = diaries.map((d) => `[${d.date}] 감정:${d.mood} 제목:${d.title}\n${d.content}`).join("\n\n");

      const prompt = `
${SYSTEM_INSTRUCTION}
[사용자: ${userName}] [기간: ${monthLabel}]
[일기 목록]
${diaryText}

위 일기를 바탕으로 따뜻한 월간 편지 리포트를 JSON으로 생성. 이모티콘 금지.
{
  "title": "월간 편지 제목",
  "oneLiner_honorific": "한 줄 요약 (존댓말)",
  "oneLiner_casual": "한 줄 요약 (반말)",
  "content_honorific": "편지 본문 (존댓말, \\n 줄바꿈)",
  "content_casual": "편지 본문 (반말, \\n 줄바꿈)",
  "signature_honorific": "서명 (존댓말)",
  "signature_casual": "서명 (반말)",
  "wrapUp_honorific": "마무리 멘트 (존댓말)",
  "wrapUp_casual": "마무리 멘트 (반말)",
  "weeklySummaries": [
    {"weekTitle": "이달 초", "description": "첫째 주 요약"},
    {"weekTitle": "이달 중", "description": "중간 주 요약"},
    {"weekTitle": "이달 말", "description": "마지막 주 요약"}
  ]
}`;

      try {
        const response = await ai.models.generateContent({
          model: "gemini-2.0-flash",
          contents: prompt,
          config: { responseMimeType: "application/json" },
        });
        const result = JSON.parse(response.text ?? "");
        const reportId = `monthly_${lastOfLastMonth.getFullYear()}${pad(lastOfLastMonth.getMonth() + 1)}`;

        await admin.firestore()
          .collection("users").doc(uid)
          .collection("reports").doc(reportId)
          .set({
            id: reportId,
            title: result.title,
            dateRange,
            isWeekly: false,
            isRead: false,
            isNew: true,
            oneLiner: { true: result.oneLiner_honorific, false: result.oneLiner_casual },
            content: { true: result.content_honorific, false: result.content_casual },
            signature: { true: result.signature_honorific, false: result.signature_casual },
            wrapUp: { true: result.wrapUp_honorific, false: result.wrapUp_casual },
            weeklySummaries: result.weeklySummaries,
          });
      } catch (e) {
        console.error(`월간 리포트 생성 실패: uid=${uid}`, e);
      }
    }));
  });

export const onReportCreated = functions.firestore
  .document("users/{uid}/reports/{reportId}")
  .onCreate(async (snapshot, context) => {
    const uid = context.params.uid;
    const data = snapshot.data();
    if (!data) return;

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const fcmToken: string | undefined = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const isWeekly = data.isWeekly as boolean;
    const reportTitle = (data.title as string) || "";
    const notifTitle = isWeekly ? "주간 리포트가 도착했어요" : "월간 리포트가 도착했어요";

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title: notifTitle, body: reportTitle },
        data: { type: isWeekly ? "weekly_report" : "monthly_report", reportId: context.params.reportId },
      });
    } catch (e) {
      console.error("FCM 리포트 알림 발송 실패:", e);
      return;
    }

    const notifId = Date.now().toString();
    const today = new Date().toISOString().split("T")[0];
    await admin.firestore()
      .collection("users").doc(uid)
      .collection("notifications").doc(notifId)
      .set({ id: notifId, title: notifTitle, date: today, isUnread: true });
  });

export const onDiaryCreated = functions.firestore
  .document("users/{uid}/diaries/{diaryId}")
  .onCreate(async (snapshot, context) => {
    const uid = context.params.uid;
    const data = snapshot.data();
    if (!data) return;

    const mascotFeedback: string = data.mascotFeedback || "";
    if (!mascotFeedback) return;

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const fcmToken: string | undefined = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const title: string = data.title || "오늘의 일기";
    const notificationBody = mascotFeedback.length > 80
      ? mascotFeedback.substring(0, 80) + "..."
      : mascotFeedback;

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title: "마중이의 답장이 도착했어요", body: notificationBody },
        data: { type: "diary_feedback", diaryId: context.params.diaryId },
      });
    } catch (e) {
      console.error("FCM 발송 실패:", e);
      return;
    }

    const notifId = Date.now().toString();
    const today = new Date().toISOString().split("T")[0];
    await admin.firestore()
      .collection("users").doc(uid)
      .collection("notifications").doc(notifId)
      .set({ id: notifId, title: `[마중이 답장] ${title}`, date: today, isUnread: true });
  });

export const dailyDiaryReminder = functions.pubsub
  .schedule("0 11 * * *")
  .timeZone("Asia/Seoul")
  .onRun(async (_context) => {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, "0");
    const today = `${now.getFullYear()}.${pad(now.getMonth() + 1)}.${pad(now.getDate())}`;

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
        .where("date", "<=", today + "￿")
        .get();

      if (!diarySnapshot.empty) return;

      const todayEvents = userData.todayEvents as string[] | undefined;
      const todayEventsDate = userData.todayEventsDate as string | undefined;
      const hasEvents = Array.isArray(todayEvents) && todayEvents.length > 0 && todayEventsDate === today;

      const notifTitle = isHonorific
        ? `${userName}님, 오늘 하루는 어떠셨어요?`
        : `${userName}야, 오늘 하루 어땠어?`;
      const notifBody = hasEvents
        ? (isHonorific
          ? `오늘 ${todayEvents![0]} 일정이 있으셨네요. 마중이에게 오늘 이야기를 들려주세요.`
          : `오늘 ${todayEvents![0]} 일정이 있었네. 마중이한테 오늘 이야기 들려줘.`)
        : (isHonorific
          ? "마중이가 기다리고 있어요. 오늘의 이야기를 들려주세요."
          : "마중이가 기다리고 있어. 오늘 이야기 들려줘.");

      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: { title: notifTitle, body: notifBody },
          data: { type: "daily_reminder" },
        });
      } catch (e) {
        console.error(`FCM 리마인드 발송 실패 (uid: ${uid}):`, e);
      }
    });

    await Promise.allSettled(promises);
    console.log(`dailyDiaryReminder: ${usersSnapshot.size}명 처리 완료`);
  });
