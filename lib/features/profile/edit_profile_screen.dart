import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentType;
  final String currentAvatar;
  final String currentUid;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentPhone,
    required this.currentType,
    required this.currentAvatar,
    required this.currentUid,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  bool _showOtpField = false;
  bool _phoneChanged = false;
  String _generatedOtp = '';
  String _originalPhone = '';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _phoneController.text = widget.currentPhone;
    _originalPhone = widget.currentPhone;

    _phoneController.addListener(() {
      setState(() {
        _phoneChanged = _phoneController.text != _originalPhone;
        if (!_phoneChanged) {
          _showOtpField = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'اختر مصدر الصورة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Iconsax.camera,
                  title: 'الكاميرا',
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectImage(ImageSource.camera);
                  },
                ),
                _buildImageSourceOption(
                  icon: Iconsax.gallery,
                  title: 'المعرض',
                  onTap: () async {
                    Navigator.pop(context);
                    await _selectImage(ImageSource.gallery);
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في اختيار الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendOtp() async {
    if (!AuthService.isValidQatarPhone(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف غير صحيح. يجب أن يكون 8 أرقام'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _generatedOtp = AuthService.generateOTP();
      _showOtpField = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إرسال رمز التحقق: $_generatedOtp'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate OTP if phone changed
    if (_phoneChanged) {
      if (!_showOtpField) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب إرسال رمز التحقق أولاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_otpController.text != _generatedOtp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رمز التحقق غير صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUid = await AuthService.getCurrentUID();
      if (currentUid == null) {
        throw Exception('المستخدم غير مسجل');
      }

      // Update profile in database
      final result = await ApiService.updateUserProfile(
        uid: currentUid,
        name: _nameController.text,
        phone: _phoneController.text,
        avatar: _selectedImage,
      );

      if (result['success'] == true) {
        // Update local storage
        await AuthService.updateUserName(_nameController.text);
        if (_selectedImage != null) {
          await AuthService.updateProfileImage(_selectedImage!.path);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        throw Exception(result['error'] ?? 'فشل في التحديث');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(widget.currentPhone);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Iconsax.arrow_square_left, color: AppColors.primary),
        ),
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 57,
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : NetworkImage(
                                widget.currentType == 'Phone'
                                    ? "https://globee.b-cdn.net/users/${widget.currentUid}/avatar.jpg?k=${DateTime.now().millisecondsSinceEpoch}"
                                    : widget.currentAvatar,
                              ),
                        backgroundColor: Colors.grey[300],
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Iconsax.camera,
                            color: AppColors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'الاسم',
                icon: Iconsax.user,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الاسم مطلوب';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                icon: Iconsax.call,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'رقم الهاتف مطلوب';
                  }
                  if (!AuthService.isValidQatarPhone(value)) {
                    return 'رقم هاتف غير صحيح (8 أرقام)';
                  }
                  return null;
                },
                suffixIcon: _phoneChanged
                    ? IconButton(
                        onPressed: _sendOtp,
                        icon: const Icon(Iconsax.sms, color: AppColors.primary),
                      )
                    : null,
              ),

              // OTP Field (if phone changed)
              if (_showOtpField) ...[
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _otpController,
                  label: 'رمز التحقق',
                  icon: Iconsax.security_safe,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'رمز التحقق مطلوب';
                    }
                    if (value.length != 6) {
                      return 'رمز التحقق يجب أن يكون 6 أرقام';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 8,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'حفظ التغييرات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.primary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.primary.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.primary.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
