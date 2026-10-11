import 'dart:async';
import 'package:MartIt/core/services/onesignal_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/widgets/moderation_actions.dart';
import '../../core/models/chat_model.dart';
import '../../core/widgets/smart_avatar_widget.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';
import '../profile/profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String? receiverName;
  final String? receiverAvatar;
  final String? receiverToken;
  final String? conversationId;
  final bool isOnline;

  const ChatScreen({
    super.key,
    required this.receiverId,
    this.receiverName,
    this.receiverAvatar,
    this.receiverToken,
    this.conversationId,
    this.isOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isFirstLoad = true; // ✅ للتفريق بين التحميل الأول والـ polling
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserAvatar;
  String? _currentConversationId;
  Timer? _statusUpdateTimer;
  Timer? _messagePollingTimer; // ✅ Timer للـ polling
  bool _isBlocked = false;

  bool _receiverIsBlocked() {
    return BlockedSellers.instance.containsSeller(
      widget.receiverId,
      widget.receiverId,
      widget.receiverName ?? '',
    );
  }

  void _onBlocksChanged() {
    final blocked = _receiverIsBlocked();
    if (mounted && blocked != _isBlocked) {
      setState(() => _isBlocked = blocked);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BlockedSellers.instance.addListener(_onBlocksChanged);
    _initializeChat();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    BlockedSellers.instance.removeListener(_onBlocksChanged);
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _statusUpdateTimer?.cancel();
    _messagePollingTimer?.cancel(); // ✅ إلغاء الـ polling timer
    super.dispose();
  }

  // ✅ عند العودة للتطبيق - تحديث فوري
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMessages(isPolling: true);
    }
  }

  void _startStatusUpdates() {
    // ✅ تحديث حالتك كل 30 ثانية (كفاية)
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_currentUserId != null) {
        await ApiService.updateOnlineStatus(userId: _currentUserId!);
      }
    });

  }

  Future<void> _initializeChat() async {
    _currentUserId = await AuthService.getCurrentUserId();
    _currentUserName = await AuthService.getCurrentName();
    _currentUserAvatar = await AuthService.getCurrentProfileImage();
    _currentConversationId = widget.conversationId;

    if (_currentUserId != null) {
      await BlockedSellers.instance.sync();
      _isBlocked = _receiverIsBlocked();
      if (_isBlocked) {
        if (mounted) setState(() {});
        return;
      }
      // Update own status immediately
      await ApiService.updateOnlineStatus(userId: _currentUserId!);
      await _loadMessages();

      // ✅ بدء polling للرسائل كل 3 ثواني
      _startMessagePolling();
    }
  }

  // ✅ Polling للرسائل الجديدة
  void _startMessagePolling() {
    _messagePollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(isPolling: true);
    });
  }

  Future<void> _loadMessages({bool isPolling = false}) async {
    // ✅ لا نظهر loading spinner أثناء الـ polling
    if (!isPolling) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final result = await ApiService.getChatMessages(
        senderId: _currentUserId!,
        receiverId: widget.receiverId,
      );

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        final newMessages = data
            .map((item) => ChatMessage.fromJson(item))
            .toList();

        // ✅ تحقق إذا وصلت رسائل جديدة
        final hadNewMessages = newMessages.length > _messages.length;

        setState(() {
          _messages = newMessages;
          _isLoading = false;
          _isFirstLoad = false;
        });

        // ✅ scroll للأسفل فقط إذا وصلت رسائل جديدة أو كان التحميل الأول
        if (hadNewMessages || !isPolling) {
          _scrollToBottom();
        }
      } else {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (!isPolling) {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  Future<void> _launchUrl(latitude, longitude) async {
    final lat = (latitude as num).toDouble();
    final lng = (longitude as num).toDouble();
    final Uri url = Uri.parse(
      AppConstants.googleMapsSearchUrl(lat: lat, lng: lng),
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendMessage({
    String? locationMessage,
    double? lat,
    double? lng,
  }) async {
    if (_isBlocked || _receiverIsBlocked()) {
      showAppSnackbar(context, message: tr('moderation.blocked_chat'));
      return;
    }
    final messageText = locationMessage ?? _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    if (locationMessage == null) {
      _messageController.clear();
    }

    setState(() {
      _isSending = true;
    });

    try {
      final result = await ApiService.sendChatMessage(
        senderId: _currentUserId!,
        receiverId: widget.receiverId,
        message: messageText,
        conversationId: _currentConversationId,
        messageType: locationMessage != null ? 'location' : 'text',
        locationLat: lat,
        locationLng: lng,
      );

      if (result['success'] == true) {
        // Update conversation ID if it's a new conversation
        if (_currentConversationId == null &&
            result['conversation_id'] != null) {
          setState(() {
            _currentConversationId = result['conversation_id'].toString();
          });
        }

        // Add message to local list immediately
        final newMessage = ChatMessage(
          id:
              result['message_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: _currentUserId!,
          receiverId: widget.receiverId,
          message: messageText,
          timestamp: DateTime.now(),
          isRead: false,
          conversationId: _currentConversationId,
          messageType: locationMessage != null ? 'location' : 'text',
          locationLat: lat,
          locationLng: lng,
        );
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();

        String? name = await AuthService.getCurrentName() ?? 'مستخدم';

        if (widget.receiverToken != null) {
          await OneSignalService.sendNotificationToUser(
            playerId: widget.receiverToken!,
            title: name,
            message: messageText,
            data: {
              "receiverId": _currentUserId ?? '',
              "receiverName": _currentUserName ?? '',
              "receiverAvatar": _currentUserAvatar ?? '',
              "receiverToken": '',
              "conversationId": _currentConversationId ?? '',
              "isOnline": false,
            },
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في إرسال الرسالة',
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء إرسال الرسالة',
        type: SnackType.error,
      );
    } finally {
      setState(() {
        _isSending = false;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
          ),
          title: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: widget.receiverId),
              ),
            ),
            child: Row(
              children: [
                _buildReceiverAvatar(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.receiverName ?? 'مستخدم',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: tr('moderation.report'),
              onPressed: _reportConversation,
              icon: Icon(Iconsax.flag, color: cs.primary),
            ),
            IconButton(
              tooltip: tr('moderation.block'),
              onPressed: _blockReceiver,
              icon: Icon(Iconsax.user_remove, color: cs.primary),
            ),
          ],
        ),
        body: _isBlocked
            ? _buildBlockedState()
            : Column(
          children: [
            _buildSafetyBar(),
            Expanded(
              child: _isLoading && _isFirstLoad
                  ? Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Future<void> _reportConversation() {
    return reportContent(
      context,
      targetType: 'message',
      commentId: widget.conversationId ?? '',
      targetUid: widget.receiverId,
      title: tr('moderation.report_user'),
    );
  }

  Future<void> _reportMessage(ChatMessage message) {
    return reportContent(
      context,
      targetType: 'message',
      commentId: message.id,
      targetUid: message.senderId,
      title: tr('moderation.report_message'),
    );
  }

  Future<void> _blockReceiver() async {
    final blocked = await blockAbusiveUser(
      context,
      blockedUid: widget.receiverId,
      name: widget.receiverName ?? '',
    );
    if (blocked && mounted) {
      setState(() => _isBlocked = true);
    }
  }

  Future<void> _unblockReceiver() async {
    final uid = await AuthService.getCurrentUserId();
    if (uid == null) return;
    await ModerationService.unblockUser(
      blockerUid: uid,
      blockedUid: widget.receiverId,
    );
    BlockedSellers.instance.unblock(
      widget.receiverId,
      name: widget.receiverName ?? '',
    );
    if (!mounted) return;
    setState(() => _isBlocked = false);
    showAppSnackbar(context, message: tr('moderation.unblocked'));
    await _loadMessages();
    if (_messagePollingTimer == null) _startMessagePolling();
  }

  Widget _buildSafetyBar() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.65),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: _reportConversation,
              icon: Icon(Iconsax.flag, size: 18, color: cs.primary),
              label: Text(tr('moderation.report')),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: _blockReceiver,
              icon: Icon(Iconsax.user_remove, size: 18, color: cs.primary),
              label: Text(tr('moderation.block')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.user_remove, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              tr('moderation.blocked_chat'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _unblockReceiver,
              child: Text(tr('moderation.unblock')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.message,
              size: 40,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ابدأ محادثة جديدة',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أرسل رسالة لبدء المحادثة مع ${widget.receiverName ?? "المستخدم"}',
            style: TextStyle(
              color: context.martItColors.mutedText,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverAvatar({required double size}) {
    final cs = Theme.of(context).colorScheme;
    return SmartAvatarWidget(
      userId: widget.receiverId,
      name: widget.receiverName ?? "",
      size: size,
      fallbackUrl: widget.receiverAvatar,
      backgroundColor: cs.primary,
      initialsStyle: TextStyle(
        color: cs.onPrimary,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.4,
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMyMessage = message.senderId == _currentUserId;
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    // Force LTR row geometry so "end" = physical right, "start" = left,
    // independent of the screen's RTL Directionality.
    final align =
        isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start;

    return GestureDetector(
      onLongPress: isMyMessage ? null : () => _reportMessage(message),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: align,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: widget.receiverId),
                ),
              ),
              child: _buildReceiverAvatar(size: 32),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: message.messageType == 'location'
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMyMessage ? cs.primary : martIt.receivedBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMyMessage ? 16 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.messageType == 'location' &&
                      message.locationLat != null &&
                      message.locationLng != null)
                    _buildLocationMapBubble(
                      lat: message.locationLat!,
                      lng: message.locationLng!,
                    )
                  else
                    Text(
                      message.message,
                      style: TextStyle(
                        color: isMyMessage ? cs.onPrimary : cs.onSurface,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: message.messageType == 'location'
                        ? const EdgeInsets.symmetric(horizontal: 4)
                        : EdgeInsets.zero,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isMyMessage
                                ? cs.onPrimary.withValues(alpha: 0.75)
                                : martIt.mutedText,
                            fontSize: 11,
                          ),
                        ),
                        if (isMyMessage) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead
                                ? Iconsax.tick_circle
                                : Iconsax.tick_square,
                            size: 14,
                            color: message.isRead
                                ? const Color(0xFFB8F0FF)
                                : cs.onPrimary.withValues(alpha: 0.75),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_currentUserId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: _currentUserId!),
                    ),
                  );
                }
              },
              child: _buildSenderAvatar(),
            ),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildLocationMapBubble({
    required double lat,
    required double lng,
  }) {
    final mapUrl = AppConstants.osmStaticMapUrl(
      lat: lat,
      lng: lng,
      width: 300,
      height: 180,
      zoom: 16,
    );

    return GestureDetector(
      onTap: () => _launchUrl(lat, lng),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 260,
          height: 160,
          child: Image.network(
            mapUrl,
            width: 260,
            height: 160,
            fit: BoxFit.cover,
            headers: const {
              'User-Agent': 'MartIt/1.0 (Flutter; chat location preview)',
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final shimmerBase = context.appSurfaceVariant;
              return Shimmer.fromColors(
                baseColor: shimmerBase,
                highlightColor: context.appSurface,
                child: Container(
                  width: 260,
                  height: 160,
                  color: shimmerBase,
                ),
              );
            },
            errorBuilder: (_, __, ___) {
              // Fallback: OSM tile + local pin if staticmap host fails.
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    AppConstants.osmTileUrl(lat: lat, lng: lng, zoom: 16),
                    fit: BoxFit.cover,
                    headers: const {
                      'User-Agent':
                          'MartIt/1.0 (Flutter; chat location preview)',
                    },
                    errorBuilder: (_, __, ___) => _buildLocationMapFallback(),
                  ),
                  const Center(
                    child: Icon(
                      Iconsax.location5,
                      color: Color(0xFFE53935),
                      size: 36,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLocationMapFallback() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 260,
      height: 160,
      color: context.appIconPillBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.map_1, color: cs.primary, size: 40),
          const SizedBox(height: 8),
          Text(
            'معاينة الخريطة غير متاحة',
            style: TextStyle(
              color: cs.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderAvatar() {
    final cs = Theme.of(context).colorScheme;
    if (_currentUserId == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: cs.primary,
        child: Text(
          _currentUserName != null && _currentUserName!.isNotEmpty
              ? _currentUserName![0]
              : 'أ',
          style: TextStyle(
            color: cs.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return SmartAvatarWidget(
      userId: _currentUserId!,
      name: _currentUserName ?? "",
      size: 32,
      loadSocialFromStorage: true,
      backgroundColor: cs.primary,
      initialsStyle: TextStyle(
        color: cs.onPrimary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _sendLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showAppSnackbar(
            context,
            message: 'يجب السماح بالوصول إلى الموقع',
            type: SnackType.warning,
          );
          return;
        }
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition();

      // Send location message
      await _sendMessage(
        locationMessage: 'موقعي الحالي',
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      print('Error getting location: $e');
      showAppSnackbar(
        context,
        message: 'فشل في الحصول على الموقع',
        type: SnackType.error,
      );
    }
  }

  Widget _buildMessageInput() {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(
          top: BorderSide(color: martIt.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _sendLocation,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.appIconPillBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.location,
                  color: cs.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: TextStyle(color: cs.onSurface, fontSize: 15),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(
                    color: martIt.mutedText,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: martIt.fieldBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: martIt.fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: martIt.fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: cs.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: cs.onPrimary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Transform.flip(
                        // RTL: send arrow should point left (message flow).
                        flipX: true,
                        child: Icon(
                          Iconsax.send_1,
                          color: cs.onPrimary,
                          size: 22,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else if (difference.inHours > 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
