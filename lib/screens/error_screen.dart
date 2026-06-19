import 'package:flutter/material.dart';
import '../theme.dart';
import 'onboarding/widgets/onboarding_illustration.dart';
import '../widgets/custom_button.dart';

/// 앱 전역에서 발생하는 예외/에러 상황에 사용하는 고충실도 에러 화면.
/// 피그마의 일관된 디자인 시스템과 캐릭터 일러스트를 활용해 안정적인 사용자 경험을 선사합니다.
class ErrorScreen extends StatelessWidget {
  final String title;
  final String? message;
  final String primaryButtonLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  const ErrorScreen({
    super.key,
    this.title = '문제가 발생했어요!',
    this.message,
    required this.primaryButtonLabel,
    required this.onPrimaryPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // 상단 닫기 아이콘이 지정되거나, secondary가 닫기 역할을 할 때의 일관된 내비게이션 지원
        leading: onSecondaryPressed != null
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.grayScale9),
                onPressed: onSecondaryPressed,
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              // 1. 에러 메인 문구 (Pretendard Bold H1)
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyle.h1.copyWith(
                  color: AppColors.grayScale9,
                ),
              ),
              const SizedBox(height: 24),

              // 2. 마중이 캐릭터 이미지 일러스트 (공용 에셋 재사용)
              const Center(
                child: OnboardingIllustration(scale: 1.0),
              ),
              const SizedBox(height: 24),

              // 3. 에러 상세 텍스트 정보 (Pretendard Regular 14px)
              if (message != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gray1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray2),
                  ),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.gray5,
                      height: 1.5,
                    ),
                  ),
                ),
              const Spacer(),

              // 4. 에러 액션 버튼 레이어 (Spacer 아래 밀착 배치)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomButton(
                    label: primaryButtonLabel,
                    onPressed: onPrimaryPressed,
                    isFullWidth: true,
                  ),
                  if (secondaryButtonLabel != null && onSecondaryPressed != null) ...[
                    const SizedBox(height: 12),
                    CustomButton(
                      label: secondaryButtonLabel!,
                      onPressed: onSecondaryPressed!,
                      isFullWidth: true,
                      backgroundColor: AppColors.gray2,
                      textColor: AppColors.grayScale9,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
