import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gemini_service.dart';
import '../services/calendar_service.dart';
import 'user_provider.dart';
import '../main.dart';

class HomeGreetingNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    ref.keepAlive(); // 홈 화면 벗어나도 캐시 유지 → 재진입 시 재호출 방지
    final userName = ref.watch(userNameProvider);
    final isHonorific = ref.watch(selectedStyleProvider) == 1;
    return _fetch(userName, isHonorific);
  }

  Future<String> _fetch(String userName, bool isHonorific) async {
    final todayEvents = await CalendarService.getTodayEvents();

    try {
      final result = await GeminiService.generateHomeGreeting(
        userName: userName,
        isHonorific: isHonorific,
        todayEvents: todayEvents,
      );
      final greeting = result['greeting'] as String?;
      if (greeting != null && greeting.isNotEmpty) return greeting;
    } catch (_) {}

    // AI 호출 전체 실패 시 말투에 맞는 정적 문구
    if (isHonorific) {
      return '오늘 하루도 잘 부탁드려요, $userName님.';
    }
    // 이름 마지막 글자 받침 여부에 따라 아/야 구분
    final code = userName.codeUnitAt(userName.length - 1);
    final hasFinalConsonant = (code - 0xAC00) % 28 != 0;
    final suffix = hasFinalConsonant ? '아' : '야';
    return '오늘 하루도 잘 부탁해, $userName$suffix.';
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
  }
}

final homeGreetingProvider =
    AsyncNotifierProvider<HomeGreetingNotifier, String>(
      HomeGreetingNotifier.new,
    );
