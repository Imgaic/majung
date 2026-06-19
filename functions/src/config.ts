import { GoogleGenAI } from "@google/genai";

export const SYSTEM_INSTRUCTION = `
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

export function getGeminiClient(): GoogleGenAI {
  return new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY ?? "" });
}

export interface ChatMessage {
  sender: "user" | "mascot";
  content: string;
}

/**
 * 현재 또는 특정 시각을 기준으로 KST(Asia/Seoul) 시간대의 날짜/시간 정보를 추출합니다.
 */
export function getKstDateInfo(date: Date = new Date()) {
  const formatter = new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
  const parts = formatter.formatToParts(date);
  const findPart = (type: string) => parts.find((p) => p.type === type)?.value || "";

  const year = parseInt(findPart("year"), 10);
  const month = parseInt(findPart("month"), 10);
  const day = parseInt(findPart("day"), 10);
  const hour = parseInt(findPart("hour"), 10);
  const minute = parseInt(findPart("minute"), 10);
  const second = parseInt(findPart("second"), 10);

  // KST 기준의 연/월/일 시각을 가진 UTC Date 객체를 구성하여 날짜 연산에 활용합니다.
  const utcEquivalent = new Date(Date.UTC(year, month - 1, day, hour, minute, second));

  return {
    year,
    month,
    day,
    hour,
    minute,
    second,
    dateString: `${year}.${String(month).padStart(2, "0")}.${String(day).padStart(2, "0")}`,
    utcEquivalent,
  };
}
