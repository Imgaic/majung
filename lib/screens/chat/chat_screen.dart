import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import 'widgets/chat_bubble.dart';
import '../../widgets/mini_segmented_slider.dart';
import '../../models/chat_message.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/recommendation_bubble.dart';
import 'widgets/activity_recommendation_dialog.dart';
import '../../widgets/confirm_dialog.dart';
import 'widgets/image_source_sheet.dart';
import 'widgets/image_preview_bar.dart';
import 'widgets/chat_input_bar.dart';
import 'diary_loading_screen.dart';
import 'widgets/direct_write_view.dart';
import '../../main.dart'; // selectedStyleProvider
import '../../utils/speech_dictionary.dart';
import '../../providers/direct_write_provider.dart';
import '../../utils/datetime_extension.dart';
import '../../utils/calendar_service.dart';
import '../../providers/user_provider.dart';
import '../../services/gemini_service.dart';


/// 마중이 앱의 핵심 기능인 AI 대화 화면.
/// 모듈화된 위젯과 대화 상태 기계, 이미지 첨부 및 미리보기 대기 업로드 기능을 탑재하고 있습니다.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  int _toggleIndex = 0; // 0: 대화, 1: 쓰기
  bool _isInputActive = false;
  bool _isMascotTyping = false;
  String? _selectedImagePath; // 미리보기용 이미지 대기 상태
  String? _selectedActivity; // 사용자 추천 선택 활동
  final List<String> _recommendedActions = [
    '좋아하는 노래 들으며 산책하기',
    '따뜻한 물로 샤워하기',
    '따뜻한 차 한 잔 마시기',
  ];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChange);

    // 직접 작성 초기 상태 보장
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(directWriteProvider.notifier).clear();
      }
    });

    // 최초 마중이 환영 인사 메시지 적재 (사용자 말투 설정 반영)
    final isHonorific = ref.read(selectedStyleProvider) == 1;
    _messages.add(
      ChatMessage(
        id: 'm_init',
        sender: MessageSender.mascot,
        content: SpeechDictionary.get(SpeechKey.chatGreeting, isHonorific),
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChange);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChange() {
    final hasText = _inputController.text.trim().isNotEmpty;
    final hasImage = _selectedImagePath != null;
    final isActive = hasText || hasImage;
    if (_isInputActive != isActive) {
      setState(() {
        _isInputActive = isActive;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 이미지 가져오기 및 전송 대기 처리
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
          _onInputChange(); // 전송 활성화 상태 체크
        });
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ConfirmDialog(
            title: '이미지를 가져오는 중 오류가 발생했습니다: $e',
            cancelLabel: '',
            onConfirm: () {},
          ),
        );
      }
    }
  }

  /// 이미지 첨부 경로 선택 바텀 시트 호출
  void _showImagePickerSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return ImageSourceSheet(
          onSourceSelected: (source) {
            Navigator.pop(context);
            _pickImage(source);
          },
        );
      },
    );
  }

  /// 사용자 메시지 전송 처리 (실시간 AI 대화 연동)
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    final imagePath = _selectedImagePath;

    if (text.isEmpty && imagePath == null) return;

    _inputController.clear();

    final userMsg = ChatMessage(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      content: text,
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );

    setState(() {
      _selectedImagePath = null;
      _isInputActive = false;
      _messages.add(userMsg);
      _isMascotTyping = true;
    });

    _scrollToBottom();

    try {
      final userName = ref.read(userNameProvider);
      final isHonorific = ref.read(selectedStyleProvider) == 1;

      // 캘린더 일정 연동
      final todayEvents = await CalendarService.getTodayEvents();

      final List<Map<String, dynamic>> serializedMessages = _messages.map((m) => {
        'sender': m.sender == MessageSender.user ? 'user' : 'mascot',
        'content': m.content,
      }).toList();

      final resultData = await GeminiService.chatWithMascot(
        messages: serializedMessages,
        userName: userName,
        isHonorific: isHonorific,
        todayEvents: todayEvents,
      );
      final reply = resultData['reply'] as String? ?? SpeechDictionary.get(SpeechKey.chatFallbackReply, isHonorific);
      final shouldRecommend = resultData['shouldRecommendActions'] as bool? ?? false;
      final List<dynamic>? recommendedList = resultData['recommendedActions'] as List<dynamic>?;

      if (!mounted) return;

      setState(() {
        _isMascotTyping = false;
        
        // 마중이 응답 추가
        _messages.add(
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.mascot,
            content: reply,
            timestamp: DateTime.now(),
          ),
        );

        // 활동 추천 노출 타이밍인 경우
        if (shouldRecommend && recommendedList != null && recommendedList.isNotEmpty) {
          final List<String> acts = recommendedList.map((e) => e as String).toList();
          
          _recommendedActions.clear();
          _recommendedActions.addAll(acts);

          _messages.add(
            ChatMessage(
              id: 'm_${DateTime.now().millisecondsSinceEpoch}_recommend',
              sender: MessageSender.mascot,
              content: SpeechDictionary.get(SpeechKey.activityRecommendationPrompt, isHonorific),
              timestamp: DateTime.now(),
              type: MessageType.activityRecommendation,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('chatWithMascot error: $e');
      if (!mounted) return;
      setState(() {
        _isMascotTyping = false;
        _messages.add(
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}_error',
            sender: MessageSender.mascot,
            content: '[AI 오류] $e',
            timestamp: DateTime.now(),
          ),
        );
      });
    }

    _scrollToBottom();
  }

  /// 활동 추천 받기 탭 시 피그마의 `활동 추천 모달` 호출
  void _showActivityRecommendationModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ActivityRecommendationDialog(
          activities: _recommendedActions,
          onActivitySelected: _selectActivity,
          onSkip: _skipActivityRecommendation,
        );
      },
    );
  }

  /// 추천 활동을 선택했을 때 피드백 전송
  void _selectActivity(String activityLabel) {
    setState(() {
      _selectedActivity = activityLabel;
      // 사용자의 답변으로 활동 추가
      _messages.add(
        ChatMessage(
          id: 'u_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.user,
          content: '$activityLabel 활동을 추천받아 볼래!',
          timestamp: DateTime.now(),
        ),
      );
      _isMascotTyping = true;
    });

    _scrollToBottom();

    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final isHonorific = ref.read(selectedStyleProvider) == 1;
      setState(() {
        _isMascotTyping = false;
        _messages.add(
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.mascot,
            content: SpeechDictionary.get(SpeechKey.activitySelectedReply, isHonorific).replaceAll('{activity}', activityLabel),
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  /// 이번엔 건너뛰기 선택 시 피드백 전송
  void _skipActivityRecommendation() {
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'u_${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.user,
          content: '이번에는 건너뛸래.',
          timestamp: DateTime.now(),
        ),
      );
      _isMascotTyping = true;
    });

    _scrollToBottom();

    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final isHonorific = ref.read(selectedStyleProvider) == 1;
      setState(() {
        _isMascotTyping = false;
        _messages.add(
          ChatMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}',
            sender: MessageSender.mascot,
            content: SpeechDictionary.get(SpeechKey.activitySkippedReply, isHonorific),
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _showFinishDialog() {
    final isHonorific = ref.read(selectedStyleProvider) == 1;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: SpeechDictionary.get(SpeechKey.finishConfirmTitle, isHonorific),
          onConfirm: _finishConversation,
        );
      },
    );
  }

  void _finishConversation() {
    // 대화 내역 중 업로드된 이미지 경로들 추출하여 최대 5개 전달
    final imagePaths = _messages
        .map((m) => m.imagePath)
        .whereType<String>()
        .take(5)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryLoadingScreen(
          imagePaths: imagePaths,
          selectedActivity: _selectedActivity,
          recommendedActions: _recommendedActions,
          chatMessages: _messages,
        ),
      ),
    );
  }

  void _submitDirectWrite() {
    final state = ref.read(directWriteProvider);
    final title = state.title.trim();
    final content = state.content.trim();
    final isHonorific = ref.read(selectedStyleProvider) == 1;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: SpeechDictionary.get(SpeechKey.completeDiaryConfirmTitle, isHonorific),
          onConfirm: () {
            Navigator.pop(context); // Close the dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DiaryLoadingScreen(
                  isDirectWrite: true,
                  directWriteTitle: title,
                  directWriteContent: content,
                  directWriteMood: state.mood,
                  imagePaths: state.imagePaths,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onFinishPressed() {
    if (_toggleIndex == 0) {
      _showFinishDialog();
    } else {
      _submitDirectWrite();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDirectWriteValid = ref.watch(directWriteProvider.select((s) => s.isValid));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        // 뒤로가기 버튼
        leading: IconButton(
          icon: SvgPicture.asset(
            AppIcons.arrowBack,
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        // 오늘 날짜를 MM.dd 형태로 표시
        title: Text(
          DateTime.now().toMMDD(),
          style: AppTextStyle.body2B,
        ),
        centerTitle: true,
        // 우측 끝내기 버튼 (체크 서클 SVG 아이콘)
        actions: [
          SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: IconButton(
                icon: SvgPicture.asset(
                  AppIcons.checkCircle,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    (_toggleIndex == 0 || isDirectWriteValid)
                        ? AppColors.mainColor
                        : AppColors.gray3,
                    BlendMode.srcIn,
                  ),
                ),
                onPressed: (_toggleIndex == 0 || isDirectWriteValid)
                    ? _onFinishPressed
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // "대화" / "쓰기" 모드 토글 (MiniSegmentedSlider 재사용)
            Center(
              child: MiniSegmentedSlider(
                selectedIndex: _toggleIndex,
                onChanged: (index) {
                  setState(() {
                    _toggleIndex = index;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            if (_toggleIndex == 0) ...[
              // 대화 목록 영역
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _messages.length + (_isMascotTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    // mascot 타이핑 중인 인디케이터 처리
                    if (index == _messages.length && _isMascotTyping) {
                      return const TypingIndicator();
                    }

                    final msg = _messages[index];
                    final isMascot = msg.sender == MessageSender.mascot;

                    if (isMascot) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SvgPicture.asset(
                              AppIcons.profile,
                              width: 40,
                              height: 40,
                            ),
                            const SizedBox(width: 8),
                            // 메시지 본문
                            if (msg.type == MessageType.activityRecommendation)
                              RecommendationBubble(
                                content: msg.content,
                                onRecommendationTap:
                                    _showActivityRecommendationModal,
                              )
                            else
                              ChatBubble(
                                text: msg.content,
                                isUser: false,
                                imagePath: msg.imagePath,
                              ),
                          ],
                        ),
                      );
                    } else {
                      // 사용자 메시지
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ChatBubble(
                            text: msg.content,
                            isUser: true,
                            imagePath: msg.imagePath,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

              // 이미지 프리뷰 대기 영역
              if (_selectedImagePath != null)
                ImagePreviewBar(
                  imagePath: _selectedImagePath!,
                  onCancel: () {
                    setState(() {
                      _selectedImagePath = null;
                      _onInputChange(); // 전송 상태 체크 업데이트
                    });
                  },
                ),

              // 하단 입력 표시줄
              ChatInputBar(
                controller: _inputController,
                isInputActive: _isInputActive,
                onSend: _sendMessage,
                onImagePickerPressed: _showImagePickerSourceSheet,
              ),
            ] else ...[
              // 직접 작성 영역
              Expanded(
                child: DirectWriteView(
                  isHonorific: ref.watch(selectedStyleProvider) == 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
