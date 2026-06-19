import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme.dart';
import '../app_icons.dart';
import '../custom_toggle.dart';
import '../style_segmented_slider.dart';
import '../confirm_dialog.dart';
import '../../providers/user_provider.dart';
import '../../providers/report_schedule_provider.dart';
import '../../main.dart'; // selectedStyleProvider, toggleStateProvider, LoginScreen
import '../../utils/speech_dictionary.dart';
import '../settings_dialog.dart';

/// 1. 사용자 이름 설정 행 컴포넌트
class SettingsNameRow extends ConsumerStatefulWidget {
  const SettingsNameRow({super.key});

  @override
  ConsumerState<SettingsNameRow> createState() => _SettingsNameRowState();
}

class _SettingsNameRowState extends ConsumerState<SettingsNameRow> {
  bool _isEditingName = false;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: ref.read(userNameProvider));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    if (_nameController.text.trim().isNotEmpty) {
      ref.read(userNameProvider.notifier).updateName(_nameController.text);
    }
    setState(() {
      _isEditingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userName = ref.watch(userNameProvider);

    return SizedBox(
      height: 32,
      child: _isEditingName
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: AppTextStyle.body2SB.copyWith(
                      color: AppColors.grayScale9,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.mainColor,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.mainColor,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _saveName,
                  child: SvgPicture.asset(
                    AppIcons.checkCircle,
                    width: 24,
                    height: 24,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  userName,
                  style: AppTextStyle.body2SB.copyWith(
                    color: AppColors.grayScale9,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _nameController.text = userName;
                      _isEditingName = true;
                    });
                  },
                  child: SvgPicture.asset(
                    AppIcons.pen,
                    width: 24,
                    height: 24,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 2. 대화 스타일 선택 행 컴포넌트
class SettingsStyleRow extends ConsumerWidget {
  const SettingsStyleRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStyle = ref.watch(selectedStyleProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대화 스타일',
          style: AppTextStyle.body2R.copyWith(color: AppColors.grayScale9),
        ),
        const SizedBox(height: 8),
        Center(
          child: StyleSegmentedSlider(
            selectedIndex: selectedStyle,
            onChanged: (val) {
              ref.read(selectedStyleProvider.notifier).select(val);
            },
          ),
        ),
      ],
    );
  }
}

/// 3. 푸시 알림 설정 행 컴포넌트
class SettingsPushRow extends ConsumerWidget {
  const SettingsPushRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPushActive = ref.watch(toggleStateProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '푸시 알림',
          style: AppTextStyle.body2R.copyWith(
            color: AppColors.grayScale9,
          ),
        ),
        CustomToggle(
          value: isPushActive,
          onChanged: (val) {
            ref.read(toggleStateProvider.notifier).toggle(val);
          },
        ),
      ],
    );
  }
}

/// 4. 리포트 수신 설정 컴포넌트
class SettingsReportRow extends ConsumerWidget {
  const SettingsReportRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(reportScheduleProvider).when(
          data: (v) => v,
          loading: () => const ReportSchedule(),
          error: (_, _) => const ReportSchedule(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '리포트 수신',
          style: AppTextStyle.body2R.copyWith(color: AppColors.grayScale9),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '주간',
              style: AppTextStyle.caption1.copyWith(color: AppColors.gray4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: schedule.weeklyDay,
                  isDense: true,
                  style: AppTextStyle.caption1.copyWith(
                    color: AppColors.grayScale9,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('월요일')),
                    DropdownMenuItem(value: 2, child: Text('화요일')),
                    DropdownMenuItem(value: 3, child: Text('수요일')),
                    DropdownMenuItem(value: 4, child: Text('목요일')),
                    DropdownMenuItem(value: 5, child: Text('금요일')),
                    DropdownMenuItem(value: 6, child: Text('토요일')),
                    DropdownMenuItem(value: 7, child: Text('일요일')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(reportScheduleProvider.notifier).setWeeklyDay(v);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '월간',
              style: AppTextStyle.caption1.copyWith(color: AppColors.gray4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: schedule.monthlyDay,
                  isDense: true,
                  style: AppTextStyle.caption1.copyWith(
                    color: AppColors.grayScale9,
                  ),
                  items: List.generate(28, (i) => i + 1)
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text('$d일')),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(reportScheduleProvider.notifier).setMonthlyDay(v);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 5. 서비스 탈퇴 컴포넌트
class SettingsWithdrawRow extends ConsumerWidget {
  final BuildContext parentContext;
  final VoidCallback onDialogDismissed;

  const SettingsWithdrawRow({
    super.key,
    required this.parentContext,
    required this.onDialogDismissed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // 기존 설정창 모달을 닫음
        onDialogDismissed();

        showDialog(
          context: parentContext,
          barrierDismissible: false,
          builder: (dialogContext) => ConfirmDialog(
            title: SpeechDictionary.get(
              SpeechKey.withdrawConfirmTitle,
              ref.read(selectedStyleProvider) == 1,
            ),
            confirmLabel: '탈퇴',
            cancelLabel: '취소',
            confirmBgColor: AppColors.red,
            onConfirm: () async {
              try {
                // 1. Firebase Auth 로그아웃 (익명 로그인 해제)
                await FirebaseAuth.instance.signOut();

                // 2. 로컬 상태 초기화
                ref.read(userNameProvider.notifier).updateName('');
                ref.read(selectedStyleProvider.notifier).select(0);
                ref.read(toggleStateProvider.notifier).toggle(false);

                // 3. 로그인 화면으로 이동하여 모든 네비게이션 스택 비우기
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  parentContext,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              } catch (e) {
                debugPrint('탈퇴 처리 중 오류 발생: $e');
              }
            },
            onCancel: () {
              // 취소 시 다시 설정 모달 띄우기
              showDialog(
                context: parentContext,
                builder: (context) => SettingsDialog(parentContext: parentContext),
              );
            },
          ),
        );
      },
      child: Text(
        '서비스 탈퇴하기',
        style: AppTextStyle.body2R.copyWith(
          color: AppColors.gray4,
        ),
      ),
    );
  }
}
