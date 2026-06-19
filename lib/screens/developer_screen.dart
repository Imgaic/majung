import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../services/local_notification_service.dart';
import '../services/gemini_service.dart';
import '../services/calendar_service.dart';
import '../providers/report_provider.dart';
import '../providers/user_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/diary_list_provider.dart';
import '../providers/activity_recommendation_provider.dart';
import '../models/diary_data.dart';
import '../models/report_model.dart';
import '../main.dart'; // selectedStyleProvider

class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  bool _isGenerating = false;

  Future<void> _triggerReminderNotification() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final userName = ref.read(userNameProvider);
      final isHonorific = ref.read(selectedStyleProvider) == 1;

      // 1. 기기 캘린더에서 오늘 실제 일정 가져오기
      final todayEvents = await CalendarService.getTodayEvents(requestPermission: true);

      // 2. 백엔드 AI 호출하여 맞춤형 리마인더 제목과 본문 생성
      final result = await GeminiService.generateDiaryReminder(
        userName: userName,
        isHonorific: isHonorific,
        todayEvents: todayEvents,
      );

      final String notifTitle = result['title'] as String? ?? '오늘 하루는 어떠셨어요?';
      final String notifBody = result['body'] as String? ?? '오늘 있었던 일을 마중이에게 이야기해 주세요.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('3초 후 알림이 발송됩니다. 홈 화면으로 이동해 주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 백그라운드 테스트를 위해 3초 대기 딜레이 부여
      await Future.delayed(const Duration(seconds: 3));

      await LocalNotificationService.show(
        title: notifTitle,
        body: notifBody,
        payload: 'diary_reminder',
      );

      // 알림 내역에 동기화 저장
      await ref.read(notificationListProvider.notifier).addNotification(notifTitle);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알림 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateReport(bool isWeekly) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final userName = ref.read(userNameProvider);
      await ref.read(reportListProvider.notifier).generateReport(
        userName: userName,
        isWeekly: isWeekly,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isWeekly ? "주간" : "월간"} 리포트 생성 및 알림 발송 완료.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateDummyDiaries() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      String fmt(DateTime d) => '${d.year}.${pad(d.month)}.${pad(d.day)}';

      final d1 = now.subtract(const Duration(days: 1));
      final d2 = now.subtract(const Duration(days: 2));
      final d3 = now.subtract(const Duration(days: 3));
      final d5 = now.subtract(const Duration(days: 5));
      final d7 = now.subtract(const Duration(days: 7));

      final List<DiaryData> dummies = [
        DiaryData(
          date: fmt(d1),
          title: '어제 있었던 일',
          content: '어제는 오랜만에 친구를 만나서 맛있는 음식을 먹고 즐거운 대화를 나누었다. 마음이 한결 가벼워진 느낌이었다.',
          mood: 1, // 아주 좋음
          imagePaths: [],
          mascotFeedback: '친구분과 즐거운 시간을 보내셨다니 다행이에요! 가끔은 이렇게 소중한 사람들과 소통하며 마음의 환기를 시켜주는 것이 정말 큰 도움이 된답니다.',
          recommendedAction: '친구에게 감사 메시지 보내기',
          recommendedActions: ['친구에게 감사 메시지 보내기', '오늘 찍은 사진 정리하기', '따뜻한 차 한 잔 마시기'],
          isDirectWrite: false,
          tags: ['우정', '즐거운하루'],
        ),
        DiaryData(
          date: fmt(d2),
          title: '조금 피곤했던 하루',
          content: '업무가 많아서 야근을 했다. 몸도 피곤하고 마음도 지쳐서 집에 오자마자 바로 눕고 싶었다.',
          mood: 4, // 나쁨
          imagePaths: [],
          mascotFeedback: '야근하시느라 정말 고생 많으셨어요. 피곤할 때는 다른 생각은 내려두고 푹 쉬는 것이 최고예요. 오늘 밤은 푹 주무세요.',
          recommendedAction: '따뜻한 물로 샤워하기',
          recommendedActions: ['따뜻한 물로 샤워하기', '가벼운 스트레칭', '일찍 잠자리에 들기'],
          isDirectWrite: false,
          tags: ['야근', '피로'],
        ),
        DiaryData(
          date: fmt(d3),
          title: '평범한 일상',
          content: '특별할 것 없는 평범한 하루였다. 산책을 하면서 좋아하는 노래를 들었는데 마음이 편안해졌다.',
          mood: 3, // 보통
          imagePaths: [],
          mascotFeedback: '평범한 하루 속에서 잔잔한 평온함을 찾으셨군요. 산책을 하며 음악을 듣는 소박한 행복이 마음을 채워주었기를 바라요.',
          recommendedAction: '좋아하는 노래 들으며 산책하기',
          recommendedActions: ['좋아하는 노래 들으며 산책하기', '일기 쓰며 하루 정리', '좋아하는 음료 마시기'],
          isDirectWrite: false,
          tags: ['산책', '평온'],
        ),
        DiaryData(
          date: fmt(d5),
          title: '속상한 수요일',
          content: '사소한 일로 가족과 다퉜다. 서로 예민했던 탓인 걸 알지만 마음이 무겁고 하루 종일 우울했다.',
          mood: 5, // 아주 나쁨
          imagePaths: [],
          mascotFeedback: '가족과의 갈등으로 마음이 무거우셨군요. 가까운 사이일수록 작은 말 한마디에 더 큰 상처를 받기도 해요. 조금 진정된 후에 따뜻한 대화를 시도해 보세요.',
          recommendedAction: '따뜻한 우유 한 잔 마시기',
          recommendedActions: ['따뜻한 우유 한 잔 마시기', '조용히 명상하기', '좋아하는 음악 듣기'],
          isDirectWrite: false,
          tags: ['우울', '가족'],
        ),
        DiaryData(
          date: fmt(d7),
          title: '기분 좋은 수확',
          content: '가까운 공원에 갔는데 예쁜 꽃들이 가득 피어 있어서 기분이 좋았다. 사진도 많이 찍고 기분 전환이 되었다.',
          mood: 2, // 좋음
          imagePaths: [],
          mascotFeedback: '공원에서 예쁜 꽃들을 보며 기분 전환을 하셨군요! 자연이 주는 아름다움을 보며 잠시 여유를 만끽하신 것은 훌륭한 선택이었어요.',
          recommendedAction: '오늘 찍은 사진 정리하기',
          recommendedActions: ['오늘 찍은 사진 정리하기', '가벼운 스트레칭', '좋아하는 차 마시기'],
          isDirectWrite: false,
          tags: ['기분전환', '자연'],
        ),
      ];

      // 1. 더미 일기 추가 및 추천 행동 연쇄 등록
      for (final diary in dummies) {
        await ref.read(diaryListProvider.notifier).addOrUpdateDiary(diary);
        if (diary.recommendedAction.isNotEmpty) {
          await ref.read(activityListProvider.notifier).addActivity(diary.recommendedAction, date: diary.date);
        }
      }

      // 2. 더미 주간 리포트 추가 (6월 테스트와 겹치지 않도록 5월 마지막 주로 고정)
      final weeklyDummy = ReportLetter(
        id: 'dummy_weekly_20260525',
        title: '5월 마지막 주',
        dateRange: '2026.05.25 ~ 2026.05.31',
        isWeekly: true,
        isRead: false,
        isNew: true,
        oneLiner: '지난 한 주 동안 친구들과 소중한 관계를 돈독히 하며 피로를 헤쳐나갔어요.',
        content: '지난 한 주는 여러 힘든 일과 바쁜 일정 속에서도 주변 사람들과 소통하며 극복하고자 한 한 주였어요. 피곤하고 지칠 때도 스스로 스트레칭이나 따뜻한 샤워로 몸과 마음을 돌보려는 노력이 돋보였습니다. 앞으로도 이러한 따뜻한 보살핌을 잊지 않길 바랄게요.',
        signature: '늘 당신을 응원하는 마중이가 드림',
        recommendationTitle: '주변 소중한 인연들과 좀 더 깊은 대화를 나누어보면 어떨까요?',
        recommendations: [
          '가족들과 맛있는 저녁 식사하기',
          '친한 친구에게 따뜻한 안부 전화하기',
          '내 방에 좋아하는 꽃 장식해두기'
        ],
      );

      // 3. 더미 월간 리포트 추가 (6월 테스트와 겹치지 않도록 5월의 기록으로 고정)
      final monthlyDummy = ReportLetter(
        id: 'dummy_monthly_202605',
        title: '5월의 기록',
        dateRange: '2026.05.01 ~ 2026.05.31',
        isWeekly: false,
        isRead: false,
        isNew: true,
        oneLiner: '이번 한 달은 평온함 속에서 잔잔한 행복을 쌓아가는 여정이었습니다.',
        content: '한 달 동안 정말 수고 많으셨어요. 평범한 일상 속에서 잔잔한 평온함을 즐기시던 날도 있었고, 지치고 피곤한 야근 뒤에 스스로 마음을 가다듬으며 극복하던 날도 있었습니다. 스스로의 마음 상태를 섬세하게 들여다보는 시간을 가지며 차분한 행복을 일구어나가는 모습이 무척 감동적이었습니다.',
        signature: '언제나 곁에 있는 마중이가 드림',
        wrapUp: '스스로를 돌보고 안아주었던 행동들을 다음 달에도 이어나가며, 잔잔한 행복의 크기를 넓혀가길 마중이가 늘 응원할게요.',
        weeklySummaries: [
          WeeklySummary(weekTitle: '1주차', description: '친구와 함께 소소한 수다를 떨며 지쳐있던 마음에 가벼운 환기를 시켜주었어요.'),
          WeeklySummary(weekTitle: '2주차', description: '야근으로 몸과 마음이 피로한 날에는 혼자만의 시간을 가지며 편안하게 휴식했습니다.'),
          WeeklySummary(weekTitle: '3주차', description: '산책을 하며 좋아하는 노래를 들고, 잔잔한 삶의 활력과 평온함을 채웠습니다.'),
        ],
      );

      await ref.read(reportListProvider.notifier).addDummyReport(weeklyDummy);
      await ref.read(reportListProvider.notifier).addDummyReport(monthlyDummy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시연용 더미 일기 5건, 추천 행동 및 리포트 2건 연동 완료!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('더미 데이터 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('개발자 메뉴 (시연/테스트)', style: AppTextStyle.body2B),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '시연 시나리오 지원 도구',
                style: AppTextStyle.body1,
              ),
              const SizedBox(height: 8),
              const Text(
                '실제 FCM 서버 없이도 시뮬레이터 및 실물 기기에서 푸시 수신 및 클릭 화면 이동(Deep Link) 시연이 가능하도록 설계된 로컬 트리거입니다.',
                style: AppTextStyle.caption1,
              ),
              const SizedBox(height: 24),

              // 1. 일기 리마인더 카드
              _buildControlCard(
                title: '1. 일기 작성 리마인더 테스트',
                description: '사용자가 온보딩에서 연동한 일정을 인지해 맞춤형 대화를 제안하는 리마인더 푸시를 전송합니다.\n(알림 터치 시 일기 작성 채팅창으로 즉시 이동)',
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isGenerating ? null : _triggerReminderNotification,
                    child: const Text('리마인더 알림 즉시 발송', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. 리포트 생성 카드
              _buildControlCard(
                title: '2. 편지 보관함 리포트 도착 테스트',
                description: '현재까지 쌓인 일기 데이터에 맞춰 AI 분석을 요청하고 주간/월간 편지를 보관함에 즉시 추가합니다.\n(완료 시 알림이 발송되며, 알림 터치 시 편지 보관함 화면으로 즉시 이동)',
                child: _isGenerating
                    ? const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: AppColors.mainColor),
                            SizedBox(height: 8),
                            Text('AI 분석 및 편지 작성 중...', style: AppTextStyle.caption1),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.mainColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => _generateReport(true),
                              child: const Text('주간 리포트 생성', style: TextStyle(color: AppColors.mainColor, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.mainColor),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                minimumSize: const Size(0, 48),
                              ),
                              onPressed: () => _generateReport(false),
                              child: const Text('월간 리포트 생성', style: TextStyle(color: AppColors.mainColor, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // 3. 더미 데이터 생성 카드
              _buildControlCard(
                title: '3. 시연용 과거 더미 일기 생성',
                description: '캘린더 화면 채우기 및 리포트(주간/월간) 생성 테스트를 위해 과거 날짜(어제, 2일 전, 3일 전 등)의 더미 일기 5건을 일괄 등록합니다.\n(각 일기에 따른 추천 행동 수행 이력도 함께 연동됩니다)',
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.subColor,
                      foregroundColor: AppColors.mainColor,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.mainColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isGenerating ? null : _generateDummyDiaries,
                    child: const Text('과거 더미 일기 5건 생성', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyle.body2B),
          const SizedBox(height: 8),
          Text(description, style: AppTextStyle.caption1.copyWith(color: AppColors.gray4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
