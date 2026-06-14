import 'package:MartIt/core/services/onesignal_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/snackbar_helper.dart';
import '../../core/utils/theme_extensions.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uid = await AuthService.getCurrentUID();
      if (uid == null) {
        throw Exception('User not logged in');
      }

      final result = await ApiService.getCustomerOrders(uid: uid);

      if (result['success'] == true) {
        setState(() {
          _orders = result['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading customer orders: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openInvoice(String orderId, String visitorUid) async {
    // Seller view: pass user_id to filter by seller's uid
    final uid = await AuthService.getCurrentUID();
    final url =
        'https://www.Globee-Trading.com/app2026/invoice.php?order_id=$orderId&user_id=$uid&view=seller&k=${DateTime.now().millisecondsSinceEpoch}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      showAppSnackbar(context, message: 'فشل في فتح الفاتورة', type: SnackType.error);
    }
  }

  Future<void> _showStatusBottomSheet(dynamic order) async {
    final statuses = [
      {
        'value': 'Pending',
        'label': 'قيد الانتظار',
        'icon': Iconsax.clock,
        'desc': 'الطلب تم استلامه لكن لم يبدأ معالجته بعد.',
      },
      {
        'value': 'Preparing',
        'label': 'قيد التحضير',
        'icon': Iconsax.box,
        'desc': 'الطلب جاري تجهيزه، مثل تجميع المنتجات أو تجهيزها للشحن.',
      },
      {
        'value': 'ReadyToShip',
        'label': 'جاهز للشحن',
        'icon': Iconsax.box_tick,
        'desc': 'الطلب تم تحضيره بالكامل ومستعد للخروج من المخزن للشحن.',
      },
      {
        'value': 'Shipping',
        'label': 'قيد الشحن',
        'icon': Iconsax.truck_fast,
        'desc': 'الطلب في طريقه للعميل، تم تسليمه لشركة الشحن.',
      },
      {
        'value': 'Delivered',
        'label': 'تم التوصيل',
        'icon': Iconsax.tick_circle,
        'desc': 'الطلب وصل للعميل وتم استلامه بنجاح.',
      },
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
        color: context.appSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'تغيير حالة الطلب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ...statuses.map(
              (status) => _buildStatusOption(
                order,
                status['value'] as String,
                status['label'] as String,
                status['icon'] as IconData,
                status['desc'] as String,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    dynamic order,
    String statusValue,
    String statusLabel,
    IconData icon,
    String desc,
  ) {
    final isCurrentStatus = order['status'] == statusValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrentStatus
              ? null
              : () => _updateOrderStatus(order, statusValue, desc),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentStatus
                  ? AppColors.primary.withOpacity(0.1)
                  : context.appSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentStatus ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrentStatus
                        ? AppColors.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isCurrentStatus ? Colors.white : Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrentStatus
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isCurrentStatus
                          ? AppColors.primary
                          : context.appTextPrimary,
                    ),
                  ),
                ),
                if (isCurrentStatus)
                  const Icon(
                    Iconsax.tick_circle,
                    color: AppColors.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(
    dynamic order,
    String newStatus,
    String desc,
  ) async {
    Navigator.pop(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final result = await ApiService.updateOrderStatus(
        orderId: order['oid'].toString(),
        status: newStatus,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: 'تم تحديث حالة الطلب بنجاح',
          type: SnackType.success,
        );
        List<String> tokens = [];
        for (var i = 0; i < result['client_token'].length; i++) {
          tokens.add(result['client_token'][i]['player_id']);
        }
        OneSignalService.sendNotificationToMultipleUsers(
          playerIds: tokens,
          title: newStatus,
          message: desc,
        );
        _loadOrders();
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في تحديث الحالة',
          type: SnackType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      showAppSnackbar(context, message: 'حدث خطأ: $e', type: SnackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            'طلبات العملاء',
            style: TextStyle(
              color: context.appTextPrimary,
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
            : _hasError
            ? _buildErrorWidget()
            : _orders.isEmpty
            ? _buildEmptyWidget()
            : RefreshIndicator(
                onRefresh: _loadOrders,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(_orders[index]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل الطلبات',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Iconsax.people,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد طلبات',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لم يقم أي عميل بطلب منتجاتك حتى الآن',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final shippingInfo = order['shipping_info'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Iconsax.receipt_text,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رقم الطلب',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '#${order['oid']}',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showStatusBottomSheet(order),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(order['status']),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusText(order['status']),
                          style: TextStyle(
                            color: _getStatusColor(order['status']),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Iconsax.arrow_down_1,
                          color: _getStatusColor(order['status']),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Customer Info Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Iconsax.user,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'معلومات العميل',
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Iconsax.personalcard,
                    'الاسم',
                    order['customer_name'] ?? 'غير متوفر',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Iconsax.call,
                    'الهاتف',
                    order['customer_phone'] ?? 'غير متوفر',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Shipping Info Section
            if (shippingInfo != null && shippingInfo['fullname'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Iconsax.location,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'معلومات الشحن',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Iconsax.personalcard,
                      'الاسم',
                      shippingInfo['fullname'] ?? 'غير متوفر',
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Iconsax.call,
                      'الهاتف',
                      shippingInfo['mobile'] ?? 'غير متوفر',
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Iconsax.global,
                      'العنوان',
                      '${shippingInfo['city'] ?? ''}, ${shippingInfo['country'] ?? ''}',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Order Details
            _buildDetailRow(
              Iconsax.calendar,
              'تاريخ الطلب',
              _formatDate(order['created_at']),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Iconsax.money,
              'المبلغ الإجمالي',
              '${order['total_amount']} ريال',
            ),

            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInvoice(order['oid'].toString(), order['uid'].toString()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Iconsax.document_text, size: 20),
                label: const Text(
                  'عرض الفاتورة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: context.appTextSecondary,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'readytoship':
        return Colors.purple;
      case 'shipping':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'preparing':
        return 'قيد التحضير';
      case 'readytoship':
        return 'جاهز للشحن';
      case 'shipping':
        return 'قيد الشحن';
      case 'delivered':
        return 'تم التوصيل';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
