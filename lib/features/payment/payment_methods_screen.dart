import 'package:GES/core/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sadad_qa_payments/sadad_qa_payments.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import 'order_success_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;
  final ShippingAddressModel shippingAddress;

  const PaymentMethodsScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
    required this.shippingAddress,
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int? _selectedPaymentMethod;
  String name = "";
  String mobile = "";

  Future loadProfile() async {
    String? uid =await AuthService.getCurrentUID();
    var result = await Dio().post("https://www.globee-trading.com/app2026/profile.php?user_id=$uid&k=${DateTime.now().millisecondsSinceEpoch}");
    setState(() {
      name = result.data['data']['name'];
      mobile = result.data['data']['phone'];
    });
  }

  @override 
  void initState() {
    loadProfile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.arrow_right, color: Color(0xFF1A1A2E)),
          ),
          title: const Text(
            'طريقة الدفع',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Sadad Payment Option
              _buildPaymentOptionCard(
                index: 0,
                icon: Iconsax.card,
                title: 'الدفع الإلكتروني',
                subtitle: 'الدفع عبر سداد',
                isEnabled: true,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 0;
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Cash on Delivery Option
              _buildPaymentOptionCard(
                index: 1,
                icon: Iconsax.money,
                title: 'الدفع عند الاستلام',
                subtitle: 'ادفع عند استلام طلبك',
                isEnabled: true,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 1;
                  });
                },
              ),
              
              const Spacer(),
              
                _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedPaymentMethod == index;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0.05),
                  ]
                : [
                    const Color(0xFFD4D4F0),
                    const Color(0xFFC8D4F5),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon on the right (RTL)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isEnabled
                    ? (isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1))
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isEnabled
                    ? (isSelected ? Colors.white : AppColors.primary)
                    : Colors.grey,
                size: 28,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isEnabled
                          ? const Color(0xFF1A1A2E)
                          : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isEnabled
                          ? const Color(0xFF1A1A2E).withOpacity(0.6)
                          : Colors.grey.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio indicator or arrow on the left (RTL)
            if (isEnabled)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.4),
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              )
            else
              Icon(
                Iconsax.arrow_left_2,
                color: Colors.grey.withOpacity(0.4),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
             
              if (_selectedPaymentMethod == 0) {
                String? oid =await AuthService.getCurrentOID();
                String transOid = "";
                String transId = "";
                String transStatus = "";
                String transAmount = "";
                String transPaymentMode = "";
                 // TODO: قبل الـ production - انقل الـ secret key للسيرفر
                var result = await Dio().post("https://api.sadadqatar.com/api-v5/userbusinesses/getsdktoken", data: {
                  "sadadId": "9818636",
                  "secretKey": "CfGxIE+7LZlWLVJg",
                  "domain": "www.ges.qa",
                  "isTest": true
                });
                
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                        return PaymentScreen(
                            orderId: oid ?? "",
                            productDetail: [],
                            customerName: name,
                            amount: widget.totalAmount,
                            email: "info@ges.qa",
                            mobile: mobile,
                            token: result.data['accessToken'],
                            packageMode: PackageMode.debug,
                            isWalletEnabled: true,
                            paymentTypes: [PaymentType.creditCard, PaymentType.debitCard, PaymentType.sadadPay],
                            image: Image.asset("assets/images/Logo-Sadad.png"),
                            titleText: "Golden Eagle Stores",
                            paymentButtonColor: AppColors.accent,
                            paymentButtonTextColor: Colors.white,
                            themeColor: AppColors.primary,
                            googleMerchantID: 'BCR2DN6TR6Y7Z2CJ',
                            googleMerchantName: 'Sadad Payment Solutions');
                    },
                )).then((value) async {
                  setState(() {
                    transOid = value['orderid'].toString();
                    transId = value['transaction_id'].toString();
                    transStatus = value['status'].toString();
                    transAmount = value['amount'].toString();
                    transPaymentMode = value['payment_mode'].toString();
                  });
                  await Dio().post("https://www.globee-trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}", data: FormData.fromMap({
                    "action": "add_new_transactions",
                    "oid": transOid,
                    "name": name,
                    "mobile": mobile,
                    "trans_id": transId,
                    "status": transStatus,
                    "amount": transAmount,
                    "pay_mode": transPaymentMode,
                    "store_id": "3"
                  }));
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderSuccessScreen(
                        userId: widget.userId,
                        cartItems: widget.cartItems,
                        totalAmount: widget.totalAmount,
                        shippingAddress: widget.shippingAddress,
                        transStatus: transStatus
                      ),
                    ),
                  );
                });
                
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderSuccessScreen(
                      userId: widget.userId,
                      cartItems: widget.cartItems,
                      totalAmount: widget.totalAmount,
                      shippingAddress: widget.shippingAddress,
                      transStatus: "3"
                    ),
                  ),
                );
              }
              
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
              children: const [
                Text(
                  'تأكيد الطلب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Iconsax.tick_circle, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
