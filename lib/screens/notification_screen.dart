import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/notification_card.dart';
import '../providers/notification_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../services/local_notification_service.dart';

/// 피그마 "알림" 화면(node 100:1488)의 레이아웃을 반영한 고충실도 알림 목록 스크린.
/// 알림 클릭 시 읽음으로 자동 상태 업데이트(빨간색/코랄색 미독 마크 해제) 처리됩니다.
class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CustomAppBar(
        title: '알림',
        titleStyle: AppTextStyle.body2B,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _TestNotifButton(
                      label: '마중이 답장',
                      title: '마중이의 답장이 도착했어요',
                      body: '오늘 하루도 고생 많았어. 일기 확인해봐.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TestNotifButton(
                      label: '일기 리마인더',
                      title: '오늘 하루는 어떠셨어요?',
                      body: '마중이가 기다리고 있어요. 오늘의 이야기를 들려주세요.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TestNotifButton(
                      label: '주간 리포트',
                      title: '주간 리포트가 도착했어요',
                      body: '이번 주 감정 흐름을 확인해보세요.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: notifications.isEmpty
            ? const Center(
                child: Text(
                  '알림이 없습니다.',
                  style: AppTextStyle.body2R,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8), // 피그마 실측 8px 간격
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return NotificationCard(
                    title: item.title,
                    date: item.date,
                    isUnread: item.isUnread,
                    onTap: () {
                      ref.read(notificationListProvider.notifier).markAsRead(item.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestNotifButton extends ConsumerWidget {
  final String label;
  final String title;
  final String body;

  const _TestNotifButton({
    required this.label,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () {
        LocalNotificationService.show(title: title, body: body);
        ref.read(notificationListProvider.notifier).addLocal(title);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        side: const BorderSide(color: AppColors.mainColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: AppTextStyle.caption1.copyWith(color: AppColors.mainColor)),
    );
  }
}
