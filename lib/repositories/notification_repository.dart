import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'base_repository.dart';

class NotificationRepository extends BaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference? get _notificationsCollection {
    final uid = currentUid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  /// 알림을 저장합니다.
  Future<void> saveNotification(NotificationItem item) async {
    if (!isEnabled) return;
    try {
      await _notificationsCollection?.doc(item.id).set(item.toJson());
    } catch (e) {
      debugPrint('NotificationRepository: saveNotification error: $e');
    }
  }

  /// Firestore에서 알림 목록을 가져옵니다. 없으면 빈 리스트를 반환합니다.
  Future<List<NotificationItem>> getNotifications() async {
    if (!isEnabled) return [];
    try {
      final snapshot = await _notificationsCollection?.get();
      if (snapshot != null && snapshot.docs.isNotEmpty) {
        final list = snapshot.docs.map((doc) {
          return NotificationItem.fromJson(doc.data() as Map<String, dynamic>);
        }).toList();
        // 최신 알림이 위로 오도록 정렬 (내림차순)
        list.sort((a, b) => b.id.compareTo(a.id));
        return list;
      }
    } catch (e) {
      debugPrint('NotificationRepository: getNotifications error: $e');
    }
    return [];
  }

  /// 특정 알림을 읽음 처리합니다.
  Future<void> updateNotificationReadStatus(String id, {required bool isUnread}) async {
    if (!isEnabled) return;
    try {
      await _notificationsCollection?.doc(id).update({
        'isUnread': isUnread,
      });
    } catch (e) {
      debugPrint('NotificationRepository: updateNotificationReadStatus error: $e');
    }
  }

  /// 모든 알림을 읽음 처리합니다.
  Future<void> markAllNotificationsAsRead(List<NotificationItem> items) async {
    if (!isEnabled) return;
    try {
      final batch = _firestore.batch();
      final collection = _notificationsCollection;
      if (collection != null) {
        for (final item in items) {
          if (item.isUnread) {
            batch.update(collection.doc(item.id), {'isUnread': false});
          }
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('NotificationRepository: markAllNotificationsAsRead error: $e');
    }
  }
}
