import 'package:flutter/material.dart';
import '../theme.dart';
import 'settings/settings_widgets.dart';

/// 피그마 "설정 모달" 디자인(node 173:514)을 100% 반영한 고충실도 설정 다이얼로그.
/// 가로 300px, 세로 460px의 흰색 카드 형태로 화면 중앙에 팝업됩니다.
/// 각 설정 단위는 settings_widgets.dart 서브 컴포넌트로 격리 설계되어 관심사의 분리를 달성했습니다.
class SettingsDialog extends StatelessWidget {
  final BuildContext parentContext;

  const SettingsDialog({super.key, required this.parentContext});

  @override
  Widget build(BuildContext context) {
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
            const SettingsNameRow(),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.gray2),
            const SizedBox(height: 12),

            // 3. 대화 스타일 선택 행
            const SettingsStyleRow(),
            const SizedBox(height: 16),

            // 4. 푸시 알림 설정 행
            const SettingsPushRow(),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.gray2),
            const SizedBox(height: 12),

            // 5. 리포트 수신 설정 행
            const SettingsReportRow(),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.gray2),
            const SizedBox(height: 12),

            // 6. 서비스 탈퇴 버튼 행
            SettingsWithdrawRow(
              parentContext: parentContext,
              onDialogDismissed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
