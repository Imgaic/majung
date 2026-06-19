"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onReportCreated = exports.scheduledMonthlyReport = exports.scheduledWeeklyReport = exports.generateReport = exports.generateDiaryAndFeedback = exports.generateDiaryReminder = exports.dailyDiaryReminder = exports.generateHomeGreeting = exports.chatWithMascot = void 0;
const admin = __importStar(require("firebase-admin"));
// Firebase Admin SDK 초기화 (모든 핸들러 로드 전에 먼저 호출)
admin.initializeApp();
var chat_1 = require("./handlers/chat");
Object.defineProperty(exports, "chatWithMascot", { enumerable: true, get: function () { return chat_1.chatWithMascot; } });
Object.defineProperty(exports, "generateHomeGreeting", { enumerable: true, get: function () { return chat_1.generateHomeGreeting; } });
Object.defineProperty(exports, "dailyDiaryReminder", { enumerable: true, get: function () { return chat_1.dailyDiaryReminder; } });
Object.defineProperty(exports, "generateDiaryReminder", { enumerable: true, get: function () { return chat_1.generateDiaryReminder; } });
var diary_1 = require("./handlers/diary");
Object.defineProperty(exports, "generateDiaryAndFeedback", { enumerable: true, get: function () { return diary_1.generateDiaryAndFeedback; } });
var report_1 = require("./handlers/report");
Object.defineProperty(exports, "generateReport", { enumerable: true, get: function () { return report_1.generateReport; } });
Object.defineProperty(exports, "scheduledWeeklyReport", { enumerable: true, get: function () { return report_1.scheduledWeeklyReport; } });
Object.defineProperty(exports, "scheduledMonthlyReport", { enumerable: true, get: function () { return report_1.scheduledMonthlyReport; } });
Object.defineProperty(exports, "onReportCreated", { enumerable: true, get: function () { return report_1.onReportCreated; } });
//# sourceMappingURL=index.js.map