import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../widgets/letter_card.dart';
import '../../widgets/mini_segmented_slider.dart';
import '../../providers/report_provider.dart';
import 'report_detail_screen.dart';

import '../../widgets/custom_app_bar.dart';
import '../../providers/user_provider.dart';

/// 피그마 "편지 보관함 (리포트 목록)" 화면 (node 16:70) 구현.
/// 상단 주간 / 월간 전환용 탭을 제공하며, 탭에 해당하는 편지 리스트를 렌더링합니다.
class ReportListScreen extends ConsumerStatefulWidget {
  const ReportListScreen({super.key});

  @override
  ConsumerState<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends ConsumerState<ReportListScreen> {
  bool _isGenerating = false;

  Future<void> _generate(bool isWeekly) async {
    setState(() => _isGenerating = true);
    try {
      final userName = ref.read(userNameProvider);
      await ref.read(reportListProvider.notifier).generateReport(
        userName: userName,
        isWeekly: isWeekly,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${isWeekly ? '주간' : '월간'} 리포트가 생성됐어요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

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

              // 리포트 수동 생성 버튼 (테스트용)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isGenerating ? null : () => _generate(true),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.mainColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isGenerating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('주간 리포트 생성', style: AppTextStyle.caption1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isGenerating ? null : () => _generate(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.mainColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isGenerating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('월간 리포트 생성', style: AppTextStyle.caption1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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
