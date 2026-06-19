import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { SYSTEM_INSTRUCTION, getGeminiClient, getKstDateInfo } from "../config";
import { getWeeklyReportSchema, getMonthlyReportSchema } from "../schemas";

export const generateReport = functions.https.onCall(async (data, _context) => {
  const { userName, isWeekly, dateRange, diaries, isHonorific } = data as {
    userName: string;
    isWeekly: boolean;
    dateRange: string;
    diaries: Array<{ date: string; title: string; content: string; mood: number }>;
    isHonorific: boolean;
  };

  const ai = getGeminiClient();
  const reportType = isWeekly ? "주간" : "월간";
  const diaryText = diaries.map((d) => `[${d.date}] 감정:${d.mood} 제목:${d.title}\n${d.content}`).join("\n\n");

  const prompt = `
${SYSTEM_INSTRUCTION}

[사용자 이름: ${userName}]
[기간: ${dateRange}]
[적용할 말투: ${isHonorific ? "존댓말" : "반말"}]
[일기 목록]
${diaryText || "이 기간에 작성된 일기가 없습니다."}

위 일기들을 바탕으로 ${userName}에게 보내는 따뜻한 ${reportType} 편지 리포트를 생성해주세요.
이모티콘 절대 금지. 반드시 지정된 말투 규칙(존댓말/반말)을 100% 엄수해 작성하세요.

출력은 반드시 아래 JSON 형태:
${isWeekly ? getWeeklyReportSchema(isHonorific) : getMonthlyReportSchema(isHonorific)}
`;

  try {
    const response = await ai.models.generateContent({
      model: "gemini-3.1-flash-lite",
      contents: prompt,
      config: { responseMimeType: "application/json" },
    });
    return JSON.parse(response.text ?? "");
  } catch (error: any) {
    throw new functions.https.HttpsError("internal", error.message || "Failed to generate report.");
  }
});

export const scheduledWeeklyReport = functions.pubsub
  .schedule("0 0 * * 1")
  .timeZone("Asia/Seoul")
  .onRun(async (_context) => {
    const ai = getGeminiClient();
    const kst = getKstDateInfo();
    const pad = (n: number) => String(n).padStart(2, "0");

    const to = new Date(kst.utcEquivalent.getTime());
    to.setUTCDate(to.getUTCDate() - 1);
    const from = new Date(to.getTime());
    from.setUTCDate(from.getUTCDate() - 6);

    const fmt = (d: Date) => `${d.getUTCFullYear()}.${pad(d.getUTCMonth() + 1)}.${pad(d.getUTCDate())}`;
    const dateRange = `${fmt(from)} ~ ${fmt(to)}`;
    const fromStr = fmt(from);
    const toStr = fmt(to);

    const usersSnapshot = await admin.firestore().collection("users").get();

    await Promise.allSettled(usersSnapshot.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      const userName: string = userData.name || "사용자";
      const isHonorific = userData.selectedStyle === 1;

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
[적용할 말투: ${isHonorific ? "존댓말" : "반말"}]
[일기 목록]
${diaryText}

위 일기를 바탕으로 따뜻한 주간 편지 리포트를 JSON으로 생성. 이모티콘 금지. 지정된 말투 100% 준수.
${getWeeklyReportSchema(isHonorific)}`;

      try {
        const response = await ai.models.generateContent({
          model: "gemini-3.1-flash-lite",
          contents: prompt,
          config: { responseMimeType: "application/json" },
        });
        const result = JSON.parse(response.text ?? "");
        const reportId = `weekly_${fromStr.replace(/\./g, "")}`;

        const month = from.getUTCMonth() + 1;
        const firstDay = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), 1));
        const firstWeekday = firstDay.getUTCDay();
        const adjFirstWeekday = firstWeekday === 0 ? 7 : firstWeekday;
        const dayOffset = from.getUTCDate() + adjFirstWeekday - 2;
        const weekNum = Math.floor(dayOffset / 7) + 1;
        const weekWords = ["첫째", "둘째", "셋째", "넷째", "다섯째", "여섯째"];
        const weekWord = (weekNum >= 1 && weekNum <= 6) ? weekWords[weekNum - 1] : `${weekNum}째`;
        const calculatedTitle = `${month}월 ${weekWord} 주`;

        await admin.firestore()
          .collection("users").doc(uid)
          .collection("reports").doc(reportId)
          .set({
            id: reportId,
            title: calculatedTitle,
            dateRange,
            isWeekly: true,
            isRead: false,
            isNew: true,
            oneLiner: result.oneLiner,
            content: result.content,
            signature: result.signature,
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
    const kst = getKstDateInfo();
    const pad = (n: number) => String(n).padStart(2, "0");

    const firstOfThisMonth = new Date(Date.UTC(kst.year, kst.month - 1, 1));
    const lastOfLastMonth = new Date(firstOfThisMonth.getTime() - 86400000);
    const firstOfLastMonth = new Date(Date.UTC(lastOfLastMonth.getUTCFullYear(), lastOfLastMonth.getUTCMonth(), 1));

    const fmt = (d: Date) => `${d.getUTCFullYear()}.${pad(d.getUTCMonth() + 1)}.${pad(d.getUTCDate())}`;
    const fromStr = fmt(firstOfLastMonth);
    const toStr = fmt(lastOfLastMonth);
    const dateRange = `${fromStr} ~ ${toStr}`;
    const monthLabel = `${lastOfLastMonth.getUTCFullYear()}년 ${lastOfLastMonth.getUTCMonth() + 1}월`;

    const usersSnapshot = await admin.firestore().collection("users").get();

    await Promise.allSettled(usersSnapshot.docs.map(async (userDoc) => {
      const uid = userDoc.id;
      const userData = userDoc.data();
      const userName: string = userData.name || "사용자";
      const isHonorific = userData.selectedStyle === 1;

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
[적용할 말투: ${isHonorific ? "존댓말" : "반말"}]
[일기 목록]
${diaryText}

위 일기를 바탕으로 따뜻한 월간 편지 리포트를 JSON으로 생성. 이모티콘 금지. 지정된 말투 100% 준수.
${getMonthlyReportSchema(isHonorific)}`;

      try {
        const response = await ai.models.generateContent({
          model: "gemini-3.1-flash-lite",
          contents: prompt,
          config: { responseMimeType: "application/json" },
        });
        const result = JSON.parse(response.text ?? "");
        const reportId = `monthly_${lastOfLastMonth.getUTCFullYear()}${pad(lastOfLastMonth.getUTCMonth() + 1)}`;
        const calculatedTitle = `${lastOfLastMonth.getUTCMonth() + 1}월의 기록`;

        await admin.firestore()
          .collection("users").doc(uid)
          .collection("reports").doc(reportId)
          .set({
            id: reportId,
            title: calculatedTitle,
            dateRange,
            isWeekly: false,
            isRead: false,
            isNew: true,
            oneLiner: result.oneLiner,
            content: result.content,
            signature: result.signature,
            wrapUp: result.wrapUp,
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
    const userData = userDoc.data();
    const isHonorific = userData?.selectedStyle === 1;

    let notifTitle = "";
    if (isWeekly) {
      notifTitle = isHonorific ? `${reportTitle} 편지가 도착했어요` : `${reportTitle} 편지가 도착했어`;
    } else {
      notifTitle = isHonorific ? `${reportTitle}이 도착했어요` : `${reportTitle}이 도착했어`;
    }

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: notifTitle,
          body: isHonorific ? "마중이의 따뜻한 리포트를 확인해 보세요." : "마중이의 따뜻한 리포트를 확인해 봐.",
        },
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
