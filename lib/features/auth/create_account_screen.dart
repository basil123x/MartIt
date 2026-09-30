import 'dart:io';
import 'package:MartIt/core/services/onesignal_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../home/main_navigation_screen.dart';
import '../../core/utils/theme_extensions.dart';
import '../add_product/media_picker_sheet.dart';
import '../../core/services/api_config_service.dart';

class CreateAccountScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryDialCode;

  const CreateAccountScreen({
    super.key,
    required this.phoneNumber,
    this.countryDialCode = '+974',
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final lang = LocalizationService.instance.currentLanguage;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: lang == 'ar'
            ? 'حدث خطأ أثناء اختيار الصورة'
            : 'Error selecting image',
        type: SnackType.error,
      );
    }
  }

  Future<void> _takePhoto() async {
    final lang = LocalizationService.instance.currentLanguage;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: lang == 'ar' ? 'حدث خطأ أثناء التقاط الصورة' : 'Error taking photo',
        type: SnackType.error,
      );
    }
  }

  void _showImagePickerOptions() {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';
    final options = <MediaPickerOption>[
      MediaPickerOption(
        icon: Iconsax.camera5,
        label: isAr ? 'التقاط صورة' : 'Take photo',
        subtitle: isAr ? 'استخدم الكاميرا' : 'Use camera',
        onTap: () {
          Navigator.pop(context);
          _takePhoto();
        },
      ),
      MediaPickerOption(
        icon: Iconsax.gallery5,
        label: isAr ? 'اختيار من المعرض' : 'Choose from gallery',
        subtitle: isAr ? 'اختر صورة موجودة' : 'Choose existing photo',
        onTap: () {
          Navigator.pop(context);
          _pickImage();
        },
      ),
    ];
    if (_selectedImage != null) {
      options.add(
        MediaPickerOption(
          icon: Iconsax.trash,
          label: isAr ? 'حذف الصورة' : 'Remove photo',
          subtitle: isAr ? 'إزالة الصورة المحددة' : 'Clear selected photo',
          accent: AppColors.error,
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _selectedImage = null;
            });
          },
        ),
      );
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => MediaPickerSheet(
        title: isAr ? 'اختر صورة الملف الشخصي' : 'Choose profile photo',
        subtitle: isAr
            ? 'التقط صورة جديدة أو اختر من المعرض'
            : 'Take a new photo or pick from gallery',
        options: options,
      ),
    );
  }

  Future<void> _createAccount() async {
    final lang = LocalizationService.instance.currentLanguage;
    if (_nameController.text.trim().isEmpty) {
      showAppSnackbar(
        context,
        message: lang == 'ar' ? 'يرجى إدخال اسمك الكامل' : 'Please enter your full name',
        type: SnackType.error,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.createWithPhone(
        widget.phoneNumber,
        _nameController.text.trim(),
        profileImage: _selectedImage?.path,
      );
      final request = await Dio().post(
        ApiConfigService.instance.sqlEndpoint,
        data: FormData.fromMap({"action": "get_tokens"}),
      );
      List playerIds = request.data['player_ids'];
      List<String> setPlayers = [];
      for (var player_id in playerIds) {
        setState(() {
          setPlayers.add(player_id['player_id'].toString());
        });
        await OneSignalService.sendNotificationToMultipleUsers(
          playerIds: setPlayers,
          title: "مستخدم جديد انضم إلى التطبيق",
          message:
              "تم تسجيل مستخدم جديد في النظام. اضغط هنا لعرض التفاصيل أو متابعة النشاط.",
        );
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      showAppSnackbar(
        context,
        message: lang == 'ar' ? 'حدث خطأ أثناء إنشاء الحساب' : 'Error creating account',
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: context.appSurface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Iconsax.arrow_left, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    lang == 'ar'
                                        ? 'إنشاء حساب جديد'
                                        : 'Create New Account',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    lang == 'ar'
                                        ? 'أكمل بياناتك للانضمام إلى ${AppStrings.appName}'
                                        : 'Complete your info to join ${AppStrings.appName}',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondaryColor(context),
                                        ),
                                  ),
                                  const SizedBox(height: 50),
                                  GestureDetector(
                                    onTap: _showImagePickerOptions,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.lightGrey,
                                        border: Border.all(
                                          color: AppColors.primary,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: _selectedImage != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _selectedImage!,
                                                fit: BoxFit.cover,
                                                width: 120,
                                                height: 120,
                                              ),
                                            )
                                          : const Icon(
                                              Iconsax.camera,
                                              size: 40,
                                              color: AppColors.primary,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    lang == 'ar'
                                        ? 'اضغط لإضافة صورة شخصية'
                                        : 'Tap to add profile photo',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondaryColor(context),
                                        ),
                                  ),
                                  const SizedBox(height: 40),
                                  TextField(
                                    controller: _nameController,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      hintText: lang == 'ar'
                                          ? 'اسمك الكامل'
                                          : 'Your full name',
                                      hintStyle: TextStyle(
                                        color: AppColors.textHint,
                                      ),
                                      prefixIcon: const Icon(
                                        Iconsax.user,
                                        color: AppColors.primary,
                                      ),
                                      filled: true,
                                      fillColor: context.appSurface,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.lightGrey,
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.lightGrey,
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.primary,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _createAccount,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        elevation: 8,
                                        shadowColor: AppColors.primary.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                      Colors.white,
                                                    ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Iconsax.user_add,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  lang == 'ar'
                                                      ? 'إنشاء حساب'
                                                      : 'Create Account',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.lightGrey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Iconsax.mobile,
                                    size: 16,
                                    color: AppColors.textSecondaryColor(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.countryDialCode} ${widget.phoneNumber}',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondaryColor(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
