import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository());

/// 알림 목록 및 개별 알림의 읽음(확인) 상태를 관리하는 Notifier.
class NotificationListNotifier extends Notifier<List<NotificationItem>> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  List<NotificationItem> build() {
    _init();
    return [];
  }

  Future<void> _init() async {
    if (_repo.isEnabled) {
      final list = await _repo.getNotifications();
      state = list;
    }
  }

  /// 특정 알림을 확인(읽음) 처리하는 메서드
  Future<void> markAsRead(String id) async {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isUnread: false) else item
    ];

    await _repo.updateNotificationReadStatus(id, isUnread: false);
  }

  /// 로컬 테스트용: 알림 목록 상단에 항목 추가
  void addLocal(String title) {
    final now = DateTime.now();
    final date = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    final item = NotificationItem(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      date: date,
      isUnread: true,
    );
    state = [item, ...state];
  }

  /// 모든 알림을 확인 처리하는 메서드 (추후 전역 제어 대비)
  Future<void> markAllAsRead() async {
    final oldState = List<NotificationItem>.from(state);
    state = [for (final item in state) item.copyWith(isUnread: false)];

    await _repo.markAllNotificationsAsRead(oldState);
  }
}

final notificationListProvider =
    NotifierProvider<NotificationListNotifier, List<NotificationItem>>(
        NotificationListNotifier.new);
