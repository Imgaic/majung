import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import '../utils/datetime_extension.dart';

final activityRepositoryProvider = Provider((ref) => ActivityRepository());

/// 추천 활동 목록 상태를 관리하는 Riverpod Notifier.
class ActivityListNotifier extends Notifier<List<RecommendationActivity>> {
  ActivityRepository get _repo => ref.read(activityRepositoryProvider);

  @override
  List<RecommendationActivity> build() {
    _init();
    return [];
  }

  Future<void> _init() async {
    if (_repo.isEnabled) {
      final list = await _repo.getActivities();
      _sortActivities(list);
      state = list;
    }
  }

  /// 새로운 활동을 추천받아 목록에 추가하거나 기존 활동의 선택 날짜를 누적합니다. (중복 처리)
  Future<void> addActivity(String title, {String? date}) async {
    final cleanDate = date ?? DateTime.now().toDotString();

    // 중복 여부 확인
    final existingIndex = state.indexWhere((act) => act.title == title);
    if (existingIndex != -1) {
      final existingActivity = state[existingIndex];
      final updatedDates = existingActivity.selectedDates.contains(cleanDate)
          ? existingActivity.selectedDates
          : [...existingActivity.selectedDates, cleanDate];
      final updatedActivity = existingActivity.copyWith(selectedDates: updatedDates);

      final updatedList = [...state];
      updatedList[existingIndex] = updatedActivity;
      _sortActivities(updatedList);
      state = updatedList;

      if (_repo.isEnabled) {
        await _repo.updateActivityLike(updatedActivity); // Firestore에 업데이트
      }
      return;
    }

    final newActivity = RecommendationActivity(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      isLiked: false,
      selectedDates: [cleanDate],
    );

    final updatedList = [...state, newActivity];
    _sortActivities(updatedList);
    state = updatedList;
    
    if (_repo.isEnabled) {
      await _repo.updateActivityLike(newActivity); // Firestore에 저장
    }
  }

  /// 특정 활동의 타이틀을 받아 목록에서 삭제합니다. (Firestore 동기화 포함)
  Future<void> removeActivityByTitle(String title) async {
    final targets = state.where((act) => act.title == title).toList();
    if (targets.isEmpty) return;

    final targetId = targets.first.id;
    state = state.where((act) => act.title != title).toList();

    if (_repo.isEnabled) {
      await _repo.deleteActivity(targetId);
    }
  }

  /// 특정 활동의 선택 날짜 이력에서 특정 날짜를 제거합니다.
  /// 날짜 이력이 완전히 비면 해당 활동을 완전히 삭제합니다. (좋아요 상태 여부 무시)
  Future<void> removeActivityDate(String title, String date) async {
    final existingIndex = state.indexWhere((act) => act.title == title);
    if (existingIndex == -1) return;

    final activity = state[existingIndex];
    final updatedDates = activity.selectedDates.where((d) => d != date).toList();

    if (updatedDates.isEmpty) {
      // 날짜 목록이 비어있으면 활동 삭제
      state = state.where((act) => act.title != title).toList();
      if (_repo.isEnabled) {
        await _repo.deleteActivity(activity.id);
      }
    } else {
      // 그렇지 않으면 날짜만 갱신
      final updatedActivity = activity.copyWith(selectedDates: updatedDates);
      final updatedList = [...state];
      updatedList[existingIndex] = updatedActivity;
      _sortActivities(updatedList);
      state = updatedList;

      if (_repo.isEnabled) {
        await _repo.updateActivityLike(updatedActivity); // Firestore에 업데이트
      }
    }
  }

  /// 특정 활동의 좋아요(하트) 상태를 토글합니다.
  Future<void> toggleLike(String id) async {
    RecommendationActivity? target;
    final updatedList = state.map((act) {
      if (act.id == id) {
        target = act.copyWith(isLiked: !act.isLiked);
        return target!;
      }
      return act;
    }).toList();

    state = updatedList;

    if (target != null) {
      await _repo.updateActivityLike(target!);
    }
  }

  /// 활동 목록을 가장 최근 선택 날짜(selectedDates.last) 기준으로 내림차순 정렬합니다.
  void _sortActivities(List<RecommendationActivity> list) {
    list.sort((a, b) {
      final aDate = a.selectedDates.lastOrNull ?? '';
      final bDate = b.selectedDates.lastOrNull ?? '';
      
      if (aDate != bDate) {
        if (aDate.isEmpty) return 1;
        if (bDate.isEmpty) return -1;
        return bDate.compareTo(aDate);
      }
      return b.id.compareTo(a.id);
    });
  }
}

/// 전체 활동 목록 상태 제공 프로바이더
final activityListProvider =
    NotifierProvider<ActivityListNotifier, List<RecommendationActivity>>(
  ActivityListNotifier.new,
);

/// 좋아요 필터 활성화 여부 상태를 관리하는 Notifier.
class BehaviorFilterNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

/// 좋아요 필터 활성화 여부 상태 제공 프로바이더 (true: 좋아요만 보기, false: 전체 보기)
final behaviorFilterProvider =
    NotifierProvider<BehaviorFilterNotifier, bool>(BehaviorFilterNotifier.new);

/// 필터 조건에 맞게 가공된 활동 목록을 계산(Computed)하여 반환하는 프로바이더
final filteredActivitiesProvider = Provider<List<RecommendationActivity>>((ref) {
  final activities = ref.watch(activityListProvider);
  final showOnlyLiked = ref.watch(behaviorFilterProvider);

  if (showOnlyLiked) {
    return activities.where((act) => act.isLiked).toList();
  }
  return activities;
});
