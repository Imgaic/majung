import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_options.dart';

import 'providers/user_provider.dart';
import 'repositories/user_repository.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'services/calendar_service.dart';

import 'theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

bool isFirebaseEnabled = false;

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

    if (kDebugMode) {
      // 실물 아이폰 기기 테스트를 위해 맥북의 실제 로컬 IP 주소(172.30.1.43)를 가리키도록 설정합니다.
      final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '172.30.1.43';
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5002);
      debugPrint('Firebase: Using Functions emulator at $host:5002');
    }

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
      await LocalNotificationService.initialize(); // 로컬 알림 초기화 및 클릭 핸들러 사전 등록
      await FcmService.initialize(uid: uid, requestPermission: false);

      // 오늘 캘린더 일정 Firestore 동기화 (모바일에서만 동작)
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        final todayEvents = await CalendarService.getTodayEvents(requestPermission: false);
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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

/// 로그인 화면: 스플래시 형태로 작동하며, 1.5초 노출 후 자동 로그인 여부에 따라 홈 또는 온보딩 화면으로 스르륵 전환됩니다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // 진입 시 즉시 스플래시 시퀀스 작동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSplashSequence();
    });
  }

  Future<void> _runSplashSequence() async {
    // 최소 1.5초 스플래시 화면 노출 보장
    final delay = Future.delayed(const Duration(milliseconds: 1500));

    try {
      final auth = FirebaseAuth.instance;
      // 1. Firebase 익명 로그인 보장
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
        debugPrint('Splash: Anonymous sign-in success. UID = ${auth.currentUser?.uid}');
      }

      // 2. 온보딩 완료 정보 조회
      final repo = ref.read(userRepositoryProvider);
      final settings = await repo.getUserSettings();
      final isOnboardingDone = settings != null && (settings['name'] as String? ?? '').isNotEmpty;

      // 3. 최소 노출 대기 완료 대기
      await delay;

      if (!mounted) return;

      // 4. 스르륵 (Fade Transition) 화면 라우팅 전환
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              isOnboardingDone ? const HomeScreen() : const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
          settings: RouteSettings(name: isOnboardingDone ? '/home' : '/onboarding'),
        ),
      );
    } catch (e) {
      debugPrint('Splash Sequence Error: $e');
      // 에러 발생 시에도 최소 시간을 채우고 안전하게 온보딩으로 진행
      await delay;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
          settings: const RouteSettings(name: '/onboarding'),
        ),
      );
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
