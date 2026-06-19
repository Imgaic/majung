import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import '../repositories/diary_repository.dart';
import '../services/gemini_service.dart';
import '../services/local_notification_service.dart';
import 'notification_provider.dart';
import '../main.dart'; // selectedStyleProvider

final reportRepositoryProvider = Provider((ref) => ReportRepository());
final diaryRepositoryForReportProvider = Provider((ref) => DiaryRepository());

/// 편지 보관함 전체 목록 상태를 관리하는 Notifier.
class ReportListNotifier extends Notifier<List<ReportLetter>> {
  ReportRepository get _repo => ref.read(reportRepositoryProvider);

  @override
  List<ReportLetter> build() {
    _init();
    return [];
  }

  Future<void> _init() async {
    if (_repo.isEnabled) {
      final list = await _repo.getReports();
      state = list;
    }
  }

  /// 주간 또는 월간 리포트를 AI로 생성하고 저장합니다.
  Future<void> generateReport({
    required String userName,
    required bool isWeekly,
  }) async {
    final diaryRepo = ref.read(diaryRepositoryForReportProvider);
    final reportRepo = _repo;

    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${d.year}.${pad(d.month)}.${pad(d.day)}';

    final String fromStr;
    final String toStr;
    final String dateRange;

    if (isWeekly) {
      final to = now.subtract(const Duration(days: 1));
      final from = to.subtract(const Duration(days: 6));
      fromStr = fmt(from);
      toStr = fmt(to);
      dateRange = '$fromStr ~ $toStr';
    } else {
      // 이번 달 1일 ~ 오늘
      fromStr = fmt(DateTime(now.year, now.month, 1));
      toStr = fmt(now);
      dateRange = '$fromStr ~ $toStr';
    }

    final diaries = await diaryRepo.getDiariesInRange(fromStr, toStr);
    final diaryMaps = diaries.map((d) => d.toJson()).toList();

    final isHonorific = ref.read(selectedStyleProvider) == 1;

    final result = await GeminiService.generateReport(
      userName: userName,
      isWeekly: isWeekly,
      dateRange: dateRange,
      diaries: diaryMaps,
      isHonorific: isHonorific,
    );

    final reportId = isWeekly
        ? 'weekly_${fromStr.replaceAll('.', '')}'
        : 'monthly_${toStr.substring(0, 7).replaceAll('.', '')}';

    final String calculatedTitle;
    if (isWeekly) {
      final parts = fromStr.split('.');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final startDate = DateTime(year, month, day);
      
      final firstDay = DateTime(startDate.year, startDate.month, 1);
      final firstWeekday = firstDay.weekday; // 1 = Monday, 7 = Sunday
      final dayOffset = startDate.day + firstWeekday - 2;
      final weekNum = (dayOffset / 7).floor() + 1;
      
      final weekWords = ['첫째', '둘째', '셋째', '넷째', '다섯째', '여섯째'];
      final weekWord = (weekNum >= 1 && weekNum <= 6) ? weekWords[weekNum - 1] : '$weekNum째';
      
      calculatedTitle = '$month월 $weekWord 주';
    } else {
      final parts = fromStr.split('.');
      final month = int.parse(parts[1]);
      calculatedTitle = '$month월의 기록';
    }

    final report = ReportLetter(
      id: reportId,
      title: calculatedTitle,
      dateRange: dateRange,
      isWeekly: isWeekly,
      isRead: false,
      isNew: true,
      oneLiner: result['oneLiner'] as String? ?? '',
      content: result['content'] as String? ?? '',
      signature: result['signature'] as String? ?? '',
      wrapUp: result['wrapUp'] as String?,
      recommendationTitle: isWeekly
          ? result['recommendationTitle'] as String?
          : null,
      recommendations: isWeekly
          ? (result['recommendations'] as List?)
                ?.map((e) => e as String)
                .toList()
          : null,
      weeklySummaries: isWeekly
          ? null
          : (result['weeklySummaries'] as List?)?.map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return WeeklySummary(
                weekTitle: m['weekTitle'] as String? ?? '',
                description: m['description'] as String? ?? '',
              );
            }).toList(),
    );

    await reportRepo.saveReport(report);
    state = [report, ...state.where((r) => r.id != reportId)];

    final String notifTitle;
    if (isWeekly) {
      notifTitle = isHonorific ? '$calculatedTitle 편지가 도착했어요' : '$calculatedTitle 편지가 도착했어';
    } else {
      notifTitle = isHonorific ? '$calculatedTitle이 도착했어요' : '$calculatedTitle이 도착했어';
    }

    await LocalNotificationService.show(
      title: notifTitle,
      body: isHonorific ? '마중이의 따뜻한 리포트를 확인해 보세요.' : '마중이의 따뜻한 리포트를 확인해 봐.',
      payload: 'report',
    );

    // Save report notification to Firestore/Notification List
    await ref.read(notificationListProvider.notifier).addNotification(notifTitle);
  }

  /// 특정 편지를 읽음 처리합니다 (isRead -> true, isNew -> false).
  Future<void> markAsRead(String id) async {
    state = [
      for (final report in state)
        if (report.id == id)
          report.copyWith(isRead: true, isNew: false)
        else
          report,
    ];

    await _repo.updateReportReadStatus(id, isRead: true, isNew: false);
  }

  /// 시연/테스트 등을 위해 리포트를 직접 저장/목록 갱신하는 메서드
  Future<void> addDummyReport(ReportLetter report) async {
    if (_repo.isEnabled) {
      await _repo.saveReport(report);
    }
    state = [report, ...state.where((r) => r.id != report.id)];
  }
}

/// 전체 리포트 편지 리스트 공급자
final reportListProvider =
    NotifierProvider<ReportListNotifier, List<ReportLetter>>(
      ReportListNotifier.new,
    );

/// 편지 보관함 탭 선택 상태 관리 (0: 주간, 1: 월간)
class ReportTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void selectTab(int tabIndex) {
    state = tabIndex;
  }
}

/// 탭 선택 상태 제공자
final reportTabProvider = NotifierProvider<ReportTabNotifier, int>(
  ReportTabNotifier.new,
);

/// 탭 필터링 조건에 따라 주간 혹은 월간 리스트를 가공하여 제공하는 Computed Provider
final filteredReportsProvider = Provider<List<ReportLetter>>((ref) {
  final reports = ref.watch(reportListProvider);
  final activeTab = ref.watch(reportTabProvider);

  // activeTab == 0 이면 주간(isWeekly == true), 1 이면 월간(isWeekly == false)
  final filterWeekly = activeTab == 0;
  return reports.where((r) => r.isWeekly == filterWeekly).toList();
});
