import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import '../repositories/report_repository.dart';
import '../repositories/diary_repository.dart';
import '../services/gemini_service.dart';
import '../services/local_notification_service.dart';

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
    final pad = (int n) => n.toString().padLeft(2, '0');
    final fmt = (DateTime d) => '${d.year}.${pad(d.month)}.${pad(d.day)}';

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

    final result = await GeminiService.generateReport(
      userName: userName,
      isWeekly: isWeekly,
      dateRange: dateRange,
      diaries: diaryMaps,
    );

    final reportId = isWeekly
        ? 'weekly_${fromStr.replaceAll('.', '')}'
        : 'monthly_${toStr.substring(0, 7).replaceAll('.', '')}';

    Map<bool, String> boolMap(String honorific, String casual) =>
        {true: honorific, false: casual};

    final report = ReportLetter(
      id: reportId,
      title: result['title'] as String? ?? dateRange,
      dateRange: dateRange,
      isWeekly: isWeekly,
      isRead: false,
      isNew: true,
      oneLiner: boolMap(
        result['oneLiner_honorific'] as String? ?? '',
        result['oneLiner_casual'] as String? ?? '',
      ),
      content: boolMap(
        result['content_honorific'] as String? ?? '',
        result['content_casual'] as String? ?? '',
      ),
      signature: boolMap(
        result['signature_honorific'] as String? ?? '',
        result['signature_casual'] as String? ?? '',
      ),
      wrapUp: isWeekly ? null : boolMap(
        result['wrapUp_honorific'] as String? ?? '',
        result['wrapUp_casual'] as String? ?? '',
      ),
      recommendationTitle: isWeekly ? result['recommendationTitle'] as String? : null,
      recommendations: isWeekly
          ? (result['recommendations'] as List?)?.map((e) => e as String).toList()
          : null,
      weeklySummaries: isWeekly
          ? null
          : (result['weeklySummaries'] as List?)?.map((e) {
              final m = e as Map<String, dynamic>;
              return WeeklySummary(
                weekTitle: m['weekTitle'] as String? ?? '',
                description: m['description'] as String? ?? '',
              );
            }).toList(),
    );

    await reportRepo.saveReport(report);
    state = [report, ...state.where((r) => r.id != reportId)];

    final notifTitle = isWeekly ? '주간 리포트가 도착했어요' : '월간 리포트가 도착했어요';
    await LocalNotificationService.show(title: notifTitle, body: report.title);
  }

  /// 특정 편지를 읽음 처리합니다 (isRead -> true, isNew -> false).
  Future<void> markAsRead(String id) async {
    state = [
      for (final report in state)
        if (report.id == id)
          report.copyWith(isRead: true, isNew: false)
        else
          report
    ];

    await _repo.updateReportReadStatus(id, isRead: true, isNew: false);
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
