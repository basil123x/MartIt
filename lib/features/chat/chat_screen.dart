import 'dart:async';
import 'package:MartIt/core/services/onesignal_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/chat_model.dart';
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
  bool _isOnline = false;
  Timer? _statusUpdateTimer;
  Timer? _statusCheckTimer;
  Timer? _messagePollingTimer; // ✅ Timer للـ polling

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _statusUpdateTimer?.cancel();
    _statusCheckTimer?.cancel();
    _messagePollingTimer?.cancel(); // ✅ إلغاء الـ polling timer
    super.dispose();
  }

  // ✅ عند العودة للتطبيق - تحديث فوري
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUserStatus(); // تحديث فوري
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

    // ✅ تحقق من حالة الطرف الآخر كل 3 ثواني (سريع وفوري)
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      await _checkUserStatus();
    });
  }

  Future<void> _initializeChat() async {
    _currentUserId = await AuthService.getCurrentUserId();
    _currentUserName = await AuthService.getCurrentName();
    _currentUserAvatar = await AuthService.getCurrentProfileImage();
    _currentConversationId = widget.conversationId;
    
    // ✅ إذا لم يكن هناك صورة محفوظة، نستخدم رابط CDN
    if ((_currentUserAvatar == null || _currentUserAvatar!.isEmpty) && _currentUserId != null) {
      _currentUserAvatar = 'https://globee.b-cdn.net/users/$_currentUserId/avatar.jpg';
    }
    
    if (_currentUserId != null) {
      // Update own status immediately
      await ApiService.updateOnlineStatus(userId: _currentUserId!);
      await _loadMessages();
      await _checkUserStatus();
      
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

  Future<void> _checkUserStatus() async {
    try {
      final result = await ApiService.getUserStatus(userId: widget.receiverId);
      if (result['success'] == true && mounted) {
        final minutesAgo = result['minutes_ago'] ?? 999;
        setState(() {
          // ✅ متصل لو آخر ظهور أقل من دقيقة
          _isOnline = minutesAgo < 1;
        });
      }
    } catch (e) {
      print('Error checking user status: $e');
    }
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
        final newMessages = data.map((item) => ChatMessage.fromJson(item)).toList();
        
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
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendMessage({
    String? locationMessage,
    double? lat,
    double? lng,
  }) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'فشل في إرسال الرسالة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء إرسال الرسالة'),
          backgroundColor: Colors.red,
        ),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: const Icon(Iconsax.arrow_right, color: Color(0xFF1A1A2E)),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                backgroundImage:
                    widget.receiverAvatar != null &&
                        widget.receiverAvatar!.isNotEmpty
                    ? NetworkImage(widget.receiverAvatar!)
                    : null,
                child:
                    widget.receiverAvatar == null ||
                        widget.receiverAvatar!.isEmpty
                    ? Text(
                        widget.receiverName != null &&
                                widget.receiverName!.isNotEmpty
                            ? widget.receiverName![0]
                            : 'S',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.receiverName ?? 'مستخدم',
                      style: const TextStyle(
                        // color: Colors.white,
                        color: Color(0xFF1A1A2E),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                // TODO: Voice call functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ميزة المكالمات الصوتية ستكون متاحة قريباً'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              // icon: const Icon(Iconsax.call, color: Colors.white),
              icon: const Icon(Iconsax.call, color: Color(0xFF1A1A2E)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Messages List
            Expanded(
              // ✅ نظهر loading فقط في التحميل الأول
              child: _isLoading && _isFirstLoad
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
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

            // Message Input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Iconsax.message,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ابدأ محادثة جديدة',
            style: TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أرسل رسالة لبدء المحادثة مع ${widget.receiverName ?? "المستخدم"}',
            style: TextStyle(
              // color: Colors.white.withOpacity(0.7),
              color: const Color(0xFF1A1A2E).withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMyMessage = message.senderId == _currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMyMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              backgroundImage:
                  widget.receiverAvatar != null &&
                      widget.receiverAvatar!.isNotEmpty
                  ? NetworkImage(widget.receiverAvatar!)
                  : null,
              child:
                  widget.receiverAvatar == null ||
                      widget.receiverAvatar!.isEmpty
                  ? Text(
                      widget.receiverName != null &&
                              widget.receiverName!.isNotEmpty
                          ? widget.receiverName![0]
                          : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // gradient: isMyMessage
                //     ? LinearGradient(
                //         colors: [
                //           AppColors.primary,
                //           AppColors.primary.withOpacity(0.8),
                //         ],
                //       )
                //     : LinearGradient(
                //         colors: [
                //           Colors.white.withOpacity(0.1),
                //           Colors.white.withOpacity(0.05),
                //         ],
                //       ),
                // borderRadius: BorderRadius.only(
                //   topLeft: const Radius.circular(16),
                //   topRight: const Radius.circular(16),
                //   bottomLeft: isMyMessage
                //       ? const Radius.circular(16)
                //       : const Radius.circular(4),
                //   bottomRight: isMyMessage
                //       ? const Radius.circular(4)
                //       : const Radius.circular(16),
                color:
                    isMyMessage // ✅ فاتح
                    ? AppColors.primary
                    : const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMyMessage
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMyMessage
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                border: !isMyMessage
                    ? Border.all(color: Colors.white.withOpacity(0.1))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Check if it's a location message
                  if (message.messageType == 'location')
                    GestureDetector(
                      onTap: () async {
                        if (message.locationLat != null &&
                            message.locationLng != null) {
                          _launchUrl(message.locationLat, message.locationLng);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          // color: Colors.white.withOpacity(0.1),
                          color: isMyMessage
                              ? Colors.white.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.location,
                              // color: Colors.white,
                              color: isMyMessage
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'عرض الموقع',
                              style: TextStyle(
                                // color: Colors.white,
                                color: isMyMessage
                                    ? Colors.white
                                    : AppColors.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      message.message,
                      style: TextStyle(
                        // color: Colors.white,
                        color: isMyMessage
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          // color: Colors.white.withOpacity(0.7),
                          color: isMyMessage
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF1A1A2E).withOpacity(0.6),
                          fontSize: 12,
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
                              ? Colors.blue.shade300
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMyMessage) ...[
            const SizedBox(width: 8),
            // ✅ صورة المرسل (أنا) مع معالجة الأخطاء
            _buildSenderAvatar(),
          ],
        ],
      ),
    );
  }

  // ✅ Widget لصورة المرسل (أنا) مع معالجة الأخطاء
  Widget _buildSenderAvatar() {
    final avatarUrl = _currentUserAvatar;
    final hasValidUrl = avatarUrl != null && avatarUrl.isNotEmpty;
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary,
      child: hasValidUrl
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // ✅ إذا فشل تحميل الصورة، نظهر الحرف الأول
                  return Text(
                    _currentUserName != null && _currentUserName!.isNotEmpty
                        ? _currentUserName![0]
                        : 'أ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            )
          : Text(
              _currentUserName != null && _currentUserName!.isNotEmpty
                  ? _currentUserName![0]
                  : 'أ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يجب السماح بالوصول إلى الموقع')),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل في الحصول على الموقع')));
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // const Color(0xFF1A1A2E).withOpacity(0.9),
            // const Color(0xFF0F3460),
            Color(0xFFD4D4F0),
            Color(0xFFC8D4F5),
            Color(0xFFB4D4F0),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Location button
            GestureDetector(
              onTap: _sendLocation,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  // color: Colors.white.withOpacity(0.1),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.5),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(
                  Iconsax.location,
                  // color: Colors.white,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _messageController,
                  // style: const TextStyle(color: Colors.white),
                  style: const TextStyle(color: Color(0xFF1A1A2E)),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة...',
                    hintStyle: TextStyle(
                      // color: Colors.white.withOpacity(0.5)
                      color: const Color(0xFF1A1A2E).withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Transform.flip(
                        flipX: true,
                        child: const Icon(
                          Iconsax.send_1,
                          color: Colors.white,
                          size: 24,
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
