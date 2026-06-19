import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../widgets/app_icons.dart';
import '../main.dart';
import '../providers/user_provider.dart';
import 'onboarding/widgets/onboarding_intro_step.dart';
import 'onboarding/widgets/onboarding_calendar_step.dart';
import 'onboarding/widgets/onboarding_name_step.dart';
import 'onboarding/widgets/onboarding_tone_step.dart';
import 'home_screen.dart';

/// 피그마 고충실도 매칭을 완료한 마중(Majung) 온보딩 시퀀스 컨테이너 스크린.
/// GEMINI.md 5장의 파일 모듈화 및 위젯 분리 규칙에 의거하여, 각 단계의 뷰를
/// 독립 스텝 컴포넌트로 완전히 격리하여 다이어트된 코드로 유지보수성을 극대화함.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // 온보딩 입력/선택 상태 데이터
  final TextEditingController _nameController = TextEditingController();
  int _selectedTone = 0; // 0: 반말, 1: 존댓말

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // 모든 온보딩 최종 단계를 정상 완수하면 상태를 동기화하고 홈 화면으로 전환
      ref.read(userNameProvider.notifier).updateName(_nameController.text);
      ref.read(selectedStyleProvider.notifier).select(_selectedTone);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
          settings: const RouteSettings(name: '/home'),
        ),
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // 피그마 논리 구조상 온보딩 1~3단계(0, 1, 2 index) 최초 진입상태에서는
        // 뒤로가기 동작을 완전히 은닉(AppBar leading null 및 imply false) 처리함.
        leading: _currentPage >= 3
            ? IconButton(
                icon: SvgPicture.asset(
                  AppIcons.arrowBack,
                  width: 24,
                  height: 24,
                ),
                onPressed: _prevPage,
              )
            : null,
        title: _buildProgressBar(_currentPage),
        centerTitle: true,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          // 4단계부터는 유효성 확인을 강제하기 위해 손가락 스와이프를 막고 버튼 제어 적용
          physics: _currentPage >= 3
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          onPageChanged: (page) {
            setState(() {
              _currentPage = page;
            });
          },
          children: [
            // 1단계: 소개 1 (나만의 맞춤)
            OnboardingIntroStep(
              bubbleText: '안녕하세요!\n여기선 일기를 써야 한다는\n부담은 내려 놓으세요.',
              subTitle: '나만을 위한 맞춤 일기 서비스',
              onNextPressed: _nextPage,
            ),
            // 2단계: 소개 2 (대화로 쓰기)
            OnboardingIntroStep(
              bubbleText: '저와의 대화가 끝나면, 우리가 나눈\n이야길 모아 하루를 기록해 드릴게요!',
              subTitle: '대화로 완성되는 쉬운 일기',
              onNextPressed: _nextPage,
            ),
            // 3단계: 소개 3 (기분 전환 해결책 제안)
            OnboardingIntroStep(
              bubbleText: '지친 하루에는 마음을 달래줄\n해결책도 알려드려요!',
              subTitle: '대화를 바탕으로\n건강한 기분 전환 해결책 제안',
              onNextPressed: _nextPage,
            ),
            // 4단계: 캘린더 동기화 동의
            OnboardingCalendarStep(
              onNextPressed: _nextPage,
            ),
            // 5단계: 이름 입력
            OnboardingNameStep(
              controller: _nameController,
              onNextPressed: _nextPage,
            ),
            // 6단계: 말투 선택
            OnboardingToneStep(
              initialTone: _selectedTone,
              onToneChanged: (tone) {
                _selectedTone = tone;
              },
              onNextPressed: _nextPage,
            ),
          ],
        ),
      ),
    );
  }

  // 상단 진행상황을 알려주는 가로 세그먼트 프로그레스 인디케이터
  Widget _buildProgressBar(int currentStep) {
    return SizedBox(
      height: 4,
      width: 140,
      child: Row(
        children: List.generate(6, (index) {
          final isPassed = index <= currentStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: isPassed ? AppColors.mainColor : AppColors.gray2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
