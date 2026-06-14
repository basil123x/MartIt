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
import '../../core/constants/app_colors.dart';
import '../../core/utils/country_code_util.dart';
import '../../core/widgets/video_player_widget.dart';
import '../../core/services/api_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/services/s3_upload_service.dart';
import '../camera/camera_screen.dart';
import '../../core/utils/theme_extensions.dart';

// ══════════════════════════════════════════════════════════════════════════════
// THEME COLORS - MATCHING ONBOARDING BLUE
// ══════════════════════════════════════════════════════════════════════════════
class _LuxuryColors {
  // Light theme backgrounds
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE0E0E0);

  // Deep navy (secondary accents)
  static const Color navyPrimary = Color(0xFF0F172A);
  static const Color navyDark = Color(0xFF020617);

  // Blue accents (matching onboarding)
  static const Color orangePrimary = Color(0xFF1E3A8A);
  static const Color orangeLight = Color(0xFF2D5BE3);
  static const Color orangeDark = Color(0xFF152C6B);

  // Toggle/Card tint
  static const Color orangeTint = Color(0xFFEEF2FF);

  // Text colors for light theme
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Input field colors
  static const Color inputBg = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFD1D5DB);

  // Toggle colors
  static const Color toggleOff = Color(0xFFD1D5DB);
  static const Color toggleTrackOff = Color(0xFFE5E7EB);

  // Blue gradient (primary accent)
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [orangeLight, orangePrimary, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Navy gradient
  static const LinearGradient navyGradient = LinearGradient(
    colors: [navyPrimary, navyDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}

class AddProductScreen extends StatefulWidget {
  final List<String> mediaFiles;
  final String? itemId;

  const AddProductScreen({super.key, required this.mediaFiles, this.itemId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  final PageController _mediaController = PageController();
  final PageController _stepPageController = PageController();

  static const int _totalSteps = 6;
  int _currentStep = 0;

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
  bool _isMediaUploading = false;
  String? _currentItemId;
  String _savedMediaString = '';
  int _uploadedMediaCount = 0;
  Timer? _autoSaveTimer;

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
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;

  // Focus nodes for glow effect
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _fieldFocused = {};

  Future<void> insertOneRecord() async {
    final country = getCountryCode();
    final uid = await FlutterSecureStorage().read(key: 'user_uid');
    final request = await Dio().post(
      'https://Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
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
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Dio().post(
        'https://Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
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

  @override
  void initState() {
    super.initState();
    _mediaFiles = List.from(widget.mediaFiles);
    if (widget.itemId != null && widget.itemId!.isNotEmpty) {
      _currentItemId = widget.itemId;
      if (_mediaFiles.isNotEmpty) {
        _uploadInitialMediaIfNeeded();
      }
    } else {
      insertOneRecord();
    }
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
      await DatabaseService.updateItem(
        itemId: _currentItemId!,
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
        media: _savedMediaString,
      );
    } catch (e) {
      print('Auto-save error: $e');
    }
  }

  Future<void> _flushAutoSave() async {
    _autoSaveTimer?.cancel();
    await _autoSave();
  }

  Future<void> _uploadInitialMediaIfNeeded() async {
    if (_currentItemId == null || _uploadedMediaCount > 0) return;
    if (_mediaFiles.isEmpty) return;
    await _uploadMediaImmediately(List.from(_mediaFiles));
  }

  Future<void> _addMediaPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    setState(() {
      _mediaFiles.addAll(paths);
    });
    await _uploadMediaImmediately(paths);
  }

  Future<void> _uploadMediaImmediately(List<String> filePaths) async {
    if (_currentItemId == null || filePaths.isEmpty || _isMediaUploading) {
      return;
    }

    setState(() => _isMediaUploading = true);
    try {
      final uploadedUrls = await S3UploadService.uploadMediaFiles(
        filePaths: filePaths,
        itemId: _currentItemId!,
        startIndex: _uploadedMediaCount,
      );

      if (uploadedUrls.isEmpty) return;

      final newNames = uploadedUrls.map((url) => url.split('/').last).toList();
      _uploadedMediaCount += newNames.length;

      final newMediaChunk = newNames.join(', ');
      _savedMediaString = _savedMediaString.isEmpty
          ? newMediaChunk
          : '$_savedMediaString, $newMediaChunk';

      await ApiService.updateItemMedia(
        itemId: _currentItemId!,
        media: _savedMediaString,
      );

      await _autoSave();

      if (mounted) setState(() {});
    } catch (e) {
      print('Media upload error: $e');
    } finally {
      if (mounted) setState(() => _isMediaUploading = false);
    }
  }

  void _initAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
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
    _autoSaveTimer?.cancel();
    _mediaController.dispose();
    _stepPageController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _engnameController.dispose();
    _descriptionController.dispose();
    _description_arb_Controller.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return _lang == 'ar' ? 'إضافة صور' : 'Add Photos';
      case 1:
        return _lang == 'ar' ? 'اسم المنتج' : 'Product Name';
      case 2:
        return _lang == 'ar' ? 'الوصف' : 'Description';
      case 3:
        return _lang == 'ar' ? 'التصنيف' : 'Category';
      case 4:
        return _lang == 'ar' ? 'السعر والكمية' : 'Price & Quantity';
      case 5:
        return _lang == 'ar' ? 'الإعدادات والنشر' : 'Settings & Publish';
      default:
        return '';
    }
  }

  void _goToStep(int step) {
    if (step < 0 || step >= _totalSteps) return;
    FocusScope.of(context).unfocus();
    _stepPageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  bool _canProceedFromCurrentStep() {
    if (_currentStep == 0) return _mediaFiles.isNotEmpty;
    return true;
  }

  void _selectCategory(String category) {
    setState(() => _categoryController.text = category);
    _scheduleAutoSave();
  }

  void _removeMediaAt(int index) {
    if (index < 0 || index >= _mediaFiles.length) return;

    setState(() {
      _mediaFiles.removeAt(index);

      if (_currentMediaIndex >= _mediaFiles.length) {
        _currentMediaIndex = _mediaFiles.isEmpty
            ? 0
            : _mediaFiles.length - 1;
      }

      if (index < _uploadedMediaCount && _savedMediaString.isNotEmpty) {
        final parts = _savedMediaString
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (index < parts.length) {
          parts.removeAt(index);
          _savedMediaString = parts.join(', ');
          _uploadedMediaCount = parts.length;
          _scheduleAutoSave();
          if (_currentItemId != null) {
            ApiService.updateItemMedia(
              itemId: _currentItemId!,
              media: _savedMediaString,
            );
          }
        }
      } else if (index < _uploadedMediaCount) {
        _uploadedMediaCount = math.max(0, _uploadedMediaCount - 1);
      }
    });

    if (_mediaFiles.isNotEmpty && _mediaController.hasClients) {
      _mediaController.jumpToPage(
        _currentMediaIndex.clamp(0, _mediaFiles.length - 1),
      );
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
              _buildStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _stepPageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentStep = index),
                  children: [
                    _buildMediaStep(),
                    _buildNameStep(),
                    _buildDescriptionStep(),
                    _buildCategoryStep(),
                    _buildPriceQuantityStep(),
                    _buildSettingsStep(),
                  ],
                ),
              ),
              _buildBottomNav(),
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
      leading: Container(),
      actions: [
        Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LuxuryColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Iconsax.arrow_right_3,
                color: _onSurface,
                size: 20,
              ),
            ),
          ),
        ),
      ],
      title: ShaderMask(
        shaderCallback: (bounds) =>
            _LuxuryColors.orangeGradient.createShader(bounds),
        child: Text(
          _stepTitle(_currentStep),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (index) {
          final isActive = _currentStep == index;
          final isPast = index < _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: isActive ? _LuxuryColors.orangeGradient : null,
              color: isActive
                  ? null
                  : isPast
                  ? _LuxuryColors.orangePrimary.withOpacity(0.5)
                  : _LuxuryColors.orangePrimary.withOpacity(0.2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isLastStep = _currentStep == _totalSteps - 1;
    final canProceed = _canProceedFromCurrentStep();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          _buildNavButton(
            label: _lang == 'ar' ? 'رجوع' : 'Back',
            onPressed: _currentStep > 0 ? _previousStep : null,
            outlined: true,
          ),
          const Spacer(),
          if (isLastStep)
            _buildNavButton(
              label: _lang == 'ar' ? 'نشر' : 'Publish',
              onPressed: _submitProduct,
              outlined: false,
            )
          else
            _buildNavButton(
              label: _lang == 'ar' ? 'التالي' : 'Next',
              onPressed: canProceed ? _nextStep : null,
              outlined: false,
            ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required VoidCallback? onPressed,
    required bool outlined,
  }) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: outlined || !enabled ? null : _LuxuryColors.orangeGradient,
              color: outlined ? context.appSurface : null,
              border: outlined
                  ? Border.all(
                      color: enabled
                          ? _LuxuryColors.orangePrimary
                          : _LuxuryColors.inputBorder,
                    )
                  : null,
              boxShadow: !outlined && enabled
                  ? [
                      BoxShadow(
                        color: _LuxuryColors.orangePrimary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: outlined
                    ? (enabled
                          ? _LuxuryColors.orangePrimary
                          : _onSurfaceSecondary)
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: _buildCinematicMediaPreview(fullHeight: true),
          ),
        ),
        _buildMediaThumbnailsRow(),
        if (_isMediaUploading)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _LuxuryColors.orangePrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _lang == 'ar' ? 'جاري رفع الوسائط...' : 'Uploading media...',
                  style: TextStyle(
                    color: _onSurfaceSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMediaThumbnailsRow() {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...List.generate(_mediaFiles.length, (index) {
            final path = _mediaFiles[index];
            final isVideo = path.toLowerCase().contains('.mp4');
            final isSelected = index == _currentMediaIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
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
                  width: 80,
                  height: 80,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _LuxuryColors.orangePrimary
                                : _LuxuryColors.inputBorder,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _LuxuryColors.orangePrimary
                                        .withOpacity(0.25),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: isVideo
                              ? ColoredBox(
                                  color: _LuxuryColors.navyPrimary,
                                  child: const Center(
                                    child: Icon(
                                      Iconsax.video_play,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeMediaAt(index),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
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
          GestureDetector(
            onTap: _showAddMoreMediaBottomSheet,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _LuxuryColors.orangePrimary,
                  width: 1.5,
                ),
                color: _LuxuryColors.orangeTint,
              ),
              child: const Icon(
                Iconsax.add,
                color: _LuxuryColors.orangePrimary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
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
          const SizedBox(height: 28),
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
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z0-9\s.,!?"-]'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
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
          const SizedBox(height: 28),
          _buildLuxuryTextField(
            controller: _descriptionController,
            label: _lang == 'ar'
                ? 'الوصف بالإنجليزي'
                : 'Description (English)',
            hint: 'Enter product description',
            icon: Iconsax.edit_2,
            maxLines: 4,
            focusKey: 'descEn',
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[a-zA-Z0-9\s.,!?"-]'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _lang == 'ar' ? 'اختر تصنيفاً' : 'Choose a category',
            style: TextStyle(
              color: _onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryGrid(),
          const SizedBox(height: 28),
          Text(
            _lang == 'ar' ? 'أو أدخل تصنيفاً جديداً' : 'Or enter a new category',
            style: TextStyle(
              color: _onSurfaceSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildLuxuryTextField(
            controller: _categoryController,
            label: _lang == 'ar' ? 'تصنيف مخصص' : 'Custom category',
            hint: _lang == 'ar' ? 'أدخل تصنيف المنتج' : 'Enter product category',
            icon: Iconsax.tag,
            focusKey: 'category',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
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
          onTap: () => _selectCategory(category),
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

  Widget _buildPriceQuantityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          _buildNumericField(
            controller: _priceController,
            label: _lang == 'ar' ? 'السعر' : 'Price',
            icon: Iconsax.money_4,
            focusKey: 'price',
            suffix: 'ر.ق',
          ),
          const SizedBox(height: 40),
          Text(
            _lang == 'ar' ? 'الكمية' : 'Quantity',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onSurfaceSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuantityField(),
        ],
      ),
    );
  }

  Widget _buildSettingsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
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
          const SizedBox(height: 28),
          Text(
            _lang == 'ar' ? 'الباركود (اختياري)' : 'Barcode (optional)',
            style: TextStyle(
              color: _onSurfaceSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildBarcodeField(),
          const SizedBox(height: 32),
          _buildShimmerButton(),
        ],
      ),
    );
  }

  Widget _buildCinematicMediaPreview({bool fullHeight = false}) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final preview = Container(
          height: fullHeight ? null : 380,
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
                    gradient: LinearGradient(
                      colors: [
                        _LuxuryColors.orangeLight.withOpacity(
                          0.9 + 0.1 * _glowAnimation.value,
                        ),
                        _LuxuryColors.orangePrimary.withOpacity(
                          0.85 + 0.15 * _glowAnimation.value,
                        ),
                        _LuxuryColors.orangeDark.withOpacity(
                          0.9 + 0.1 * _glowAnimation.value,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      color: context.appSurface,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: _mediaFiles.isEmpty
                          ? _buildEmptyMediaState()
                          : PageView.builder(
                              controller: _mediaController,
                              onPageChanged: (index) => setState(
                                () => _currentMediaIndex = index,
                              ),
                              itemCount: _mediaFiles.length,
                              itemBuilder: (context, index) {
                                final file = File(_mediaFiles[index]);
                                final isVideo = _mediaFiles[index]
                                    .toLowerCase()
                                    .contains('.mp4');
                                return isVideo
                                    ? VideoPlayerWidget(
                                        filePath: _mediaFiles[index],
                                        autoPlay: false,
                                        showControls: true,
                                      )
                                    : Image.file(file, fit: BoxFit.cover);
                              },
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _buildGlowingAddButton(),
                ),
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
                            gradient: _currentMediaIndex == index
                                ? _LuxuryColors.orangeGradient
                                : null,
                            color: _currentMediaIndex == index
                                ? null
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
                      gradient: _LuxuryColors.orangeGradient,
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
            ShaderMask(
              shaderCallback: (bounds) =>
                  _LuxuryColors.orangeGradient.createShader(bounds),
              child: Text(
                _lang == 'ar'
                    ? 'أضف صور أو فيديو للمنتج'
                    : 'Add photos or video',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lang == 'ar'
                  ? 'اضغط على زر الإضافة للبدء'
                  : 'Tap the add button to start',
              style: TextStyle(
                color: _onSurfaceSecondary,
                fontSize: 14,
              ),
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
              gradient: _LuxuryColors.orangeGradient,
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
              style: TextStyle(
                color: _onSurface,
                fontSize: 16,
              ),
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
                      gradient: _LuxuryColors.orangeGradient,
                    ),
                    child: const Icon(
                      Iconsax.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                filled: true,
                fillColor: context.appSurface,
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
                  gradient: _LuxuryColors.navyGradient,
                  boxShadow: [
                    BoxShadow(
                      color: _LuxuryColors.navyPrimary.withOpacity(0.4),
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
          prefixIcon: ShaderMask(
            shaderCallback: (bounds) => isFocused
                ? _LuxuryColors.orangeGradient.createShader(bounds)
                : LinearGradient(
                    colors: [
                      _onSurfaceSecondary,
                      _onSurfaceSecondary,
                    ],
                  ).createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          filled: true,
          fillColor: context.appSurface,
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
    required String label,
    required IconData icon,
    required String focusKey,
    String? suffix,
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isFocused
                ? _LuxuryColors.orangePrimary
                : _onSurfaceSecondary,
          ),
          suffixText: suffix,
          suffixStyle: TextStyle(
            color: _LuxuryColors.orangePrimary,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: ShaderMask(
            shaderCallback: (bounds) => isFocused
                ? _LuxuryColors.orangeGradient.createShader(bounds)
                : LinearGradient(
                    colors: [
                      _onSurfaceSecondary,
                      _onSurfaceSecondary,
                    ],
                  ).createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          filled: true,
          fillColor: context.appSurface,
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
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    final isFocused = _fieldFocused['quantity'] ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: context.appSurface,
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: TextField(
                    controller: _quantityController,
                    focusNode: _focusNodes['quantity'],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                      ),
                    ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _LuxuryColors.navyGradient,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
              gradient: value ? _LuxuryColors.orangeGradient : null,
              color: value ? null : surface,
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
                  style: TextStyle(
                    color: _onSurfaceSecondary,
                    fontSize: 12,
                  ),
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
              inactiveTrackColor:
                  isDark ? AppColors.darkElevated : _LuxuryColors.toggleTrackOff,
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

  Widget _buildShimmerButton() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _isUploading ? null : _submitProduct,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: _LuxuryColors.orangeGradient,
              boxShadow: [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Transform.translate(
                    offset: Offset(
                      MediaQuery.of(context).size.width *
                          _shimmerAnimation.value,
                      0,
                    ),
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: _LuxuryColors.shimmerGradient,
                      ),
                    ),
                  ),
                ),
                Center(
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Iconsax.send_1,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _lang == 'ar' ? 'نشر المنتج' : 'Publish Product',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMoreMediaBottomSheet() {
    final lang = _lang;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
        color: context.appSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              lang == 'ar' ? 'إضافة وسائط' : 'Add Media',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Iconsax.camera, color: AppColors.primary),
              title: Text(lang == 'ar' ? 'التقاط صورة' : 'Take Photo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(isVideo: false),
                  ),
                ).then((result) async {
                  if (result != null &&
                      result is List<String> &&
                      result.isNotEmpty) {
                    await _addMediaPaths(result);
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.video_circle,
                color: AppColors.secondary,
              ),
              title: Text(lang == 'ar' ? 'تسجيل فيديو' : 'Record Video'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(isVideo: true),
                  ),
                ).then((result) async {
                  if (result != null &&
                      result is List<String> &&
                      result.isNotEmpty) {
                    await _addMediaPaths(result);
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery, color: Colors.green),
              title: Text(
                lang == 'ar' ? 'اختيار من المعرض' : 'Choose from Gallery',
              ),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _pickFromGallery() async {
    final lang = _lang;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang == 'ar' ? 'اختيار نوع الوسائط' : 'Choose Media Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconsax.image),
              title: Text(lang == 'ar' ? 'صور' : 'Photos'),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await picker.pickMultiImage();
                if (images.isNotEmpty) {
                  await _addMediaPaths(
                    images.map((image) => image.path).toList(),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.video_play),
              title: Text(lang == 'ar' ? 'فيديو' : 'Video'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? video = await picker.pickVideo(
                  source: ImageSource.gallery,
                );
                if (video != null) {
                  await _addMediaPaths([video.path]);
                }
              },
            ),
          ],
        ),
      ),
    );
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

  void _submitProduct() async {
    if (!_validateProductForm()) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    await _flushAutoSave();

    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });

    showAppSnackbar(
      context,
      message: _lang == 'ar' ? 'تم حفظ المنتج بنجاح' : 'Product saved successfully',
      type: SnackType.success,
    );
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.allMedia.clear();
    Navigator.pop(context, _currentItemId);
  }
}
