import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../widgets/behavior_card.dart';
import '../providers/activity_recommendation_provider.dart';
import 'chat/chat_screen.dart';
import 'onboarding/widgets/onboarding_bubble.dart';
import 'onboarding/widgets/onboarding_illustration.dart';
import 'activity_collection_screen.dart';
import 'report/report_list_screen.dart';
import 'notification_screen.dart';
import 'developer_screen.dart';
import '../widgets/settings_dialog.dart';
import '../providers/diary_list_provider.dart';
import '../utils/datetime_extension.dart';
import '../widgets/confirm_dialog.dart';
import '../main.dart';
import '../utils/speech_dictionary.dart';
import '../providers/home_greeting_provider.dart';
import '../providers/report_schedule_provider.dart';
import '../providers/report_provider.dart';
import '../providers/user_provider.dart';
import '../services/local_notification_service.dart';
import '../providers/notification_provider.dart';

import 'calendar/calendar_screen.dart';

/// 피그마 HOME 화면(노드 ID 100:1398)의 레이아웃을 100% 반영한 홈 스크린 컴포넌트.
/// 활동이 존재할 때와 존재하지 않을 때의 두 가지 비주얼 상태 분기를 분격적으로 대응하며,
/// 원활한 테스트와 시안 비교를 지원하기 위한 상태 변경 스위치 액션을 탑재함.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoReport());
  }

  Future<void> _checkAutoReport() async {
    final scheduleNotifier = ref.read(reportScheduleProvider.notifier);

    // userNameProvider가 비동기 로드 중일 수 있으므로 Repository에서 직접 최신 설정 정보를 로드합니다.
    final repo = ref.read(userRepositoryProvider);
    final settings = await repo.getUserSettings();
    final userName = (settings != null && settings['name'] != null)
        ? settings['name'] as String
        : ref.read(userNameProvider);

    if (scheduleNotifier.shouldGenerateWeekly()) {
      await ref
          .read(reportListProvider.notifier)
          .generateReport(userName: userName, isWeekly: true);
    }
    if (scheduleNotifier.shouldGenerateMonthly()) {
      await ref
          .read(reportListProvider.notifier)
          .generateReport(userName: userName, isWeekly: false);
    }
    // FCM으로 일기 리마인더가 일원화되었으므로 기존 로컬 알림 예약을 취소합니다.
    await LocalNotificationService.cancelDiaryReminder();
  }

  void _navigateToChat() {
    final diaries = ref.read(diaryListProvider);
    final todayStr = DateTime.now().toDotString();
    final todayDiaries = diaries
        .where((d) => d.date.startsWith(todayStr))
        .toList();

    if (todayDiaries.length >= 3) {
      final isHonorific = ref.read(selectedStyleProvider) == 1;
      showDialog(
        context: context,
        builder: (context) => ConfirmDialog(
          title: SpeechDictionary.get(SpeechKey.dailyLimitAlert, isHonorific),
          cancelLabel: '',
          confirmLabel: '확인',
          onConfirm: () {},
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatScreen()),
    );
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalendarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 가장 최근에 추천된 활동 확인 (없을 시 '활동 모음 보러가기' 문구 노출)
    final activities = ref.watch(activityListProvider);
    final cardTitle = activities.isNotEmpty
        ? activities.first.title
        : '활동 모음 보러가기';

    final hasUnreadNotification = ref.watch(notificationListProvider).any((item) => item.isUnread);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // 피그마 상단 탑바 레이아웃 (x: 16, y: 10, width: 76, height: 36)
        leadingWidth: 116,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: GestureDetector(
            onTap: () {
              _logoTapCount++;
              if (_logoTapCount >= 5) {
                _logoTapCount = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeveloperScreen(),
                  ),
                );
              }
            },
            child: Image.asset(
              'assets/images/main_logo.png',
              width: 100,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(AppIcons.bell, width: 24, height: 24),
                if (hasUnreadNotification)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFD7E7E), // 미확인 도트 색상
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: SvgPicture.asset(AppIcons.setting, width: 24, height: 24),
            onPressed: () {
              final parentContext = context;
              showDialog(
                context: parentContext,
                builder: (dialogContext) =>
                    SettingsDialog(parentContext: parentContext),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 24, // 여유롭게 바텀 바 위에 안착되도록 여백 설정
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            // 활동 상태 카드 (BehaviorCard 공용화 및 상태 연동)
            BehaviorCard(
              title: cardTitle,
              isChevronStyle: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActivityCollectionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 60),
            // 캐릭터 말풍선 - AI가 말투와 오늘 일정을 반영해 생성
            ref
                .watch(homeGreetingProvider)
                .when(
                  data: (greeting) => OnboardingBubble(text: greeting),
                  loading: () => const OnboardingBubble(text: '...'),
                  error: (_, _) => const OnboardingBubble(text: '오늘도 잘 부탁해.'),
                ),
            const SizedBox(height: 28),
            // 마중이 캐릭터 (Figma 160x240, scale: 1.0)
            const Center(child: OnboardingIllustration(scale: 1.0)),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: ConvexAppBar.builder(
        count: 3,
        itemBuilder: _HomeTabBuilder(
          onCalendarTap: _navigateToCalendar,
          onMessageTap: _navigateToChat,
          onEnvelopeTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportListScreen()),
            );
          },
        ),
        initialActiveIndex: 1,
        backgroundColor: AppColors.white,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        height: 60,
        curveSize: 87,
        top: -27,
        onTapNotify: (index) {
          if (index == 0) {
            _navigateToCalendar();
          } else if (index == 1) {
            _navigateToChat();
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportListScreen()),
            );
          }
          return false; // 항상 false를 반환하여 선택 및 커브가 움직이지 않게 고정
        },
      ),
    );
  }
}

/// ConvexAppBar.builder를 위해 탭 아이템들의 위젯을 제공하는 빌더 클래스
class _HomeTabBuilder extends DelegateBuilder {
  final VoidCallback onCalendarTap;
  final VoidCallback onMessageTap;
  final VoidCallback onEnvelopeTap;

  _HomeTabBuilder({
    required this.onCalendarTap,
    required this.onMessageTap,
    required this.onEnvelopeTap,
  });

  @override
  Widget build(BuildContext context, int index, bool active) {
    if (index == 0) {
      return Center(
        child: SvgPicture.asset(AppIcons.calender, width: 32, height: 32),
      );
    } else if (index == 1) {
      return Center(
        child: Container(
          width: 69,
          height: 69,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mainColor,
          ),
          child: Center(
            child: SvgPicture.asset(AppIcons.message, width: 36, height: 36),
          ),
        ),
      );
    } else {
      return Center(
        child: SvgPicture.asset(AppIcons.envelope, width: 28, height: 28),
      );
    }
  }
}
