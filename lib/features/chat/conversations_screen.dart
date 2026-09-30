import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/chat_model.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../../core/utils/theme_extensions.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final String userId;

  /// When true, hosted inside [MainNavigationScreen] — hide the back button.
  final bool embeddedInShell;

  const ConversationsScreen({
    super.key,
    required this.userId,
    this.embeddedInShell = false,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<ChatConversation> _conversations = [];
  final Map<String, bool> _onlineStatuses = {};
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _startStatusChecks();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusChecks() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkAllStatuses();
    });
  }

  Future<void> _checkAllStatuses() async {
    for (var conversation in _conversations) {
      try {
        final result = await ApiService.getUserStatus(
          userId: conversation.participantId,
        );
        if (result['success'] == true && mounted) {
          setState(() {
            _onlineStatuses[conversation.participantId] =
                result['is_online'] == true || result['is_online'] == 1;
          });
        }
      } catch (e) {
        print('Error checking status for ${conversation.participantId}: $e');
      }
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      print('🔍 Loading conversations for user: ${widget.userId}');
      final result = await ApiService.getChatConversations(
        userId: widget.userId,
      );
      print('📦 Conversations API response: $result');

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        print('✅ Found ${data.length} unique conversations');

        setState(() {
          _conversations =
              data.map((item) => ChatConversation.fromJson(item)).toList();
          _isLoading = false;
        });
        _checkAllStatuses();
      } else {
        print('❌ API returned success=false: ${result['error']}');
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading conversations: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embeddedInShell,
          leading: widget.embeddedInShell
              ? null
              : IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: cs.onSurface),
                ),
          title: Text(
            'المحادثات',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _loadConversations,
              icon: Icon(Iconsax.refresh, color: cs.primary),
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: cs.primary),
              )
            : _hasError
                ? _buildErrorWidget()
                : _conversations.isEmpty
                    ? _buildEmptyWidget()
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        color: cs.primary,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            0,
                            4,
                            0,
                            widget.embeddedInShell ? 100 : 16,
                          ),
                          itemCount: _conversations.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: martIt.divider,
                          ),
                          itemBuilder: (context, index) {
                            return _buildConversationTile(
                              _conversations[index],
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, size: 80, color: cs.error),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل المحادثات',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConversations,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.message,
              size: 56,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد محادثات',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ابدأ محادثة جديدة مع البائعين',
            style: TextStyle(
              color: context.martItColors.mutedText,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'تصفح المنتجات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation conversation) {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    final isOnline = _onlineStatuses[conversation.participantId] == true;
    final preview =
        conversation.lastMessage?.message ?? 'ابدأ محادثة جديدة';
    final dateLabel = conversation.lastMessage != null
        ? _formatTime(conversation.lastMessage!.timestamp)
        : '';

    return ColoredBox(
      color: context.appSurface,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                receiverId: conversation.participantId,
                receiverName: conversation.participantName,
                receiverAvatar: conversation.participantAvatar,
                receiverToken: conversation.participantToken,
                conversationId: conversation.conversationId,
                isOnline: isOnline,
              ),
            ),
          ).then((_) => _loadConversations());
        },
        splashColor: cs.primary.withValues(alpha: 0.06),
        highlightColor: cs.primary.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  SmartAvatarWidget(
                    userId: conversation.participantId,
                    name: conversation.participantName,
                    size: 52,
                    fallbackUrl: conversation.participantAvatar,
                    backgroundColor: cs.primary,
                    initialsStyle: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.appSurface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.participantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.primary.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: martIt.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  if (conversation.unreadCount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'أمس';
      } else if (difference.inDays < 7) {
        return 'منذ ${difference.inDays} أيام';
      } else {
        return '${timestamp.day}/${timestamp.month}';
      }
    } else if (difference.inHours > 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
