import 'package:MartIt/core/services/onesignal_service.dart';
import 'package:MartIt/features/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/item_model.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/widgets/report_sheet.dart';

class CommentsModal extends StatefulWidget {
  final String itemId;
  final bool isLoggedIn;
  final ItemModel items;

  const CommentsModal({
    super.key,
    required this.itemId,
    required this.isLoggedIn,
    required this.items,
  });

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final viewerId = await AuthService.getCurrentUserId();
      final response = await ApiService.getComments(
        int.parse(widget.itemId),
        viewerId: viewerId,
      );

      if (response['success'] == true) {
        final List<dynamic> commentsData = response['data'] ?? [];
        setState(() {
          _comments = commentsData
              .map((comment) => CommentModel.fromJson(comment))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _comments = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _comments = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (await ModerationService.containsBannedWords(text)) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr('moderation.banned_word'),
        type: SnackType.error,
      );
      return;
    }

    if (!widget.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        showAppSnackbar(context, message: 'يجب تسجيل الدخول أولاً', type: SnackType.error);
        setState(() {
          _isSending = false;
        });
        return;
      }

      final response = await ApiService.addComment(
        itemId: int.parse(widget.itemId),
        userId: int.parse(currentUserId),
        comment: _commentController.text.trim(),
      );
      final user = await FlutterSecureStorage().read(key: 'user_name');

      OneSignalService.sendNotificationToUser(
        playerId: widget.items.seller.token,
        title: "تعليق جديد من $user",
        message: _commentController.text.trim(),
      );

      if (response['success'] == true) {
        _commentController.clear();
        _loadComments(); // Reload comments

        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      } else {
        showAppSnackbar(context, message: 'فشل في إرسال التعليق', type: SnackType.error);
      }
    } catch (e) {
      showAppSnackbar(context, message: 'حدث خطأ في إرسال التعليق', type: SnackType.error);
    }

    setState(() {
      _isSending = false;
    });
  }

  Future<void> _openCommentActions(CommentModel comment) async {
    final uid = await AuthService.getCurrentUserId();
    if (!mounted || uid == null) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(tr('moderation.report')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showReportSheet(
                    context: context,
                    title: tr('moderation.report'),
                    onSubmit: (reason, note) async {
                      final result = await ModerationService.report(
                        userId: uid,
                        reason: reason,
                        note: note,
                        targetType: 'comment',
                        itemId: widget.itemId,
                        commentId: comment.id,
                        targetUid: comment.userId,
                      );
                      if (!mounted) return;
                      final sent = result['success'] == true;
                      showAppSnackbar(
                        context,
                        message: sent
                            ? tr('moderation.report_sent')
                            : tr('common.error'),
                        type: sent ? SnackType.success : SnackType.error,
                      );
                    },
                  );
                },
              ),
              ListTile(
                title: Text(tr('moderation.block')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final result = await ModerationService.blockUser(
                    blockerUid: uid,
                    blockedUid: comment.userId,
                  );
                  if (!mounted) return;
                  if (result['success'] != true) {
                    showAppSnackbar(
                      context,
                      message: tr('common.error'),
                      type: SnackType.error,
                    );
                    return;
                  }
                  BlockedSellers.instance.block([comment.userId]);
                  setState(() {
                    _comments.removeWhere((item) => item.userId == comment.userId);
                  });
                  showAppSnackbar(context, message: tr('moderation.blocked'));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Container(
      height: keyboardHeight > 0
          ? screenHeight *
                0.9 // عند فتح الكيبورد
          : screenHeight * 0.8, // الحالة العادية
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _comments.isEmpty
                ? _buildEmptyState()
                : _buildCommentsList(),
          ),

          // Comment Input
          _buildCommentInput(),

          // Add padding for keyboard
          if (keyboardHeight > 0) SizedBox(height: keyboardHeight),
        ],
      ),
    ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appCardBorder)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Expanded(
            child: Text(
              'التعليقات',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.close_square, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.message, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد تعليقات بعد',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'كن أول من يعلق على هذا المنتج',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        return _buildCommentItem(_comments[index]);
      },
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmartAvatarWidget(
              userId: comment.userId,
              name: comment.userName,
              size: 40,
              fallbackUrl: comment.userAvatar,
              backgroundColor: AppColors.secondary,
              initialsStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                // RTL start = next to avatar (right side visually).
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(comment.createdAt),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.more_horiz, color: cs.onSurfaceVariant),
                        onPressed: () => _openCommentActions(comment),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceVariant,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Text(
                        comment.comment,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appSurfaceVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Send Button
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendComment,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Iconsax.send_1, color: Colors.white, size: 20),
              ),
            ),

            const SizedBox(width: 12),

            // Text Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.appSurfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _commentController,
                  textAlign: TextAlign.right,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'اكتب تعليقك...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
