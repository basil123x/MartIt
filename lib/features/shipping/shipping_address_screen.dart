import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../payment/payment_methods_screen.dart';

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
  List<ShippingAddressModel> _addresses = [];
  bool _isLoading = true;
  bool _showAddForm = false;
  int? _selectedAddressIndex;

  // Form controllers
  final _fullnameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _zoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
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
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getShippingAddresses(uid: widget.uid);

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _addresses = data
              .map((item) => ShippingAddressModel.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addAddress() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final oid = await AuthService.getCurrentOID();

      final result = await ApiService.addShippingAddress(
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

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة العنوان بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        _clearForm();
        setState(() {
          _showAddForm = false;
        });
        _loadAddresses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'فشل في إضافة العنوان'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء إضافة العنوان'),
          backgroundColor: Colors.red,
        ),
      );
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
          title: const Text(
            'عناوين الشحن',
            style: TextStyle(
              // color: Colors.white,
              color: Color(0xFF1A1A2E),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Add New Address Button
                          if (!_showAddForm)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showAddForm = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Iconsax.add_circle),
                                label: const Text(
                                  'إضافة عنوان جديد',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // Add Address Form
                          if (_showAddForm) _buildAddressForm(),

                          // Existing Addresses
                          if (_addresses.isNotEmpty && !_showAddForm) ...[
                            const Text(
                              'العناوين المحفوظة:',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._addresses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final address = entry.value;
                              return _buildAddressCard(address, index);
                            }),
                          ],

                          // Empty State
                          if (_addresses.isEmpty && !_showAddForm)
                            _buildEmptyState(),
                        ],
                      ),
                    ),
                  ),

                  // Continue Button
                  if (_selectedAddressIndex != null && !_showAddForm)
                    _buildContinueButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildAddressForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // const Color(0xFF1A1A2E).withOpacity(0.8),
            // const Color(0xFF16213E).withOpacity(0.6),
            Color(0xFFD4D4F0),
            Color(0xFFC8D4F5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إضافة عنوان جديد',
                  style: TextStyle(
                    // color: Colors.white,
                    color: Color(0xFF1A1A2E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showAddForm = false;
                      _clearForm();
                    });
                  },
                  icon: const Icon(Iconsax.close_circle, color: Colors.red),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildTextField(
              'الاسم الكامل',
              _fullnameController,
              Iconsax.user,
              true,
            ),
            _buildTextField(
              'رقم الهاتف',
              _mobileController,
              Iconsax.call,
              true,
            ),
            _buildTextField(
              'البريد الإلكتروني',
              _emailController,
              Iconsax.sms,
              false,
            ),
            _buildTextField('الدولة', _countryController, Iconsax.global, true),
            _buildTextField('المدينة', _cityController, Iconsax.location, true),
            _buildTextField('رقم المنطقة', _zoneController, Iconsax.map, false),
            _buildTextField(
              'رقم الشارع',
              _streetController,
              Iconsax.routing,
              false,
            ),
            _buildTextField(
              'رقم المبنى',
              _buildingController,
              Iconsax.building,
              false,
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showAddForm = false;
                        _clearForm();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('حفظ العنوان'),
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
    bool required,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        // style: const TextStyle(color: Colors.white),
        style: const TextStyle(color: Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          labelText: label,
          // labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          labelStyle: TextStyle(
            color: const Color(0xFF1A1A2E).withOpacity(0.7),
          ),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          // fillColor: Colors.white.withOpacity(0.1),
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
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

  Widget _buildAddressCard(ShippingAddressModel address, int index) {
    final isSelected = _selectedAddressIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddressIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.primary.withOpacity(0.3),
                    AppColors.primary.withOpacity(0.1),
                  ]
                : [
                    // const Color(0xFF1A1A2E).withOpacity(0.6),
                    // const Color(0xFF16213E).withOpacity(0.4),
                    const Color(0xFFD4D4F0),
                    const Color(0xFFC8D4F5),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                isSelected
                    ? Container(
                        padding: EdgeInsets.only(right: 10, left: 0),
                        child: Icon(
                          Iconsax.tick_circle5,
                          color: isSelected
                              ? AppColors.primary
                              : Color(0xFF1A1A2E),
                          size: 20,
                        ),
                      )
                    : Icon(
                        Iconsax.location,
                        color: isSelected
                            ? AppColors.primary
                            : Color(0xFF1A1A2E),
                        size: 20,
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.fullname,
                    style: TextStyle(
                      // color: Colors.white,
                      color: const Color(0xFF1A1A2E),
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'محدد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            _buildAddressDetail(Iconsax.call, address.mobile),
            if (address.email.isNotEmpty)
              _buildAddressDetail(Iconsax.sms, address.email),
            _buildAddressDetail(
              Iconsax.global,
              '${address.city}, ${address.country}',
            ),
            if (address.streetNumber.isNotEmpty ||
                address.buildingNumber.isNotEmpty)
              _buildAddressDetail(
                Iconsax.location,
                '${address.streetNumber.isNotEmpty ? "شارع ${address.streetNumber}" : ""}'
                '${address.buildingNumber.isNotEmpty ? " - مبنى ${address.buildingNumber}" : ""}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDetail(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
          Icon(icon, color: const Color(0xFF1A1A2E).withOpacity(0.6), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                // color: Colors.white.withOpacity(0.8),
                color: const Color(0xFF1A1A2E).withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.width,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Iconsax.location_add,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد عناوين محفوظة',
              style: TextStyle(
                // color: Colors.white,
                color: Color(0xFF1A1A2E),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'أضف عنوان شحن لإكمال طلبك',
              style: TextStyle(
                // color: Colors.white.withOpacity(0.7),
                color: const Color(0xFF1A1A2E).withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to payment methods screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentMethodsScreen(
                    userId: widget.userId,
                    cartItems: widget.cartItems,
                    totalAmount: widget.totalAmount,
                    shippingAddress: _addresses[_selectedAddressIndex!],
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'إكمال الدفع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Iconsax.card, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
