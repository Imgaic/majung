import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../models/report_model.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_provider.dart';
import '../../main.dart'; // selectedStyleProvider
import '../../widgets/custom_app_bar.dart';
import '../../utils/speech_dictionary.dart';
import '../../utils/string_extension.dart';

/// 피그마 주간 리포트(node 27:121) 및 월간 리포트(node 30:403) 상세 정보를
/// 유연하게 통합 처리하는 고충실도(High-Fidelity) 리포트 상세 화면입니다.
class ReportDetailScreen extends ConsumerWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. 말투 선택 상태 및 사용자 이름 구독
    final isHonorific = ref.watch(selectedStyleProvider) == 1;
    final userName = ref.watch(userNameProvider);

    // 2. 전체 리포트 리스트에서 해당 ID의 편지 검색
    final reports = ref.watch(reportListProvider);
    final report = reports.firstWhere(
      (r) => r.id == reportId,
      orElse: () => ReportLetter(
        id: '',
        title: '알 수 없음',
        dateRange: '',
        isWeekly: true,
        oneLiner: '',
        content: '',
        signature: '',
      ),
    );

    // 없는 리포트 예외 처리
    if (report.id.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: const CustomAppBar(title: ''),
        body: const Center(
          child: Text('리포트를 찾을 수 없습니다.', style: AppTextStyle.body2B),
        ),
      );
    }

    // 3. 이름 자리표시자 '00' 치환 처리
    final String processedOneLiner = report.oneLiner.replaceAll('00', userName);
    final String processedContent = report.content.replaceAll('00', userName);

    // 4. 피그마 v.4 명세에 맞춘 상단 타이틀 동적 가공
    String formattedTitle = report.title;
    // '5월 둘째주' -> '5월 둘째 주' 자간 공백 교정
    if (formattedTitle.endsWith('주') && !formattedTitle.endsWith(' 주')) {
      formattedTitle = formattedTitle.replaceAll('주', ' 주');
    }

    final suffix = report.isWeekly
        ? SpeechDictionary.get(SpeechKey.weeklyReportTitleSuffix, isHonorific)
        : SpeechDictionary.get(SpeechKey.monthlyReportTitleSuffix, isHonorific);
    final String appBarTitle = report.isWeekly
        ? '$formattedTitle$suffix'
        : '${formattedTitle.replaceAll('의 기록', '')}$suffix';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CustomAppBar(
        title: appBarTitle,
        titleStyle: AppTextStyle.body2B,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // 5. 헤더: 60x60 마중이 프로필 SVG (데코레이션 및 클리핑 없이 순수 렌더링)
              Center(
                child: SvgPicture.asset(
                  AppIcons.profile,
                  width: 60,
                  height: 60,
                ),
              ),
              const SizedBox(height: 16),

              // 6. 한 줄 요약/질문 (텍스트 중앙 정렬)
              Text(
                processedOneLiner.withKoreanBalancedWrap.withKoreanWordBreak,
                textAlign: TextAlign.center,
                style: AppTextStyle.body2SB.copyWith(
                  color: AppColors.grayScale9,
                ),
              ),
              const SizedBox(height: 24),

              // 7. 편지지 피드백 영역
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.subColor, // 피그마 bg-[#F6F8FA]
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 편지 본문 텍스트
                    Text(
                      processedContent,
                      style: AppTextStyle.text.copyWith(
                        color: AppColors.grayScale9,
                        height: 1.6,
                      ),
                    ),

                    // 주간 vs 월간 UI 분기 렌더링
                    if (report.isWeekly) ...[
                      // [주간] 추천 행동 카드 박스
                      if (report.recommendations != null &&
                          report.recommendations!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        // 피그마 v.4: 추천 제목을 흰 박스 바깥 쪽에 본문 글씨 스타일로 배치
                        Text(
                          report.recommendationTitle ?? '',
                          style: AppTextStyle.text.copyWith(
                            color: AppColors.grayScale9,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: report.recommendations!.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = report.recommendations![index];
                              final itemStyle = AppTextStyle.body2R.copyWith(
                                color: AppColors.grayScale9,
                                height: 1.4,
                              );
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '•',
                                    style: itemStyle,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: itemStyle,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 피그마 v.4 추천 카드 하단 부연 멘트
                        Text(
                          SpeechDictionary.get(SpeechKey.weeklyReportRecommendationFooter, isHonorific),
                          style: AppTextStyle.body2R.copyWith(
                            color: AppColors.grayScale9,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ] else ...[
                      // [월간] 주차별 요약 카드 목록
                      if (report.weeklySummaries != null &&
                          report.weeklySummaries!.isNotEmpty) ...[
                        for (final summary in report.weeklySummaries!) ...[
                          const SizedBox(height: 20),
                          // 주차 타이틀 (카드 상단 배치)
                          Text(
                            summary.weekTitle,
                            style: AppTextStyle.body2SB.copyWith(
                              color: AppColors.mainColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 흰색 요약 카드
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              summary.description,
                              style: AppTextStyle.body2R.copyWith(
                                color: AppColors.grayScale9,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                      // 피그마 v.4 월간 리포트 하단 마무리 회고 요약글 렌더링
                      if (report.wrapUp != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          report.wrapUp!.replaceAll('00', userName),
                          style: AppTextStyle.text.copyWith(
                            color: AppColors.grayScale9,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
