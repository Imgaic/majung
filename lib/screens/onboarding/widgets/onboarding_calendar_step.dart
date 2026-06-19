import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme.dart';
import '../../../widgets/custom_button.dart';
import '../../../utils/permission_manager.dart';
import '../../../services/calendar_service.dart';
import '../../../services/fcm_service.dart';
import '../../../main.dart'; // toggleStateProvider
import 'package:firebase_auth/firebase_auth.dart';

/// 온보딩 4단계: 스마트폰 캘린더 동기화 동의 단계 위젯.
class OnboardingCalendarStep extends ConsumerStatefulWidget {
  final VoidCallback onNextPressed;

  const OnboardingCalendarStep({
    super.key,
    required this.onNextPressed,
  });

  @override
  ConsumerState<OnboardingCalendarStep> createState() => _OnboardingCalendarStepState();
}

class _OnboardingCalendarStepState extends ConsumerState<OnboardingCalendarStep> {
  bool _isLoading = false;

  Future<void> _handleSync() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 캘린더 권한 요청
      final calendarGranted = await PermissionManager.requestCalendarPermission();
      debugPrint('Majung Sync: Calendar Permission Granted = $calendarGranted');

      // 2. 알림 권한 요청 (동의 여부 상관없이 계속 진행)
      final notificationGranted = await PermissionManager.requestNotificationPermission();
      debugPrint('Majung Sync: Notification Permission Granted = $notificationGranted');

      // 알림 권한을 허용했다면 홈 화면의 푸시 알람 토글 상태도 자동으로 ON 처리
      if (notificationGranted) {
        ref.read(toggleStateProvider.notifier).toggle(true);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FcmService.initialize(uid: user.uid, requestPermission: true);
        }
      }

      if (!mounted) return;

      if (calendarGranted) {
        // 3. 오늘 일정 조회 및 Firestore 동기화
        final todayEvents = await CalendarService.getTodayEvents(requestPermission: true);
        debugPrint('Majung Sync: Fetched Today\'s Events = $todayEvents');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FcmService.syncTodayEvents(uid: user.uid, events: todayEvents);
        }
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    }

    // 짧은 로딩 지연 연출 후 다음 단계로 부드럽게 이동
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      widget.onNextPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Text(
            '오늘의 일정으로 시작하는 대화',
            style: AppTextStyle.h1.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '“오늘 무슨 일 있어?" 같은 뻔한 질문 대신\n캘린더 일정을 파악해 개인에 맞춘 질문을 해요.',
            style: AppTextStyle.body2R.copyWith(
              color: AppColors.grayScale9,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          // 스마트폰 캘린더 질문 시뮬레이션 카드 (Figma 디자인 반영)
          Center(
            child: Container(
              width: 280,
              height: 263,
              decoration: const BoxDecoration(
                color: Color(0xFF3C5A70), // Rectangle 271 색상
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(30),
                ),
              ),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 246,
                height: 246,
                margin: const EdgeInsets.only(left: 17, right: 17, top: 17),
                decoration: const BoxDecoration(
                  color: Colors.white, // Rectangle 272 색상
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(19),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 70, // y: 375 - 305 = 70
                      left: 8, // x: 65 - 57 = 8
                      child: Container(
                        width: 230,
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF4FAFF,
                          ), // Rectangle 273 색상 (subColor)
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Ellipse 2 (Avatar circle)
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F8FA), // gray1
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.mainColor,
                                  width: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Texts
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '00이',
                                  style: AppTextStyle.caption2.copyWith(
                                    color: AppColors.grayScale9,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '오늘 피크닉 잘 다녀왔어?',
                                  style: AppTextStyle.caption1.copyWith(
                                    color: AppColors.grayScale9,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            '*캘린더 데이터는 대화의 맥락을 이해하는 데만 사용되며,\n절대 외부에 유출되거나 상업적으로 활용되지 않습니다.',
            style: AppTextStyle.caption1.copyWith(
              fontSize: 12,
              color: AppColors.gray4,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          CustomButton(
            label: _isLoading ? '연동 진행 중...' : '캘린더 연동하기',
            isFullWidth: true,
            onPressed: _isLoading ? () {} : _handleSync,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
