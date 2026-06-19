import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../main.dart'; // selectedStyleProvider
import '../../providers/user_provider.dart';
import '../../providers/diary_provider.dart';
import '../../models/diary_data.dart';
import '../../models/chat_message.dart';
import '../error_screen.dart';
import '../../utils/speech_dictionary.dart';
import '../../services/calendar_service.dart';
import '../onboarding/widgets/onboarding_illustration.dart';
import 'diary_completed_screen.dart';
import '../../utils/datetime_extension.dart';

/// 일기 생성을 기다리는 로딩 화면.
/// 피그마 시안 node 175:803 ("AI 대화(로딩)")을 기반으로 구현되었습니다.
class DiaryLoadingScreen extends ConsumerStatefulWidget {
  final List<String> imagePaths;
  final String? selectedActivity;
  final List<String> recommendedActions;
  final bool isDirectWrite;
  final String? directWriteTitle;
  final String? directWriteContent;
  final int? directWriteMood;
  final bool isReplyOnly;
  final List<ChatMessage> chatMessages;

  const DiaryLoadingScreen({
    super.key,
    this.imagePaths = const [],
    this.selectedActivity,
    this.recommendedActions = const [],
    this.isDirectWrite = false,
    this.directWriteTitle,
    this.directWriteContent,
    this.directWriteMood,
    this.isReplyOnly = false,
    this.chatMessages = const [],
  });

  @override
  ConsumerState<DiaryLoadingScreen> createState() => _DiaryLoadingScreenState();
}

class _DiaryLoadingScreenState extends ConsumerState<DiaryLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // 캐릭터 미세 펄스(Pulsing) 애니메이션 초기화 (Aesthetics 보강)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.03).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 비동기 처리 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runGeneration();
    });
  }

  Future<void> _runGeneration() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      final userName = ref.read(userNameProvider);
      final isHonorific = ref.read(selectedStyleProvider) == 1;

      // 캘린더 일정 연동
      final todayEvents = await CalendarService.getTodayEvents();

      if (widget.isDirectWrite) {
        if (widget.isReplyOnly) {
          // 1. 기존 직접 작성 일기에 마중이 답장만 생성
          await ref.read(diaryProvider.notifier).generateMascotFeedbackOnly(
                userName: userName,
                isHonorific: isHonorific,
                todayEvents: todayEvents,
              );
          if (!mounted) return;
          Navigator.pop(context);
        } else {
          // 2. 신규 직접 작성 일기 생성 (답장 없이 최초 저장)
          await Future.delayed(const Duration(milliseconds: 1500));
          final newDiary = DiaryData(
            date: DateTime.now().toDotString(),
            title: widget.directWriteTitle ?? '',
            content: widget.directWriteContent ?? '',
            mood: widget.directWriteMood ?? 3,
            imagePaths: widget.imagePaths,
            mascotFeedback: '', // 답장 받기 누르기 전까지 비어있음
            recommendedAction: '',
            isDirectWrite: true,
          );
          ref.read(diaryProvider.notifier).saveNewDiary(newDiary);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DiaryCompletedScreen(),
            ),
          );
        }
      } else {
        // 3. 대화 완료 기반 일기 생성
        await ref.read(diaryProvider.notifier).generateDiary(
              date: DateTime.now().toDotString(),
              imagePaths: widget.imagePaths,
              userName: userName,
              isHonorific: isHonorific,
              selectedActivity: widget.selectedActivity,
              recommendedActions: widget.recommendedActions,
              chatMessages: widget.chatMessages,
              todayEvents: todayEvents,
            );

        if (!mounted) return;

        final diary = ref.read(diaryProvider);
        if (diary != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DiaryCompletedScreen(),
            ),
          );
        } else {
          throw Exception('일기 데이터를 불러오지 못했습니다.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return ErrorScreen(
        title: '문제가 발생했어요!',
        message: _errorMessage,
        primaryButtonLabel: '다시 시도',
        onPrimaryPressed: _runGeneration,
        secondaryButtonLabel: '이전으로',
        onSecondaryPressed: () => Navigator.pop(context),
      );
    }

    final isHonorific = ref.watch(selectedStyleProvider) == 1;
    final loadingText = widget.isDirectWrite
        ? '오늘 하루를 들여다 보는 중...'
        : SpeechDictionary.get(SpeechKey.loadingDiary, isHonorific);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                loadingText,
                textAlign: TextAlign.center,
                style: AppTextStyle.body2B.copyWith(
                  color: AppColors.grayScale9,
                  height: 1.5,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              ScaleTransition(
                scale: _scaleAnimation,
                child: const OnboardingIllustration(scale: 1.0),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
