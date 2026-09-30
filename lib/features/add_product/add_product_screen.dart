import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:MartIt/shared/providers/app_provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/country_code_util.dart';
import '../../core/widgets/video_player_widget.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/services/background_media_upload_service.dart';
import '../../core/services/s3_upload_service.dart';
import '../../core/utils/item_media_url_util.dart';
import '../camera/camera_screen.dart';
import '../../core/utils/theme_extensions.dart';
import 'media_picker_sheet.dart';
import '../../core/services/api_config_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// THEME COLORS - MARTIT PURPLE
// ══════════════════════════════════════════════════════════════════════════════
class _LuxuryColors {
  // Light theme backgrounds
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEDEAF7);

  // Deep navy (secondary accents)
  static const Color navyPrimary = Color(0xFF0F172A);
  static const Color navyDark = Color(0xFF020617);

  // MartIt purple accents
  static const Color orangePrimary = Color(0xFF5C33EA);
  static const Color orangeLight = Color(0xFF8B7AF0);
  static const Color orangeDark = Color(0xFF4A28C4);

  // Toggle/Card tint
  static const Color orangeTint = Color(0xFFEAE5FC);

  // Text colors for light theme
  static const Color textPrimary = Color(0xFF1A1333);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textHint = Color(0xFF9CA3AF);

  // Input field colors
  static const Color inputBg = Color(0xFFF5F3FF);
  static const Color inputBorder = Color(0xFFE0DBF5);

  // Toggle colors
  static const Color toggleOff = Color(0xFFD1D5DB);
  static const Color toggleTrackOff = Color(0xFFE5E7EB);
}

class AddProductScreen extends StatefulWidget {
  final List<String> mediaFiles;
  final String? itemId;

  /// When true, screen acts as product editor (same form as add).
  final bool isEditing;

  /// Prefill data from `get_item` / profile item when editing.
  final Map<String, dynamic>? existingItem;

  const AddProductScreen({
    super.key,
    required this.mediaFiles,
    this.itemId,
    this.isEditing = false,
    this.existingItem,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  final PageController _mediaController = PageController();

  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _engnameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _description_arb_Controller =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  List<String> _mediaFiles = [];
  int _currentMediaIndex = 0;
  bool _isPublic = true;
  bool _commentsEnabled = true;
  bool _isUploading = false;
  String? _currentItemId;
  String _savedMediaString = '';
  int _uploadedMediaCount = 0;
  Timer? _autoSaveTimer;

  /// Per-path upload progress (0.0–1.0). Presence means actively uploading.
  final Map<String, double> _mediaUploadProgress = {};

  /// Cached video frame thumbnails keyed by local file path.
  final Map<String, Uint8List> _videoThumbnails = {};

  final List<String> _pendingUploadPaths = [];
  final BackgroundMediaUploadService _uploads =
      BackgroundMediaUploadService.instance;

  // Categories for autocomplete
  List<String> _categories = [];
  bool _isLoadingCategories = true;

  String get _lang => LocalizationService.instance.currentLanguage;

  Color get _onSurface => Theme.of(context).colorScheme.onSurface;

  Color get _onSurfaceSecondary => AppColors.textSecondaryColor(context);

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _outline => Theme.of(context).colorScheme.outline;

  // Animation controllers
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  // Focus nodes for glow effect
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _fieldFocused = {};

  Future<void> insertOneRecord() async {
    final country = getCountryCode();
    final uid = await FlutterSecureStorage().read(key: 'user_uid');
    final request = await Dio().post(
      ApiConfigService.instance.sqlUrl(),
      data: FormData.fromMap({
        'action': 'insertNewOne',
        'country': country,
        'store_id': '1',
        if (uid != null && uid.isNotEmpty) 'uid': uid,
      }),
    );
    if (!mounted) return;
    setState(() {
      _currentItemId = request.data['item_id'].toString();
    });
    await _uploadInitialMediaIfNeeded();
    await _flushPendingUploads();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Dio().post(
        ApiConfigService.instance.sqlUrl(),
        data: FormData.fromMap({'action': 'get_categories'}),
      );

      if (response.data['status'] == 'success' &&
          response.data['categories'] != null) {
        setState(() {
          _categories = List<String>.from(response.data['categories']);
          _isLoadingCategories = false;
        });
      } else {
        setState(() => _isLoadingCategories = false);
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  bool _isRemoteMedia(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool _isVideoPath(String path) {
    final clean = path.toLowerCase().split('?').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.m4v') ||
        ItemMediaUrlUtil.isVideoUrl(path);
  }

  void _prefillFromExistingItem(Map<String, dynamic> item) {
    _barcodeController.text = item['barcode']?.toString() ?? '';
    _nameController.text = item['name']?.toString() ?? '';
    _engnameController.text = item['eng']?.toString() ?? '';
    _descriptionController.text = item['description']?.toString() ?? '';
    _description_arb_Controller.text =
        item['description_arb']?.toString() ?? '';
    _priceController.text = item['price']?.toString() ?? '';
    final qty = item['qtt'] ?? item['quantity'];
    _quantityController.text = qty?.toString() ?? '1';
    _categoryController.text = item['category']?.toString() ?? '';

    final visibility = item['visibility']?.toString().toLowerCase() ?? 'public';
    _isPublic = visibility != 'private';

    final comments = item['comments']?.toString().toLowerCase() ?? 'on';
    _commentsEnabled =
        comments != 'off' && comments != '0' && comments != 'false';

    final mediaRaw = item['media_raw']?.toString() ?? '';
    if (mediaRaw.trim().isNotEmpty) {
      _savedMediaString = mediaRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      _uploadedMediaCount = _savedMediaString.isEmpty
          ? 0
          : _savedMediaString.split(',').length;
    } else if (widget.mediaFiles.isNotEmpty) {
      // Fallback: derive filenames from remote URLs
      final names = <String>[];
      for (final url in widget.mediaFiles) {
        final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
        if (segments.isNotEmpty) {
          final fileName = segments.last;
          if (fileName.isNotEmpty) names.add(fileName);
        }
      }
      _savedMediaString = names.join(', ');
      _uploadedMediaCount = names.length;
    }
  }

  Future<void> _generateVideoThumbnails(List<String> paths) async {
    for (final path in paths) {
      if (!_isVideoPath(path) || _videoThumbnails.containsKey(path)) continue;
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 280,
          quality: 70,
        );
        if (bytes != null && mounted) {
          setState(() => _videoThumbnails[path] = bytes);
        }
      } catch (e) {
        print('Video thumbnail error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _mediaFiles = List.from(widget.mediaFiles);

    if (widget.isEditing) {
      _currentItemId = widget.itemId ?? widget.existingItem?['id']?.toString();
      if (widget.existingItem != null) {
        _prefillFromExistingItem(widget.existingItem!);
      }
    } else if (widget.itemId != null && widget.itemId!.isNotEmpty) {
      _currentItemId = widget.itemId;
    } else {
      insertOneRecord();
    }

    if (_mediaFiles.isNotEmpty) {
      _generateVideoThumbnails(
        _mediaFiles.where((p) => _isVideoPath(p)).toList(),
      );
      if (!widget.isEditing) {
        _uploadInitialMediaIfNeeded();
      }
    }

    _uploads.addListener(_onBackgroundUpload);
    _fetchCategories();
    _initAnimations();
    _initFocusNodes();
    _initAutoSaveListeners();
    _categoryController.addListener(() {
      if (mounted) setState(() {});
    });
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _initAutoSaveListeners() {
    for (final controller in [
      _barcodeController,
      _nameController,
      _engnameController,
      _descriptionController,
      _description_arb_Controller,
      _priceController,
      _quantityController,
      _categoryController,
    ]) {
      controller.addListener(_scheduleAutoSave);
    }
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 800), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_currentItemId == null) return;

    final uid = await FlutterSecureStorage().read(key: 'user_uid');
    if (uid == null || uid.isEmpty) return;

    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    if (name.isEmpty || price.isEmpty) return;

    try {
      final itemId = _currentItemId!;
      await _uploads.runExclusive(itemId, () async {
        final serviceMedia = _uploads.savedMediaOf(itemId);
        final media = serviceMedia.isNotEmpty ? serviceMedia : _savedMediaString;
        _savedMediaString = media;
        await DatabaseService.updateItem(
          itemId: itemId,
          uid: uid,
          barcode: _barcodeController.text.trim(),
          name: name,
          eng: _engnameController.text.trim(),
          description: _descriptionController.text.trim(),
          description_arb: _description_arb_Controller.text.trim(),
          category: _categoryController.text.trim(),
          price: price,
          quantity: _quantityController.text.trim().isEmpty
              ? '0'
              : _quantityController.text.trim(),
          visibility: _isPublic ? 'Public' : 'Private',
          comments: _commentsEnabled ? 'on' : 'off',
          media: media,
        );
      });
    } catch (e) {
      print('Auto-save error: $e');
    }
  }

  Future<void> _flushAutoSave() async {
    _autoSaveTimer?.cancel();
    await _autoSave();
  }

  Future<void> _uploadInitialMediaIfNeeded() async {
    if (_currentItemId == null) return;
    final localPaths = _mediaFiles.where((p) => !_isRemoteMedia(p)).toList();
    if (localPaths.isEmpty) return;
    // Skip paths already counted as uploaded (edit / prior batch).
    if (!widget.isEditing && _uploadedMediaCount > 0) return;
    await _enqueueMediaUploads(localPaths);
  }

  Future<void> _addMediaPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final localOnly = paths.where((p) => !_isRemoteMedia(p)).toList();
    setState(() {
      _mediaFiles.addAll(paths);
    });
    await _generateVideoThumbnails(
      paths.where((p) => _isVideoPath(p)).toList(),
    );
    if (localOnly.isNotEmpty) {
      await _enqueueMediaUploads(localOnly);
    }
  }

  void _onBackgroundUpload() {
    if (!mounted || _currentItemId == null) return;
    final itemId = _currentItemId!;
    final active = _uploads.progressByPath(itemId);
    final saved = _uploads.savedMediaOf(itemId);
    final count = _uploads.uploadedCountOf(itemId);
    setState(() {
      if (saved.isNotEmpty || count > 0) {
        _savedMediaString = saved;
        _uploadedMediaCount = count;
      }
      _mediaUploadProgress
        ..clear()
        ..addAll(active);
    });
  }

  Future<void> _flushPendingUploads() async {
    if (_currentItemId == null || _pendingUploadPaths.isEmpty) return;
    final pending = List<String>.from(_pendingUploadPaths);
    _pendingUploadPaths.clear();
    _enqueueMediaUploads(pending);
  }

  Future<void> _enqueueMediaUploads(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    if (_currentItemId == null) {
      for (final path in filePaths) {
        if (!_pendingUploadPaths.contains(path)) {
          _pendingUploadPaths.add(path);
        }
        _mediaUploadProgress.putIfAbsent(path, () => 0.0);
      }
      if (mounted) setState(() {});
      return;
    }

    _uploads.enqueue(
      itemId: _currentItemId!,
      paths: filePaths,
      startIndex: _uploadedMediaCount,
      savedMedia: _savedMediaString,
    );
    _pendingUploadPaths.removeWhere(filePaths.contains);
  }

  void _initAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initFocusNodes() {
    final fields = [
      'barcode',
      'nameAr',
      'nameEn',
      'descAr',
      'descEn',
      'category',
      'price',
      'quantity',
    ];
    for (final field in fields) {
      _focusNodes[field] = FocusNode();
      _fieldFocused[field] = false;
      _focusNodes[field]!.addListener(() {
        setState(() => _fieldFocused[field] = _focusNodes[field]!.hasFocus);
      });
    }
  }

  @override
  void dispose() {
    _uploads.removeListener(_onBackgroundUpload);
    _autoSaveTimer?.cancel();
    _mediaController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _engnameController.dispose();
    _descriptionController.dispose();
    _description_arb_Controller.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() => _categoryController.text = category);
    _scheduleAutoSave();
  }

  Future<void> _removeMediaAt(int index) async {
    if (index < 0 || index >= _mediaFiles.length) return;

    final removedPath = _mediaFiles[index];
    if (_currentItemId != null) {
      _uploads.cancelPath(_currentItemId!, removedPath);
    }
    final wasUploaded =
        index < _uploadedMediaCount || _isRemoteMedia(removedPath);
    final previousSavedMedia = _savedMediaString;
    final previousUploadedCount = _uploadedMediaCount;
    final previousMediaIndex = _currentMediaIndex;
    final removedThumb = _videoThumbnails[removedPath];
    final removedProgress = _mediaUploadProgress[removedPath];

    String? removedFileName;
    if (wasUploaded && _savedMediaString.isNotEmpty) {
      final parts = _savedMediaString
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (index < parts.length) {
        removedFileName = parts[index];
      }
    }
    if (removedFileName == null && _isRemoteMedia(removedPath)) {
      final segments = Uri.tryParse(removedPath)?.pathSegments ?? const [];
      if (segments.isNotEmpty) removedFileName = segments.last;
    }

    // Optimistic local removal
    setState(() {
      _mediaFiles.removeAt(index);
      _mediaUploadProgress.remove(removedPath);
      _videoThumbnails.remove(removedPath);
      _pendingUploadPaths.removeWhere((p) => p == removedPath);

      if (_currentMediaIndex >= _mediaFiles.length) {
        _currentMediaIndex = _mediaFiles.isEmpty ? 0 : _mediaFiles.length - 1;
      }

      if (wasUploaded && removedFileName != null) {
        final parts = _savedMediaString
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (index < parts.length && parts[index] == removedFileName) {
          parts.removeAt(index);
        } else {
          parts.remove(removedFileName);
        }
        _savedMediaString = parts.join(', ');
        _uploadedMediaCount = parts.length;
      } else if (wasUploaded) {
        _uploadedMediaCount = math.max(0, _uploadedMediaCount - 1);
      }
    });

    if (_mediaFiles.isNotEmpty && _mediaController.hasClients) {
      _mediaController.jumpToPage(
        _currentMediaIndex.clamp(0, _mediaFiles.length - 1),
      );
    }

    // Staged locally only — no S3 object yet
    if (!wasUploaded || removedFileName == null || _currentItemId == null) {
      _scheduleAutoSave();
      return;
    }

    final deleteTarget = _isRemoteMedia(removedPath)
        ? removedPath
        : S3UploadService.mediaObjectKey(
            itemId: _currentItemId!,
            fileName: removedFileName,
          );
    final deleted = await S3UploadService.deleteFile(deleteTarget);

    if (!deleted) {
      if (!mounted) return;
      setState(() {
        final insertAt = index.clamp(0, _mediaFiles.length);
        _mediaFiles.insert(insertAt, removedPath);
        if (removedThumb != null) {
          _videoThumbnails[removedPath] = removedThumb;
        }
        if (removedProgress != null) {
          _mediaUploadProgress[removedPath] = removedProgress;
        }
        _savedMediaString = previousSavedMedia;
        _uploadedMediaCount = previousUploadedCount;
        _currentMediaIndex = previousMediaIndex.clamp(
          0,
          math.max(0, _mediaFiles.length - 1),
        );
      });
      showAppSnackbar(
        context,
        message: _lang == 'ar'
            ? 'تعذر حذف الملف، حاول مرة أخرى'
            : 'Could not delete the file, please try again',
        type: SnackType.error,
      );
      return;
    }

    try {
      final itemId = _currentItemId!;
      await _uploads.runExclusive(itemId, () async {
        _uploads.syncSavedMedia(
          itemId,
          uploadedCount: _uploadedMediaCount,
          savedMedia: _savedMediaString,
        );
        await ApiService.updateItemMedia(
          itemId: itemId,
          media: _savedMediaString,
        );
      });
      _scheduleAutoSave();
    } catch (e) {
      print('Failed to sync media list after delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: _buildLuxuryAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormSection(
                        title: _lang == 'ar' ? 'الصور' : 'Photos',
                        child: _buildPhotosSection(),
                      ),
                      _buildFormSection(
                        title: _lang == 'ar' ? 'اسم المنتج' : 'Product name',
                        child: _buildNameFields(),
                      ),
                      _buildFormSection(
                        title: _lang == 'ar' ? 'الوصف' : 'Description',
                        child: _buildDescriptionFields(),
                      ),
                      _buildFormSection(
                        title: _lang == 'ar' ? 'التصنيف' : 'Category',
                        child: _buildCategoryPickerTile(),
                      ),
                      _buildFormSection(
                        title: _lang == 'ar'
                            ? 'السعر والكمية'
                            : 'Price & Quantity',
                        child: _buildPriceQuantityFields(),
                      ),
                      _buildFormSection(
                        title: _lang == 'ar' ? 'الإعدادات والنشر' : 'Settings',
                        child: _buildSettingsFields(),
                      ),
                    ],
                  ),
                ),
              ),
              _buildPublishBar(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildLuxuryAppBar() {
    return AppBar(
      backgroundColor: context.appBackground,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_ios_new, color: _onSurface, size: 20),
      ),
      title: Text(
        widget.isEditing
            ? (_lang == 'ar' ? 'تعديل المنتج' : 'Edit Product')
            : (_lang == 'ar' ? 'إضافة منتج جديد' : 'Add New Product'),
        style: TextStyle(
          color: _LuxuryColors.orangePrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFormSection({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFEDEAF7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : _LuxuryColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCinematicMediaPreview(),
        const SizedBox(height: 12),
        _buildMediaThumbnailsRow(),
      ],
    );
  }

  Widget _buildPublishBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A30) : const Color(0xFFEDEAF7),
          ),
        ),
      ),
      child: SafeArea(top: false, child: _buildPublishButton()),
    );
  }

  Widget _buildPublishButton() {
    return GestureDetector(
      onTap: _isUploading ? null : _submitProduct,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _LuxuryColors.orangePrimary,
        ),
        child: Center(
          child: _isUploading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _lang == 'ar' ? 'جاري الرفع...' : 'Uploading...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.isEditing
                      ? (_lang == 'ar' ? 'حفظ التعديلات' : 'Save Changes')
                      : (_lang == 'ar' ? 'نشر المنتج' : 'Publish Product'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMediaThumbnailsRow() {
    const double thumbSize = 56;
    const double badgeOverflow = 8;
    return SizedBox(
      height: thumbSize + badgeOverflow,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 6, right: 6),
        children: [
          ...List.generate(_mediaFiles.length, (index) {
            final path = _mediaFiles[index];
            final isVideo = _isVideoPath(path);
            final isSelected = index == _currentMediaIndex;
            final uploadProgress = _mediaUploadProgress[path];
            final isUploading = uploadProgress != null;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() => _currentMediaIndex = index);
                  if (_mediaController.hasClients) {
                    _mediaController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: SizedBox(
                  width: thumbSize,
                  height: thumbSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? _LuxuryColors.orangePrimary
                                : _LuxuryColors.inputBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _LuxuryColors.orangePrimary
                                        .withOpacity(0.25),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildMediaThumbnailContent(
                                path: path,
                                isVideo: isVideo,
                                size: thumbSize,
                              ),
                              if (isUploading)
                                ColoredBox(
                                  color: Colors.black.withOpacity(0.35),
                                  child: Center(
                                    child: SizedBox(
                                      width: 34,
                                      height: 34,
                                      child: CircularProgressIndicator(
                                        value:
                                            (uploadProgress > 0 &&
                                                uploadProgress < 1)
                                            ? uploadProgress
                                            : null,
                                        strokeWidth: 3,
                                        color: const Color(0xFFC6FF3D),
                                        backgroundColor: Colors.white24,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _removeMediaAt(index),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Extra gap between the last thumbnail and the add (+) tile
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: GestureDetector(
              onTap: _showAddMoreMediaBottomSheet,
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _LuxuryColors.orangePrimary,
                    width: 1.5,
                  ),
                  color: _LuxuryColors.orangeTint,
                ),
                child: const Icon(
                  Iconsax.add,
                  color: _LuxuryColors.orangePrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnailContent({
    required String path,
    required bool isVideo,
    required double size,
  }) {
    if (!isVideo) {
      if (_isRemoteMedia(path)) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: _LuxuryColors.orangeTint,
            child: const Icon(Iconsax.gallery, size: 18),
          ),
        );
      }
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }

    final thumbBytes = _videoThumbnails[path];
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbBytes != null)
          Image.memory(thumbBytes, fit: BoxFit.cover, width: size, height: size)
        else
          ColoredBox(
            color: _LuxuryColors.navyPrimary,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.video_play,
              color: Colors.white,
              size: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLuxuryTextField(
          controller: _nameController,
          label: _lang == 'ar' ? 'اسم المنتج بالعربي' : 'Product Name (Arabic)',
          hint: _lang == 'ar' ? 'أدخل اسم المنتج' : 'Enter product name',
          icon: Iconsax.text,
          focusKey: 'nameAr',
          textDirection: TextDirection.rtl,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[\u0600-\u06FF\s0-9٠-٩]'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLuxuryTextField(
          controller: _engnameController,
          label: _lang == 'ar'
              ? 'اسم المنتج بالإنجليزي'
              : 'Product Name (English)',
          hint: 'Enter product name',
          icon: Iconsax.text,
          focusKey: 'nameEn',
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,!?"-]')),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLuxuryTextField(
          controller: _description_arb_Controller,
          label: _lang == 'ar' ? 'الوصف بالعربي' : 'Description (Arabic)',
          hint: _lang == 'ar'
              ? 'أدخل وصف المنتج بالعربي'
              : 'Enter Arabic description',
          icon: Iconsax.edit_2,
          maxLines: 4,
          focusKey: 'descAr',
          textDirection: TextDirection.rtl,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'[\u0600-\u06FF\s0-9٠-٩]'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLuxuryTextField(
          controller: _descriptionController,
          label: _lang == 'ar' ? 'الوصف بالإنجليزي' : 'Description (English)',
          hint: 'Enter product description',
          icon: Iconsax.edit_2,
          maxLines: 4,
          focusKey: 'descEn',
          textDirection: TextDirection.ltr,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,!?"-]')),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryPickerTile() {
    final selected = _categoryController.text.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _showCategoryPicker,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252528) : _LuxuryColors.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _LuxuryColors.inputBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Iconsax.tag,
              color: _LuxuryColors.orangePrimary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected.isEmpty
                    ? (_lang == 'ar' ? 'اختر تصنيفاً' : 'Choose a category')
                    : selected,
                style: TextStyle(
                  color: selected.isEmpty ? _onSurfaceSecondary : _onSurface,
                  fontSize: 15,
                  fontWeight: selected.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: _onSurfaceSecondary),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                height: MediaQuery.of(sheetContext).size.height * 0.75,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1F) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _LuxuryColors.inputBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _lang == 'ar' ? 'اختر تصنيفاً' : 'Choose a category',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : _LuxuryColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCategoryGrid(
                              onSelected: () => setSheetState(() {}),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _lang == 'ar'
                                  ? 'أو أدخل تصنيفاً جديداً'
                                  : 'Or enter a new category',
                              style: TextStyle(
                                color: _onSurfaceSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildLuxuryTextField(
                              controller: _categoryController,
                              label: _lang == 'ar'
                                  ? 'تصنيف مخصص'
                                  : 'Custom category',
                              hint: _lang == 'ar'
                                  ? 'أدخل تصنيف المنتج'
                                  : 'Enter product category',
                              icon: Iconsax.tag,
                              focusKey: 'category',
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.pop(sheetContext),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _LuxuryColors.orangePrimary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    _lang == 'ar' ? 'تم' : 'Done',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid({VoidCallback? onSelected}) {
    if (_isLoadingCategories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              _LuxuryColors.orangePrimary,
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          _lang == 'ar'
              ? 'لا توجد تصنيفات — أدخل تصنيفاً جديداً أدناه'
              : 'No categories yet — enter one below',
          textAlign: TextAlign.center,
          style: TextStyle(color: _onSurfaceSecondary),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((category) {
        final isSelected = _categoryController.text.trim() == category;
        return GestureDetector(
          onTap: () {
            _selectCategory(category);
            onSelected?.call();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: isSelected ? AppColors.primary : _surface,
              border: Border.all(
                color: isSelected ? AppColors.primary : _outline,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              category,
              style: TextStyle(
                color: isSelected ? Colors.white : _onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceQuantityFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lang == 'ar' ? 'السعر' : 'Price',
                style: TextStyle(
                  color: _onSurfaceSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildNumericField(
                controller: _priceController,
                icon: Iconsax.money_4,
                focusKey: 'price',
                suffix: 'ر.ق',
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _lang == 'ar' ? 'الكمية' : 'Quantity',
                style: TextStyle(
                  color: _onSurfaceSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildQuantityField(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPremiumToggle(
          title: _lang == 'ar' ? 'منتج عام' : 'Public Product',
          subtitle: _lang == 'ar'
              ? 'يمكن لجميع المستخدمين رؤية هذا المنتج'
              : 'All users can see this product',
          value: _isPublic,
          onChanged: (v) {
            setState(() => _isPublic = v);
            _autoSave();
          },
          activeIcon: Iconsax.global,
          inactiveIcon: Iconsax.lock,
        ),
        const SizedBox(height: 16),
        _buildPremiumToggle(
          title: _lang == 'ar' ? 'تفعيل التعليقات' : 'Enable Comments',
          subtitle: _lang == 'ar'
              ? 'السماح للمستخدمين بالتعليق على المنتج'
              : 'Allow users to comment on product',
          value: _commentsEnabled,
          onChanged: (v) {
            setState(() => _commentsEnabled = v);
            _autoSave();
          },
          activeIcon: Iconsax.message,
          inactiveIcon: Iconsax.message_minus,
        ),
        const SizedBox(height: 20),
        Text(
          _lang == 'ar' ? 'الباركود (اختياري)' : 'Barcode (optional)',
          style: TextStyle(color: _onSurfaceSecondary, fontSize: 14),
        ),
        const SizedBox(height: 12),
        _buildBarcodeField(),
      ],
    );
  }

  Widget _buildCinematicMediaPreview({bool fullHeight = false}) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final preview = Container(
          height: fullHeight ? null : 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _LuxuryColors.orangePrimary.withOpacity(
                  0.2 * _glowAnimation.value,
                ),
                blurRadius: 25,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _LuxuryColors.orangePrimary,
                      width: 3,
                    ),
                    color: context.appSurface,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: _mediaFiles.isEmpty
                        ? _buildEmptyMediaState()
                        : PageView.builder(
                            controller: _mediaController,
                            onPageChanged: (index) =>
                                setState(() => _currentMediaIndex = index),
                            itemCount: _mediaFiles.length,
                            itemBuilder: (context, index) {
                              final path = _mediaFiles[index];
                              final isVideo = _isVideoPath(path);
                              final isRemote = _isRemoteMedia(path);
                              if (isVideo) {
                                return VideoPlayerWidget(
                                  networkUrl: isRemote ? path : null,
                                  filePath: isRemote ? null : path,
                                  autoPlay: false,
                                  showControls: true,
                                );
                              }
                              return isRemote
                                  ? Image.network(
                                      path,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                            color: Color(0xFFEAE5FC),
                                            child: Icon(Iconsax.gallery),
                                          ),
                                    )
                                  : Image.file(File(path), fit: BoxFit.cover);
                            },
                          ),
                  ),
                ),
                Positioned(top: 16, left: 16, child: _buildGlowingAddButton()),
                if (_mediaFiles.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _mediaFiles.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentMediaIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentMediaIndex == index
                                ? _LuxuryColors.orangePrimary
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (fullHeight) {
          return SizedBox.expand(child: preview);
        }
        return preview;
      },
    );
  }

  Widget _buildEmptyMediaState() {
    return Container(
      decoration: BoxDecoration(color: context.appBackground),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _LuxuryColors.orangePrimary,
                      boxShadow: [
                        BoxShadow(
                          color: _LuxuryColors.orangePrimary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Iconsax.camera,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              _lang == 'ar' ? 'أضف صور أو فيديو للمنتج' : 'Add photos or video',
              style: const TextStyle(
                color: _LuxuryColors.orangePrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lang == 'ar'
                  ? 'اضغط على زر الإضافة للبدء'
                  : 'Tap the add button to start',
              style: TextStyle(color: _onSurfaceSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingAddButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _showAddMoreMediaBottomSheet,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: _LuxuryColors.orangePrimary,
              boxShadow: [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(
                    0.5 * _pulseAnimation.value,
                  ),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Iconsax.add, color: Colors.white, size: 26),
          ),
        );
      },
    );
  }

  // Generate random 12-digit EAN barcode
  String _generateRandomBarcode() {
    final random = math.Random();
    String barcode = '';
    for (int i = 0; i < 12; i++) {
      barcode += random.nextInt(10).toString();
    }
    return barcode;
  }

  Widget _buildBarcodeField() {
    final isFocused = _fieldFocused['barcode'] ?? false;
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: _barcodeController,
              focusNode: _focusNodes['barcode'],
              keyboardType: TextInputType.number,
              style: TextStyle(color: _onSurface, fontSize: 16),
              decoration: InputDecoration(
                labelText: _lang == 'ar' ? 'الباركود' : 'Barcode',
                hintText: _lang == 'ar'
                    ? 'أدخل باركود المنتج'
                    : 'Enter product barcode',
                hintStyle: TextStyle(color: _onSurfaceSecondary),
                labelStyle: TextStyle(
                  color: isFocused
                      ? _LuxuryColors.orangePrimary
                      : _onSurfaceSecondary,
                  fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                ),
                prefixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _barcodeController.text = _generateRandomBarcode();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _LuxuryColors.orangePrimary,
                    ),
                    child: const Icon(
                      Iconsax.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? context.appSurface
                    : _LuxuryColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _LuxuryColors.inputBorder,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _LuxuryColors.orangePrimary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _lang == 'ar' ? 'مسح الباركود' : 'Scan Barcode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, '-1'),
                            child: Text(
                              _lang == 'ar' ? 'إلغاء' : 'Cancel',
                              style: const TextStyle(color: Color(0xFFD4AF37)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: MobileScanner(
                        onDetect: (capture) {
                          final barcode = capture.barcodes.firstOrNull;
                          if (barcode?.rawValue != null) {
                            Navigator.pop(context, barcode!.rawValue);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (result != null && result != '-1') {
              setState(() => _barcodeController.text = result);
            }
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _LuxuryColors.orangeDark,
                  boxShadow: [
                    BoxShadow(
                      color: _LuxuryColors.orangePrimary.withOpacity(0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.scan_barcode,
                  color: Colors.white,
                  size: 24,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String focusKey,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isFocused = _fieldFocused[focusKey] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                  blurRadius: 12,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: _focusNodes[focusKey],
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: textDirection,
        inputFormatters: inputFormatters,
        style: TextStyle(color: _onSurface, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: _onSurfaceSecondary),
          labelStyle: TextStyle(
            color: isFocused
                ? _LuxuryColors.orangePrimary
                : _onSurfaceSecondary,
            fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
          ),
          prefixIcon: Icon(
            icon,
            color: isFocused
                ? _LuxuryColors.orangePrimary
                : _onSurfaceSecondary,
            size: 22,
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? context.appSurface
              : _LuxuryColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _LuxuryColors.orangePrimary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required IconData icon,
    required String focusKey,
    String? label,
    String? suffix,
  }) {
    final isFocused = _fieldFocused[focusKey] ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                  blurRadius: 12,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: _focusNodes[focusKey],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: label == null
              ? null
              : TextStyle(
                  color: isFocused
                      ? _LuxuryColors.orangePrimary
                      : _onSurfaceSecondary,
                ),
          suffixText: suffix,
          suffixStyle: TextStyle(
            color: _LuxuryColors.orangePrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: isFocused
                ? _LuxuryColors.orangePrimary
                : _onSurfaceSecondary,
            size: 20,
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? context.appSurface
              : _LuxuryColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: _LuxuryColors.orangePrimary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    final isFocused = _fieldFocused['quantity'] ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? context.appSurface : _LuxuryColors.inputBg,
        border: Border.all(
          color: isFocused
              ? _LuxuryColors.orangePrimary
              : _LuxuryColors.inputBorder,
          width: isFocused ? 2 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                  blurRadius: 12,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          _buildQuantityButton(
            icon: Iconsax.minus,
            onTap: () {
              final current = int.tryParse(_quantityController.text) ?? 1;
              if (current > 1) {
                _quantityController.text = (current - 1).toString();
                setState(() {});
                _scheduleAutoSave();
              }
            },
          ),
          Expanded(
            child: TextField(
              controller: _quantityController,
              focusNode: _focusNodes['quantity'],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _onSurface,
              ),
              decoration: const InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          _buildQuantityButton(
            icon: Iconsax.add,
            onTap: () {
              final current = int.tryParse(_quantityController.text) ?? 0;
              _quantityController.text = (current + 1).toString();
              setState(() {});
              _scheduleAutoSave();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _LuxuryColors.orangePrimary,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildPremiumToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: value
            ? (isDark ? AppColors.darkElevated : _LuxuryColors.orangeTint)
            : surface,
        border: Border.all(
          color: value
              ? _LuxuryColors.orangePrimary.withOpacity(0.3)
              : _outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: value ? _LuxuryColors.orangePrimary : surface,
              border: value ? null : Border.all(color: _outline),
            ),
            child: Icon(
              value ? activeIcon : inactiveIcon,
              color: value ? Colors.white : _onSurfaceSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: value
                        ? (isDark ? Colors.white : _LuxuryColors.orangePrimary)
                        : _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: _onSurfaceSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _LuxuryColors.orangePrimary,
              activeTrackColor: _LuxuryColors.orangePrimary.withOpacity(0.4),
              inactiveThumbColor: surface,
              inactiveTrackColor: isDark
                  ? AppColors.darkElevated
                  : _LuxuryColors.toggleTrackOff,
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.transparent;
                }
                return isDark ? AppColors.darkBorder : _LuxuryColors.toggleOff;
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMoreMediaBottomSheet() {
    final isAr = _lang == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'إضافة وسائط' : 'Add Media',
        subtitle: isAr
            ? 'اختر طريقة إضافة المحتوى لمنتجك'
            : 'Choose how to add content for your product',
        options: [
          MediaPickerOption(
            icon: Iconsax.camera5,
            label: isAr ? 'إضافة صورة' : 'Add Photo',
            subtitle: isAr ? 'التقط صورة للمنتج' : 'Take a product photo',
            onTap: () {
              Navigator.pop(sheetContext);
              _showImageSourceBottomSheet();
            },
          ),
          MediaPickerOption(
            icon: Iconsax.video_play,
            label: isAr ? 'إضافة فيديو' : 'Add Video',
            subtitle: isAr ? 'سجل فيديو للمنتج' : 'Record a product video',
            onTap: () {
              Navigator.pop(sheetContext);
              _showVideoSourceBottomSheet();
            },
          ),
        ],
      ),
    );
  }

  void _showImageSourceBottomSheet() {
    final isAr = _lang == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'إضافة صورة' : 'Add Photo',
        subtitle: isAr
            ? 'التقط صورة جديدة أو اختر من المعرض'
            : 'Take a new photo or pick from gallery',
        onBack: () {
          Navigator.pop(sheetContext);
          _showAddMoreMediaBottomSheet();
        },
        options: [
          MediaPickerOption(
            icon: Iconsax.camera5,
            label: isAr ? 'التقاط صورة' : 'Take Photo',
            subtitle: isAr
                ? 'استخدم الكاميرا لالتقاط صورة جديدة'
                : 'Use camera to take a new photo',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraScreen(isVideo: false),
                ),
              ).then((result) async {
                final paths = result is List
                    ? result
                        .map((e) => e.toString())
                        .where((e) => e.isNotEmpty)
                        .toList()
                    : const <String>[];
                if (paths.isNotEmpty) {
                  await _addMediaPaths(paths);
                }
              });
            },
          ),
          MediaPickerOption(
            icon: Iconsax.gallery5,
            label: isAr ? 'اختيار من المعرض' : 'Choose from Gallery',
            subtitle: isAr
                ? 'اختر صورة من معرض الصور'
                : 'Choose from photo gallery',
            onTap: () {
              Navigator.pop(sheetContext);
              _pickImagesFromGallery();
            },
          ),
        ],
      ),
    );
  }

  void _showVideoSourceBottomSheet() {
    final isAr = _lang == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'إضافة فيديو' : 'Add Video',
        subtitle: isAr
            ? 'سجّل فيديو جديد أو اختر من المعرض'
            : 'Record a new video or pick from gallery',
        onBack: () {
          Navigator.pop(sheetContext);
          _showAddMoreMediaBottomSheet();
        },
        options: [
          MediaPickerOption(
            icon: Iconsax.video_circle,
            label: isAr ? 'تسجيل فيديو' : 'Record Video',
            subtitle: isAr
                ? 'استخدم الكاميرا لتسجيل فيديو جديد'
                : 'Use camera to record a new video',
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraScreen(isVideo: true),
                ),
              ).then((result) async {
                final paths = result is List
                    ? result
                        .map((e) => e.toString())
                        .where((e) => e.isNotEmpty)
                        .toList()
                    : const <String>[];
                if (paths.isNotEmpty) {
                  await _addMediaPaths(paths);
                }
              });
            },
          ),
          MediaPickerOption(
            icon: Iconsax.gallery5,
            label: isAr ? 'اختيار من المعرض' : 'Choose from Gallery',
            subtitle: isAr
                ? 'اختر فيديو من معرض الفيديوهات'
                : 'Choose from video gallery',
            onTap: () {
              Navigator.pop(sheetContext);
              _pickVideoFromGallery();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      await _addMediaPaths(images.map((image) => image.path).toList());
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      await _addMediaPaths([video.path]);
    }
  }

  void _showValidationError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: _lang == 'ar' ? 'خطأ' : 'Error',
      desc: message,
      btnOkOnPress: () {},
      btnOkText: _lang == 'ar' ? 'حسناً' : 'OK',
    ).show();
  }

  bool _validateProductForm() {
    if (_mediaFiles.isEmpty) {
      _showValidationError(
        _lang == 'ar'
            ? 'يجب إضافة صورة واحدة على الأقل للمنتج'
            : 'Add at least one photo',
      );
      return false;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      _showValidationError(
        _lang == 'ar' ? 'يجب إدخال اسم المنتج' : 'Product name is required',
      );
      return false;
    }

    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    if (priceText.isEmpty || price == null || price <= 0) {
      _showValidationError(
        _lang == 'ar' ? 'يجب إدخال سعر صحيح للمنتج' : 'Enter a valid price',
      );
      return false;
    }

    final quantityText = _quantityController.text.trim();
    final quantity = int.tryParse(quantityText);
    if (quantityText.isEmpty || quantity == null || quantity <= 0) {
      _showValidationError(
        _lang == 'ar'
            ? 'يجب إدخال كمية صحيحة للمنتج'
            : 'Enter a valid quantity',
      );
      return false;
    }

    if (_categoryController.text.trim().isEmpty) {
      _showValidationError(
        _lang == 'ar' ? 'يجب اختيار تصنيف للمنتج' : 'Select a category',
      );
      return false;
    }

    return true;
  }

  List<String> _publishedMediaUrls() {
    final remote = _mediaFiles.where(_isRemoteMedia).toList();
    if (remote.isNotEmpty) return remote;

    final itemId = _currentItemId;
    if (itemId == null || itemId.isEmpty) return const [];

    final urls = <String>[];
    var index = 1;
    for (final token in _savedMediaString.split(',')) {
      final name = token.trim();
      if (name.isEmpty) continue;
      final ext = ItemMediaUrlUtil.extensionFromMediaToken(name) ?? 'webp';
      urls.add(
        ItemMediaUrlUtil.mediaUrl(
          storeId: '1',
          itemId: itemId,
          index: index,
          extension: ext,
        ),
      );
      index++;
    }
    return urls;
  }

  void _submitProduct() async {
    if (!_validateProductForm()) {
      return;
    }

    await _flushPendingUploads();

    setState(() {
      _isUploading = true;
    });

    if (_currentItemId != null && _currentItemId!.isNotEmpty) {
      _uploads.rememberSnapshot(_currentItemId!, {
        'id': _currentItemId,
        'idx': '',
        'storeid': '1',
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),
      });
    }

    await _flushAutoSave();

    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });

    showAppSnackbar(
      context,
      message: widget.isEditing
          ? (_lang == 'ar'
                ? 'تم حفظ التعديلات بنجاح'
                : 'Changes saved successfully')
          : (_lang == 'ar'
                ? 'تم حفظ المنتج بنجاح'
                : 'Product saved successfully'),
      type: SnackType.success,
    );
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.allMedia.clear();

    if (widget.isEditing || _currentItemId == null || _currentItemId!.isEmpty) {
      Navigator.pop(context, _currentItemId);
      return;
    }

    Navigator.pop(context, {
      'id': _currentItemId,
      'idx': '',
      'storeid': '1',
      'name': _nameController.text.trim(),
      'eng': _engnameController.text.trim(),
      'price': _priceController.text.trim(),
      'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
      'description': _descriptionController.text.trim(),
      'description_arb': _description_arb_Controller.text.trim(),
      'media': _publishedMediaUrls(),
    });
  }
}
