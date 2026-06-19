import * as admin from "firebase-admin";

// Firebase Admin SDK 초기화 (모든 핸들러 로드 전에 먼저 호출)
admin.initializeApp();

export { chatWithMascot, generateHomeGreeting, dailyDiaryReminder, generateDiaryReminder } from "./handlers/chat";
export { generateDiaryAndFeedback } from "./handlers/diary";
export { generateReport, scheduledWeeklyReport, scheduledMonthlyReport, onReportCreated } from "./handlers/report";
