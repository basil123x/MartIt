import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../payment/payment_success_screen.dart';

class ShippingAddressScreen extends StatefulWidget {
  final String userId;
  final String uid;
  final List<CartItemModel> cartItems;
  final double totalAmount;

  const ShippingAddressScreen({
    super.key,
    required this.userId,
    required this.uid,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  static const Color _title = Color(0xFF1A1333);
  static const Color _brand = Color(0xFF5C33EA);
  static const Color _iconAccent = Color(0xFF8B7AF0);
  static const Color _surfaceSoft = Color(0xFFF5F3FF);
  static const Color _iconBadge = Color(0xFFEAE5FC);
  static const Color _border = Color(0xFFE0DBF5);
  static const Color _dashedBorder = Color(0xFFC9BFF5);
  static const Color _destructive = Color(0xFFE5484D);

  List<ShippingAddressModel> _addresses = [];
  bool _isLoading = true;
  bool _isLocating = false;
  bool _isSaving = false;
  bool _showAddForm = false;
  int? _selectedAddressIndex;
  int? _editingAddressId;

  final _fullnameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _zoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool get _isAr => LocalizationService.instance.currentLanguage == 'ar';
  bool get _isEditing => _editingAddressId != null;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
    _loadAddresses();
  }

  Future<void> _prefillUserData() async {
    const storage = FlutterSecureStorage();

    final name = await AuthService.getCurrentName() ?? '';
    final phone = await AuthService.getCurrentPhone() ?? '';
    final email =
        await storage.read(key: 'user_email') ??
        await storage.read(key: 'social_email') ??
        '';

    if (!mounted) return;

    setState(() {
      if (name.isNotEmpty) _fullnameController.text = name;
      if (phone.isNotEmpty) _mobileController.text = phone;
      if (email.isNotEmpty) _emailController.text = email;
      if (_countryController.text.isEmpty) _countryController.text = 'Qatar';
    });
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _zoneController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getShippingAddresses(uid: widget.uid);

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _addresses = data
              .map((item) => ShippingAddressModel.fromJson(item))
              .toList();
          _isLoading = false;
          if (_addresses.isNotEmpty) {
            _selectedAddressIndex = _selectedAddressIndex != null &&
                    _selectedAddressIndex! < _addresses.length
                ? _selectedAddressIndex
                : 0;
            _showAddForm = false;
            _editingAddressId = null;
          } else {
            _selectedAddressIndex = null;
            _showAddForm = true;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          if (_addresses.isEmpty) _showAddForm = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (_addresses.isEmpty) _showAddForm = true;
      });
    }
  }

  Future<void> _getLocationAndFill() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          showAppSnackbar(
            context,
            message: 'يجب السماح بالوصول للموقع',
            type: SnackType.warning,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        showAppSnackbar(
          context,
          message: 'يجب السماح بالوصول للموقع من الإعدادات',
          type: SnackType.warning,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final url =
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=${position.latitude}'
          '&lon=${position.longitude}'
          '&format=json'
          '&accept-language=ar';

      final response = await Dio().get(
        url,
        options: Options(headers: {'User-Agent': 'MartItApp/1.0'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final address = data['address'] ?? {};

        if (!mounted) return;
        setState(() {
          final city =
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              '';
          if (city.isNotEmpty) _cityController.text = city.toString();

          final country = address['country'] ?? 'Qatar';
          _countryController.text = country.toString();

          final zone =
              address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['district'] ??
              '';
          if (zone.isNotEmpty) _zoneController.text = zone.toString();

          final street = address['road'] ?? address['street'] ?? '';
          if (street.isNotEmpty) _streetController.text = street.toString();

          final building = address['house_number'] ?? '';
          if (building.isNotEmpty) {
            _buildingController.text = building.toString();
          }
        });

        if (!mounted) return;
        showAppSnackbar(
          context,
          message: 'تم تحديد موقعك بنجاح ✓',
          type: SnackType.success,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'تعذر تحديد الموقع، أدخل العنوان يدوياً',
        type: SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  bool _validateForm() {
    final required = [
      (_fullnameController, 'الاسم الكامل'),
      (_mobileController, 'رقم الهاتف'),
      (_countryController, 'الدولة'),
      (_cityController, 'المدينة'),
      (_zoneController, 'رقم المنطقة'),
      (_streetController, 'رقم الشارع'),
      (_buildingController, 'رقم المبنى'),
    ];

    for (final (controller, name) in required) {
      if (controller.text.trim().isEmpty) {
        showAppSnackbar(
          context,
          message: '$name مطلوب',
          type: SnackType.warning,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _saveAddress() async {
    if (!_validateForm()) return;
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> result;
      if (_isEditing) {
        result = await ApiService.updateShippingAddress(
          addressId: _editingAddressId!,
          fullname: _fullnameController.text,
          mobile: _mobileController.text,
          email: _emailController.text,
          country: _countryController.text,
          city: _cityController.text,
          zoneNumber: _zoneController.text,
          streetNumber: _streetController.text,
          buildingNumber: _buildingController.text,
          uid: widget.uid,
        );
      } else {
        final oid = await AuthService.getCurrentOID();
        result = await ApiService.addShippingAddress(
          fullname: _fullnameController.text,
          mobile: _mobileController.text,
          email: _emailController.text,
          country: _countryController.text,
          city: _cityController.text,
          zoneNumber: _zoneController.text,
          streetNumber: _streetController.text,
          buildingNumber: _buildingController.text,
          uid: widget.uid,
          oid: oid ?? '',
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: _isEditing
              ? 'تم تحديث العنوان بنجاح'
              : 'تم إضافة العنوان بنجاح',
          type: SnackType.success,
        );
        _clearForm();
        setState(() {
          _showAddForm = false;
          _editingAddressId = null;
        });
        await _loadAddresses();
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في حفظ العنوان',
          type: SnackType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء حفظ العنوان',
        type: SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _fullnameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _countryController.clear();
    _cityController.clear();
    _zoneController.clear();
    _streetController.clear();
    _buildingController.clear();
    _prefillUserData();
  }

  void _startAddAddress() {
    _clearForm();
    setState(() {
      _editingAddressId = null;
      _showAddForm = true;
    });
  }

  void _startEditAddress(ShippingAddressModel address) {
    setState(() {
      _editingAddressId = address.id;
      _showAddForm = true;
      _fullnameController.text = address.fullname;
      _mobileController.text = address.mobile;
      _emailController.text = address.email;
      _countryController.text = address.country;
      _cityController.text = address.city;
      _zoneController.text = address.zoneNumber;
      _streetController.text = address.streetNumber;
      _buildingController.text = address.buildingNumber;
    });
  }

  void _confirmDeleteAddress(ShippingAddressModel address, int index) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: _isAr ? 'حذف العنوان؟' : 'Delete address?',
      desc: _isAr
          ? 'سيتم حذف هذا العنوان من عناوينك المحفوظة'
          : 'This address will be removed from your saved addresses',
      btnCancelText: _isAr ? 'إلغاء' : 'Cancel',
      btnOkText: _isAr ? 'حذف' : 'Delete',
      btnOkColor: _destructive,
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        _deleteAddress(address, index);
      },
    ).show();
  }

  Future<void> _deleteAddress(ShippingAddressModel address, int index) async {
    try {
      final result = await ApiService.deleteShippingAddress(
        addressId: address.id,
        uid: widget.uid,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: _isAr ? 'تم حذف العنوان' : 'Address deleted',
          type: SnackType.success,
        );
        await _loadAddresses();
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ??
              (_isAr ? 'فشل في حذف العنوان' : 'Failed to delete address'),
          type: SnackType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: _isAr ? 'حدث خطأ أثناء الحذف' : 'Error deleting address',
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final titleColor = isDark ? Colors.white : _title;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: titleColor,
            ),
          ),
          title: Text(
            isAr ? 'عناوين الشحن' : 'Shipping Addresses',
            style: TextStyle(
              color: titleColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _brand))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_showAddForm) _buildAddressForm(isDark: isDark),
                          if (!_showAddForm) ...[
                            if (_addresses.isNotEmpty) ...[
                              _buildSectionHeader(isDark: isDark),
                              const SizedBox(height: 14),
                              ..._addresses.asMap().entries.map((entry) {
                                return _buildAddressCard(
                                  entry.value,
                                  entry.key,
                                  isDark: isDark,
                                );
                              }),
                              if (_addresses.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    bottom: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Iconsax.info_circle,
                                        size: 14,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : const Color(0xFF6B6B80),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isAr
                                              ? 'اضغط على عنوان لتغيير الاختيار'
                                              : 'Tap an address to change selection',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : const Color(0xFF6B6B80),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                            _buildDashedAddButton(isDark: isDark),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!_showAddForm) _buildContinueButton(isDark: isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : _surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? _brand.withValues(alpha: 0.2) : _iconBadge,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Iconsax.location, color: _brand, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            _isAr ? 'العناوين المحفوظة' : 'Saved addresses',
            style: TextStyle(
              color: isDark ? Colors.white : _title,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedAddButton({required bool isDark}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _startAddAddress,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: isDark ? _brand.withValues(alpha: 0.45) : _dashedBorder,
            radius: 14,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.add,
                  color: _brand,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAr ? 'إضافة عنوان جديد' : 'Add new address',
                  style: const TextStyle(
                    color: _brand,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
    ShippingAddressModel address,
    int index, {
    required bool isDark,
  }) {
    final isSelected = _selectedAddressIndex == index;
    final cardBg = isSelected
        ? (isDark ? _brand.withValues(alpha: 0.14) : _surfaceSoft)
        : (isDark ? AppColors.darkSurface : Colors.white);
    final borderColor = isSelected
        ? _brand
        : (isDark ? AppColors.darkBorder : _border);

    return GestureDetector(
      onTap: () => setState(() => _selectedAddressIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    address.fullname,
                    style: TextStyle(
                      color: isDark ? Colors.white : _title,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (isSelected)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: _brand,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _border, width: 1.5),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildInfoRow(Iconsax.call, address.mobile),
            const SizedBox(height: 12),
            _buildInfoRow(
              Iconsax.location,
              [
                if (address.city.isNotEmpty) address.city,
                if (address.country.isNotEmpty) address.country,
              ].join(', '),
            ),
            if (address.streetNumber.isNotEmpty ||
                address.buildingNumber.isNotEmpty ||
                address.zoneNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Iconsax.building,
                [
                  if (address.streetNumber.isNotEmpty)
                    'شارع ${address.streetNumber}',
                  if (address.buildingNumber.isNotEmpty)
                    'مبنى ${address.buildingNumber}',
                  if (address.zoneNumber.isNotEmpty)
                    'منطقة ${address.zoneNumber}',
                ].join(' · '),
              ),
            ],
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFEDEAF7),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _startEditAddress(address),
                  style: TextButton.styleFrom(
                    foregroundColor: _brand,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isAr ? 'تعديل' : 'Edit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _confirmDeleteAddress(address, index),
                  style: TextButton.styleFrom(
                    foregroundColor: _destructive,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isAr ? 'حذف' : 'Delete',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _iconAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF6B6B80),
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressForm({required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : _border,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing
                        ? (_isAr ? 'تعديل العنوان' : 'Edit address')
                        : (_isAr ? 'إضافة عنوان جديد' : 'Add new address'),
                    style: TextStyle(
                      color: isDark ? Colors.white : _title,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_addresses.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showAddForm = false;
                        _editingAddressId = null;
                        _clearForm();
                      });
                    },
                    icon: const Icon(Iconsax.close_circle, color: _destructive),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _isLocating ? null : _getLocationAndFill,
              icon: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _isLocating
                    ? (_isAr ? 'جاري تحديد الموقع...' : 'Locating...')
                    : (_isAr ? 'استخدم موقعي الحالي' : 'Use my current location'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _buildTextField(
              'الاسم الكامل',
              _fullnameController,
              Iconsax.user,
              true,
              isDark: isDark,
            ),
            _buildTextField(
              'رقم الهاتف',
              _mobileController,
              Iconsax.call,
              true,
              isDark: isDark,
            ),
            _buildTextField(
              'البريد الإلكتروني',
              _emailController,
              Iconsax.sms,
              false,
              isDark: isDark,
            ),
            _buildTextField(
              'الدولة',
              _countryController,
              Iconsax.global,
              true,
              isDark: isDark,
            ),
            _buildTextField(
              'المدينة',
              _cityController,
              Iconsax.location,
              true,
              isDark: isDark,
            ),
            _buildTextField(
              'رقم المنطقة',
              _zoneController,
              Iconsax.map,
              true,
              isDark: isDark,
            ),
            _buildTextField(
              'رقم الشارع',
              _streetController,
              Iconsax.routing,
              true,
              isDark: isDark,
            ),
            _buildTextField(
              'رقم المبنى',
              _buildingController,
              Iconsax.building,
              true,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_addresses.isNotEmpty) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showAddForm = false;
                          _editingAddressId = null;
                          _clearForm();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B6B80),
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : _border,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_isAr ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isEditing
                                ? (_isAr ? 'حفظ التعديلات' : 'Save changes')
                                : (_isAr ? 'حفظ العنوان' : 'Save address'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool required, {
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : _title),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF6B6B80),
          ),
          prefixIcon: Icon(icon, color: _brand, size: 20),
          filled: true,
          fillColor: isDark ? AppColors.darkElevated : _surfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : _border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : _border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brand, width: 1.5),
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildContinueButton({required bool isDark}) {
    final hasSelection = _selectedAddressIndex != null &&
        _selectedAddressIndex! < _addresses.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFEDEAF7),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSelection
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentSuccessScreen(
                          userId: widget.userId,
                          cartItems: widget.cartItems,
                          totalAmount: widget.totalAmount,
                          shippingAddress:
                              _addresses[_selectedAddressIndex!],
                        ),
                      ),
                    );
                  }
                : () {
                    showAppSnackbar(
                      context,
                      message: 'اختر أو أضف عنوان شحن أولاً',
                      type: SnackType.warning,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSelection ? _brand : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: hasSelection ? 4 : 0,
              shadowColor: _brand.withValues(alpha: 0.28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isAr ? 'إكمال الدفع' : 'Complete payment',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Iconsax.card, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
