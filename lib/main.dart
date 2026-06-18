import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'providers/user_provider.dart';
import 'repositories/user_repository.dart';
import 'services/fcm_service.dart';
import 'utils/calendar_service.dart';

import 'theme.dart';
import 'widgets/custom_button.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

bool isFirebaseEnabled = false;
bool isCloudFunctionsEnabled = true;

// 1. 대화 스타일 세그먼트 상태 공급자 (0: 반말, 1: 높임말)
class SelectedStyle extends Notifier<int> {
  UserRepository get _repo => ref.read(userRepositoryProvider);

  @override
  int build() {
    _init();
    return 0;
  }

  Future<void> _init() async {
    final settings = await _repo.getUserSettings();
    if (settings != null && settings['selectedStyle'] != null) {
      state = settings['selectedStyle'] as int;
    }
  }

  Future<void> select(int val) async {
    state = val;
    await _repo.saveUserSettings(selectedStyle: val);
  }
}
final selectedStyleProvider = NotifierProvider<SelectedStyle, int>(SelectedStyle.new);

// 2. 푸시 알림 설정 토글 상태 공급자
class ToggleState extends Notifier<bool> {
  UserRepository get _repo => ref.read(userRepositoryProvider);

  @override
  bool build() {
    _init();
    return false;
  }

  Future<void> _init() async {
    final settings = await _repo.getUserSettings();
    if (settings != null && settings['notificationEnabled'] != null) {
      state = settings['notificationEnabled'] as bool;
    }
  }

  Future<void> toggle(bool val) async {
    state = val;
    await _repo.saveUserSettings(notificationEnabled: val);
  }
}
final toggleStateProvider = NotifierProvider<ToggleState, bool>(ToggleState.new);


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseEnabled = true;
    debugPrint('Firebase: Successfully initialized');

    // 익명 로그인 수행
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      debugPrint('Firebase: Anonymous sign-in success. UID = ${auth.currentUser?.uid}');
    } else {
      debugPrint('Firebase: Already signed in. UID = ${auth.currentUser?.uid}');
    }

    // FCM 서비스 초기화 및 토큰 동기화
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      await FcmService.initialize(uid: uid);

      // 오늘 캘린더 일정 Firestore 동기화 (모바일에서만 동작)
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        final todayEvents = await CalendarService.getTodayEvents();
        await FcmService.syncTodayEvents(uid: uid, events: todayEvents);
      }
    }
  } catch (e) {
    debugPrint('Firebase: Initialization failed. Error: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마중',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.mainColor,
          primary: AppColors.mainColor,
        ),
        scaffoldBackgroundColor: AppColors.white,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

/// 로그인 화면: 익명 로그인 후 온보딩 완료 여부에 따라 홈/온보딩으로 이동
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _start() async {
    setState(() => _isLoading = true);
    try {
      // 온보딩 완료 여부: Firestore에 name 필드 존재 여부로 판단
      final repo = ref.read(userRepositoryProvider);
      final settings = await repo.getUserSettings();
      final isOnboardingDone = settings != null && (settings['name'] as String? ?? '').isNotEmpty;

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isOnboardingDone
              ? const HomeScreen()
              : const OnboardingScreen(),
          settings: RouteSettings(name: isOnboardingDone ? '/home' : '/onboarding'),
        ),
      );
    } catch (e) {
      debugPrint('LoginScreen: 라우팅 오류: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/character.png',
                  width: 160,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '마중',
                textAlign: TextAlign.center,
                style: AppTextStyle.h1.copyWith(color: AppColors.grayScale9),
              ),
              const SizedBox(height: 12),
              Text(
                '오늘 하루, 마중이에게 털어놓아요.',
                textAlign: TextAlign.center,
                style: AppTextStyle.body2R.copyWith(color: AppColors.gray4),
              ),
              const Spacer(),
              CustomButton(
                label: _isLoading ? '로딩 중...' : '시작하기',
                isFullWidth: true,
                onPressed: _isLoading ? () {} : _start,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
