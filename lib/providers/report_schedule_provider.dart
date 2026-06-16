import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kWeeklyDayKey = 'report_weekly_day';   // 1=월 ~ 7=일 (DateTime.weekday 기준)
const _kMonthlyDayKey = 'report_monthly_day'; // 1~28

class ReportSchedule {
  final int weeklyDay;   // 1=월요일 ~ 7=일요일
  final int monthlyDay;  // 1~28

  const ReportSchedule({this.weeklyDay = 1, this.monthlyDay = 1});

  ReportSchedule copyWith({int? weeklyDay, int? monthlyDay}) => ReportSchedule(
        weeklyDay: weeklyDay ?? this.weeklyDay,
        monthlyDay: monthlyDay ?? this.monthlyDay,
      );
}

class ReportScheduleNotifier extends AsyncNotifier<ReportSchedule> {
  @override
  Future<ReportSchedule> build() async {
    final prefs = await SharedPreferences.getInstance();
    return ReportSchedule(
      weeklyDay: prefs.getInt(_kWeeklyDayKey) ?? 1,
      monthlyDay: prefs.getInt(_kMonthlyDayKey) ?? 1,
    );
  }

  ReportSchedule get _current =>
      state.when(data: (v) => v, loading: () => const ReportSchedule(), error: (_, __) => const ReportSchedule());

  Future<void> setWeeklyDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWeeklyDayKey, day);
    state = AsyncData(_current.copyWith(weeklyDay: day));
  }

  Future<void> setMonthlyDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMonthlyDayKey, day);
    state = AsyncData(_current.copyWith(monthlyDay: day));
  }

  /// 앱 시작 시 호출 — 오늘이 설정한 요일/일이면 true 반환
  bool shouldGenerateWeekly() {
    final s = state.when(data: (v) => v, loading: () => null, error: (_, __) => null);
    if (s == null) return false;
    return DateTime.now().weekday == s.weeklyDay;
  }

  bool shouldGenerateMonthly() {
    final s = state.when(data: (v) => v, loading: () => null, error: (_, __) => null);
    if (s == null) return false;
    return DateTime.now().day == s.monthlyDay;
  }
}

final reportScheduleProvider =
    AsyncNotifierProvider<ReportScheduleNotifier, ReportSchedule>(
        ReportScheduleNotifier.new);
