import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_app_bar.dart';
import '../../providers/user_provider.dart';
import '../../providers/diary_provider.dart';
import '../error_screen.dart';
import 'widgets/chat_inner_button.dart';
import 'diary_edit_screen.dart';
import '../../utils/datetime_extension.dart';
import '../../utils/speech_dictionary.dart';
import '../../main.dart'; // selectedStyleProvider
import 'diary_loading_screen.dart';
import 'widgets/activity_recommendation_dialog.dart';

/// 일기 작성이 완료된 후의 렌더링 화면 (순수 뷰어 역할).
/// 피그마 시안 node 175:862 ("AI 대화(작성 완료)")에 해당하며, 편집은 DiaryEditScreen에서 전담합니다.
class DiaryCompletedScreen extends ConsumerStatefulWidget {
  final bool fromCalendar;

  const DiaryCompletedScreen({
    super.key,
    this.fromCalendar = false,
  });

  @override
  ConsumerState<DiaryCompletedScreen> createState() => _DiaryCompletedScreenState();
}

class _DiaryCompletedScreenState extends ConsumerState<DiaryCompletedScreen> {

  /// 사용자가 업로드한 이미지가 있으면 렌더링
  List<Widget> _buildImageItems(List<String> imagePaths) {
    final List<Widget> items = [];
    for (int i = 0; i < imagePaths.length; i++) {
      if (i > 0) items.add(const SizedBox(width: 12));
      items.add(
        _buildImageCard(
          child: Image.file(
            File(imagePaths[i]),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildImageCard({required Widget child}) {
    return Container(
      width: 101,
      height: 101,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray2, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  /// 일기 삭제 컨펌 다이얼로그 호출
  void _showDeleteConfirmDialog() {
    final isHonorific = ref.read(selectedStyleProvider) == 1;
    final parentNavigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ConfirmDialog(
          title: SpeechDictionary.get(SpeechKey.deleteConfirmTitle, isHonorific),
          onConfirm: () {
            ref.read(diaryProvider.notifier).deleteDiary();
            // 1. 다이얼로그 닫기
            Navigator.pop(dialogContext);
            // 2. 진입 경로에 따라 적절히 이전 화면 또는 홈 화면으로 이동
            if (widget.fromCalendar) {
              parentNavigator.pop();
            } else {
              parentNavigator.popUntil(ModalRoute.withName('/home'));
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diary = ref.watch(diaryProvider);
    final userName = ref.watch(userNameProvider);
    final isHonorific = ref.watch(selectedStyleProvider) == 1;

    // 일기 데이터가 없는 경우 (삭제되었거나 미생성) 안전하게 전역 에러 화면 표출
    if (diary == null) {
      return ErrorScreen(
        title: '문제가 발생했어요!',
        message: '일기 데이터를 찾을 수 없거나 삭제되었습니다.',
        primaryButtonLabel: '홈으로 돌아가기',
        onPrimaryPressed: () {
          Navigator.popUntil(context, ModalRoute.withName('/home'));
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: CustomAppBar(
        title: diary.date.toMMDD(),
        titleStyle: AppTextStyle.body2B,
        onBackPressed: () {
          // 일기 완수 후 뒤로가기 탭 시 진입 경로에 따라 복귀 처리
          if (widget.fromCalendar) {
            Navigator.pop(context);
          } else {
            Navigator.popUntil(context, ModalRoute.withName('/home'));
          }
        },
        actions: [
          // 일반 뷰 모드: 수정(펜) 및 삭제(휴지통) 버튼
          IconButton(
            icon: SvgPicture.asset(
              AppIcons.pen,
              width: 24,
              height: 24,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryEditScreen(initialDiary: diary),
                ),
              );
            },
          ),
          IconButton(
            icon: SvgPicture.asset(
              AppIcons.trash,
              width: 24,
              height: 24,
            ),
            onPressed: _showDeleteConfirmDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // 1. 감정 클라우드 배지 (Pretendard 72x72)
              Center(
                child: SvgPicture.asset(
                  AppIcons.getMoodIcon(diary.mood),
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 16),

              // 2. 일기 제목 렌더링
              Center(
                child: Text(
                   diary.title,
                  style: AppTextStyle.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.grayScale9,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. 일기 앨범 이미지 리스트 (101x101) - 사진이 있을 때만 렌더링
              if (diary.imagePaths.isNotEmpty) ...[
                SizedBox(
                  height: 101,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _buildImageItems(diary.imagePaths),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 4. 일기 본문 렌더링
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  diary.content,
                  style: AppTextStyle.body2R.copyWith(
                    color: AppColors.grayScale9,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 5. 마중이의 건네는 말 카드
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$userName에게 건네는 말',
                  style: AppTextStyle.body2B.copyWith(
                    color: AppColors.grayScale9,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.subColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (diary.mascotFeedback.isNotEmpty)
                      Text(
                        diary.mascotFeedback,
                        style: AppTextStyle.body2R.copyWith(
                          color: AppColors.grayScale9,
                          height: 1.6,
                        ),
                      )
                    else
                      ChatInnerButton(
                        label: '답장 받기',
                        width: double.infinity,
                        height: 48,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DiaryLoadingScreen(
                                isDirectWrite: true,
                                isReplyOnly: true,
                                imagePaths: diary.imagePaths,
                              ),
                            ),
                          );
                        },
                      ),
                    if (!diary.isDirectWrite || diary.mascotFeedback.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        SpeechDictionary.get(SpeechKey.behaviorRecommendationTitle, isHonorific),
                        style: AppTextStyle.body2R.copyWith(
                          color: AppColors.grayScale9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (diary.recommendedAction.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              diary.recommendedAction,
                              textAlign: TextAlign.center,
                              style: AppTextStyle.body2B.copyWith(
                                color: AppColors.mainColor,
                              ),
                            ),
                          ),
                        )
                      else
                        ChatInnerButton(
                          label: '활동 추천 받기',
                          width: double.infinity,
                          height: 48,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return ActivityRecommendationDialog(
                                  activities: diary.recommendedActions.isNotEmpty
                                      ? diary.recommendedActions
                                      : const [
                                          '좋아하는 노래 들으며 산책하기',
                                          '따뜻한 물로 샤워하기',
                                          '따뜻한 차 한 잔 마시기',
                                        ],
                                  onActivitySelected: (activityLabel) {
                                    ref.read(diaryProvider.notifier).updateDiary(
                                          recommendedAction: activityLabel,
                                        );
                                  },
                                  onSkip: () {
                                    // 건너뛰기 선택 시 아무런 행동도 임의 지정하지 않고 빈 상태를 유지하여 추후 상세 화면에서 재추천/선택할 수 있게 함
                                  },
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
