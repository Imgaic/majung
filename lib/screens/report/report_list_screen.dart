import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../widgets/letter_card.dart';
import '../../widgets/mini_segmented_slider.dart';
import '../../providers/report_provider.dart';
import 'report_detail_screen.dart';

import '../../widgets/custom_app_bar.dart';

/// 피그마 "편지 보관함 (리포트 목록)" 화면 (node 16:70) 구현.
/// 상단 주간 / 월간 전환용 탭을 제공하며, 탭에 해당하는 편지 리스트를 렌더링합니다.
class ReportListScreen extends ConsumerStatefulWidget {
  const ReportListScreen({super.key});

  @override
  ConsumerState<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends ConsumerState<ReportListScreen> {
  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(reportTabProvider);
    final reportList = ref.watch(filteredReportsProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CustomAppBar(
        title: '편지 보관함',
        titleStyle: AppTextStyle.body2B,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // 1. 주간/월간 세그먼트 탭바 (MiniSegmentedSlider 재사용)
              Center(
                child: MiniSegmentedSlider(
                  selectedIndex: activeTab,
                  onChanged: (index) {
                    ref.read(reportTabProvider.notifier).selectTab(index);
                  },
                  labels: const ['주간', '월간'],
                ),
              ),
              const SizedBox(height: 12),

              // 2. 편지 카드 목록 렌더링
              Expanded(
                child: reportList.isEmpty
                  ? Center(
                      child: Text(
                        activeTab == 0 ? '수신된 주간 편지가 없습니다.' : '수신된 월간 편지가 없습니다.',
                        style: AppTextStyle.caption1.copyWith(
                          color: AppColors.gray4,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: reportList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final report = reportList[index];
                        return LetterCard(
                          title: report.title,
                          subtitle: report.dateRange,
                          isRead: report.isRead,
                          isNew: report.isNew,
                          onTap: () {
                            // 읽음 상태 업데이트 (Riverpod)
                            ref
                                .read(reportListProvider.notifier)
                                .markAsRead(report.id);

                            // 리포트 상세 페이지로 이동
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportDetailScreen(
                                  reportId: report.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
