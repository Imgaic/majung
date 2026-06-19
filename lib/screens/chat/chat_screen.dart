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
import '../../providers/chat_provider.dart';
import '../../providers/direct_write_provider.dart';
import '../../utils/datetime_extension.dart';
import '../../providers/user_provider.dart';
import '../../utils/speech_dictionary.dart';

/// 마중이 앱의 핵심 기능인 AI 대화 화면.
/// UI 렌더링에만 집중하도록 설계되었으며, 비즈니스 상태 및 실시간 AI 통신 로직은 chatProvider로 격리되어 있습니다.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  int _toggleIndex = 0; // 0: 대화, 1: 쓰기

  bool get _isInputActive {
    final text = _inputController.text.trim();
    final chatState = ref.read(chatProvider);
    return text.isNotEmpty || chatState.selectedImagePath != null;
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChange);

    // 직접 작성 초기 상태 보장 및 채팅 첫인사 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(directWriteProvider.notifier).clear();
        final isHonorific = ref.read(selectedStyleProvider) == 1;
        ref.read(chatProvider.notifier).initChat(isHonorific);
      }
    });
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChange);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputChange() {
    // 텍스트 입력 상태 감지 및 버튼 활성화를 위한 리빌드 유도
    setState(() {});
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
        ref.read(chatProvider.notifier).updateSelectedImagePath(pickedFile.path);
        setState(() {}); // 전송 상태 활성화 업데이트 반영
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

  /// 사용자 메시지 전송 처리
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    final chatState = ref.read(chatProvider);
    final imagePath = chatState.selectedImagePath;

    if (text.isEmpty && imagePath == null) return;

    _inputController.clear();

    final isHonorific = ref.read(selectedStyleProvider) == 1;
    final userName = ref.read(userNameProvider);

    await ref.read(chatProvider.notifier).sendMessage(
          text,
          userName: userName,
          isHonorific: isHonorific,
        );

    _scrollToBottom();
  }

  /// 활동 추천 받기 탭 시 피그마의 `활동 추천 모달` 호출
  void _showActivityRecommendationModal() {
    final chatState = ref.read(chatProvider);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ActivityRecommendationDialog(
          activities: chatState.recommendedActions,
          onActivitySelected: _selectActivity,
          onSkip: _skipActivityRecommendation,
        );
      },
    );
  }

  /// 추천 활동을 선택했을 때 피드백 전송
  void _selectActivity(String activityLabel) {
    final isHonorific = ref.read(selectedStyleProvider) == 1;
    ref.read(chatProvider.notifier).selectActivity(activityLabel, isHonorific);
    _scrollToBottom();
  }

  /// 이번엔 건너뛰기 선택 시 피드백 전송
  void _skipActivityRecommendation() {
    final isHonorific = ref.read(selectedStyleProvider) == 1;
    ref.read(chatProvider.notifier).skipActivity(isHonorific);
    _scrollToBottom();
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
    final chatState = ref.read(chatProvider);
    final imagePaths = chatState.messages
        .map((m) => m.imagePath)
        .whereType<String>()
        .take(5)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryLoadingScreen(
          imagePaths: imagePaths,
          selectedActivity: chatState.selectedActivity,
          recommendedActions: chatState.recommendedActions,
          chatMessages: chatState.messages,
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
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isMascotTyping = chatState.isMascotTyping;
    final selectedImagePath = chatState.selectedImagePath;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: SvgPicture.asset(
            AppIcons.arrowBack,
            width: 24,
            height: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          DateTime.now().toMMDD(),
          style: AppTextStyle.body2B,
        ),
        centerTitle: true,
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
                onPressed: (_toggleIndex == 0 || isDirectWriteValid) ? _onFinishPressed : null,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
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
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: messages.length + (isMascotTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && isMascotTyping) {
                      return const TypingIndicator();
                    }

                    final msg = messages[index];
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
                            if (msg.type == MessageType.activityRecommendation)
                              RecommendationBubble(
                                content: msg.content,
                                onRecommendationTap: _showActivityRecommendationModal,
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
              if (selectedImagePath != null)
                ImagePreviewBar(
                  imagePath: selectedImagePath,
                  onCancel: () {
                    ref.read(chatProvider.notifier).updateSelectedImagePath(null);
                    setState(() {});
                  },
                ),
              ChatInputBar(
                controller: _inputController,
                isInputActive: _isInputActive,
                onSend: _sendMessage,
                onImagePickerPressed: _showImagePickerSourceSheet,
              ),
            ] else ...[
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
