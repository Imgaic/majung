import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import 'app_icons.dart';
import 'custom_toggle.dart';
import 'style_segmented_slider.dart';
import 'confirm_dialog.dart';
import '../providers/user_provider.dart';
import '../providers/report_schedule_provider.dart';
import '../main.dart'; // selectedStyleProvider, toggleStateProvider
import '../utils/speech_dictionary.dart';

/// 피그마 "설정 모달" 디자인(node 173:514)을 100% 반영한 고충실도 설정 다이얼로그.
/// 가로 300px, 세로 353px의 흰색 카드 형태로 화면 중앙에 팝업됩니다.
class SettingsDialog extends ConsumerStatefulWidget {
  final BuildContext parentContext;

  const SettingsDialog({super.key, required this.parentContext});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  bool _isEditingName = false;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // 현재 사용자 이름을 가져와 텍스트 에디터에 주입
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
    final selectedStyle = ref.watch(selectedStyleProvider);
    final isPushActive = ref.watch(toggleStateProvider);
    final schedule = ref.watch(reportScheduleProvider).when(
          data: (v) => v,
          loading: () => const ReportSchedule(),
          error: (_, __) => const ReportSchedule(),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        width: 300,
        height: 460,
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 헤더 영역 (설정 타이틀 & 닫기 버튼)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '설정',
                  style: AppTextStyle.body1.copyWith(
                    color: AppColors.grayScale9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close, color: AppColors.gray4, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. 사용자 이름 설정 행
            SizedBox(
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
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.gray2),
            const SizedBox(height: 12),

            // 3. 대화 스타일 선택 행
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
            const SizedBox(height: 16),

            // 4. 푸시 알림 설정 행
            Row(
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
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.gray2),
            const SizedBox(height: 12),

            // 5. 리포트 수신 설정
            Text('리포트 수신', style: AppTextStyle.body2R.copyWith(color: AppColors.grayScale9)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('주간', style: AppTextStyle.caption1.copyWith(color: AppColors.gray4)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: schedule.weeklyDay,
                      isDense: true,
                      style: AppTextStyle.caption1.copyWith(color: AppColors.grayScale9),
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
                        if (v != null) ref.read(reportScheduleProvider.notifier).setWeeklyDay(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('월간', style: AppTextStyle.caption1.copyWith(color: AppColors.gray4)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: schedule.monthlyDay,
                      isDense: true,
                      style: AppTextStyle.caption1.copyWith(color: AppColors.grayScale9),
                      items: List.generate(28, (i) => i + 1)
                          .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) ref.read(reportScheduleProvider.notifier).setMonthlyDay(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.gray2),
            const SizedBox(height: 12),

            // 6. 서비스 탈퇴 버튼
            GestureDetector(
              onTap: () {
                // 기존 설정창 모달을 닫고 전환하는 효과
                Navigator.pop(context);

                showDialog(
                  context: widget.parentContext,
                  barrierDismissible: false,
                  builder: (dialogContext) => ConfirmDialog(
                    title: SpeechDictionary.get(
                      SpeechKey.withdrawConfirmTitle,
                      ref.read(selectedStyleProvider) == 1,
                    ),
                    confirmLabel: '탈퇴',
                    cancelLabel: '취소',
                    confirmBgColor: AppColors.red,
                    onConfirm: () {
                      // 탈퇴 모크 기능: 설정 초기화
                      ref.read(userNameProvider.notifier).updateName('00이');
                      ref.read(selectedStyleProvider.notifier).select(0);
                      ref.read(toggleStateProvider.notifier).toggle(false);
                    },
                    onCancel: () {
                      // 취소 시 다시 설정 모달 띄우기
                      showDialog(
                        context: widget.parentContext,
                        builder: (context) =>
                            SettingsDialog(parentContext: widget.parentContext),
                      );
                    },
                  ),
                );
              },
              child: Text(
                '서비스 탈퇴하기',
                style: AppTextStyle.body2R.copyWith(
                  color: AppColors.gray4, // 피그마 #9ea4a9 적용
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
