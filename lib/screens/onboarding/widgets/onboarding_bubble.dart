import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../utils/string_extension.dart';

/// 피그마의 Union 말풍선 꼬리 및 음영 박스 데코레이터를 추상화한 공용 말풍선 위젯.
class OnboardingBubble extends StatelessWidget {
  final String text;

  const OnboardingBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // 말풍선 삼각형 꼬리 (Union Beak)가 뒤에 깔리도록 먼저 선언
        Positioned(
          bottom: 4,
          child: RotationTransition(
            turns: const AlwaysStoppedAnimation(45 / 360),
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.grayScale1,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.grayScale1,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            text.withKoreanBalancedWrap.withKoreanWordBreak,
            textAlign: TextAlign.center,
            style: AppTextStyle.body2R.copyWith(
              color: AppColors.grayScale9,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
