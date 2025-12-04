// import 'dart:io';
// import 'dart:isolate';
// import 'package:Globee/core/services/onesignal_service.dart';
// import 'package:Globee/core/services/onesignal_service_web.dart';
// import 'package:Globee/core/services/upload_notification_service.dart';
// import 'package:Globee/features/home/tiktok_feed_screen.dart';
// import 'package:Globee/shared/providers/app_provider.dart';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:iconsax/iconsax.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
// import '../../core/constants/app_colors.dart';
// import '../../core/constants/app_strings.dart';
// import '../../core/widgets/video_player_widget.dart';
// import '../../core/services/auth_service.dart';
// import '../../core/services/database_service.dart';
// import '../../core/services/bunny_upload_service.dart';
// import '../camera/camera_screen.dart';

// class AddProductScreen extends StatefulWidget {
//   final List<String> mediaFiles;
//   final String? itemId;

//   const AddProductScreen({super.key, required this.mediaFiles, this.itemId});

//   @override
//   State<AddProductScreen> createState() => _AddProductScreenState();
// }

// class _AddProductScreenState extends State<AddProductScreen> {
//   final PageController _mediaController = PageController();
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   final TextEditingController _quantityController = TextEditingController();
//   final TextEditingController _categoryController = TextEditingController();

//   List<String> _mediaFiles = [];
//   int _currentMediaIndex = 0;
//   bool _isPublic = true;
//   bool _commentsEnabled = true;
//   bool _isUploading = false;
//   String? _currentItemId;

//   Future insertOneRecord() async {
//     var request = await Dio().post(
//       'https://Globee-Trading.com/app2026/sql.php',
//       data: FormData.fromMap({'action': 'insertNewOne'}),
//     );
//     setState(() {
//       _currentItemId = request.data['item_id'].toString();
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     _mediaFiles = List.from(widget.mediaFiles);
//     insertOneRecord();
//   }

//   @override
//   void dispose() {
//     _mediaController.dispose();
//     _nameController.dispose();
//     _descriptionController.dispose();
//     _priceController.dispose();
//     _quantityController.dispose();
//     _categoryController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     print(_currentItemId);
//     _isUploading = false;
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: Container(),
//         actions: [
//           IconButton(
//             onPressed: () => Navigator.pop(context),
//             icon: const Icon(Iconsax.arrow_right, color: Colors.black),
//           ),
//         ],
//         title: const Text(
//           'إضافة منتج جديد',
//           style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             // Media Preview
//             _buildMediaPreview(),

//             const SizedBox(height: 24),

//             // Product Name
//             _buildTextField(
//               controller: _nameController,
//               label: 'اسم المنتج',
//               hint: 'أدخل اسم المنتج',
//               icon: Iconsax.box,
//             ),

//             const SizedBox(height: 16),

//             // Description
//             _buildTextField(
//               controller: _descriptionController,
//               label: 'الوصف',
//               hint: 'أدخل وصف المنتج',
//               icon: Iconsax.document_text,
//               maxLines: 3,
//             ),

//             const SizedBox(height: 16),

//             // Category
//             _buildTextField(
//               controller: _categoryController,
//               label: 'التصنيف',
//               hint: 'أدخل تصنيف المنتج',
//               icon: Iconsax.category,
//             ),

//             const SizedBox(height: 16),

//             // Price and Quantity Row
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildTextField(
//                     controller: _priceController,
//                     label: 'السعر',
//                     hint: '0.00',
//                     icon: Iconsax.money,
//                     keyboardType: TextInputType.number,
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: _buildTextField(
//                     controller: _quantityController,
//                     label: 'الكمية',
//                     hint: '1',
//                     icon: Iconsax.box_1,
//                     keyboardType: TextInputType.number,
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 24),

//             // Privacy Settings
//             _buildSectionTitle('إعدادات الخصوصية'),
//             const SizedBox(height: 12),

//             _buildSwitchTile(
//               title: 'منتج عام',
//               subtitle: 'يمكن لجميع المستخدمين رؤية هذا المنتج',
//               value: _isPublic,
//               onChanged: (value) => setState(() => _isPublic = value),
//               icon: _isPublic ? Iconsax.global : Iconsax.lock,
//             ),

//             const SizedBox(height: 12),

//             _buildSwitchTile(
//               title: 'تفعيل التعليقات',
//               subtitle: 'السماح للمستخدمين بالتعليق على المنتج',
//               value: _commentsEnabled,
//               onChanged: (value) => setState(() => _commentsEnabled = value),
//               icon: _commentsEnabled ? Iconsax.message : Iconsax.message_minus,
//             ),

//             const SizedBox(height: 32),

//             // Submit Button
//             SizedBox(
//               width: double.infinity,
//               height: 56,
//               child: ElevatedButton(
//                 onPressed: _isUploading ? null : _submitProduct,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.primary,
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   elevation: 0,
//                 ),
//                 child: _isUploading
//                     ? const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                               color: Colors.white,
//                               strokeWidth: 2,
//                             ),
//                           ),
//                           SizedBox(width: 12),
//                           Text('جاري الرفع...'),
//                         ],
//                       )
//                     : const Text(
//                         'نشر المنتج',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMediaPreview() {
//     return Consumer<AppProvider>(
//       builder: (context, appProvider, child) {
//         return Container(
//           height: 300,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(16),
//             color: Colors.grey[100],
//           ),
//           child: Stack(
//             children: [
//               PageView.builder(
//                 controller: _mediaController,
//                 onPageChanged: (index) {
//                   setState(() {
//                     _currentMediaIndex = index;
//                   });
//                 },
//                 itemCount: appProvider.allMedia.length,
//                 itemBuilder: (context, index) {
//                   final file = File(appProvider.allMedia[index]);
//                   final isVideo = appProvider.allMedia[index]
//                       .toLowerCase()
//                       .contains('.mp4');

//                   return ClipRRect(
//                     borderRadius: BorderRadius.circular(16),
//                     child: isVideo
//                         ? VideoPlayerWidget(
//                             filePath: appProvider.allMedia[index],
//                             autoPlay: false,
//                             showControls: true,
//                           )
//                         : Image.file(file, fit: BoxFit.cover),
//                   );
//                 },
//               ),

//               // Add more media button
//               Positioned(
//                 top: 16,
//                 right: 16,
//                 child: FloatingActionButton(
//                   mini: true,
//                   backgroundColor: AppColors.primary,
//                   onPressed: _showAddMoreMediaBottomSheet,
//                   child: const Icon(Iconsax.add, color: Colors.white, size: 20),
//                 ),
//               ),

//               // Media indicators
//               if (appProvider.allMedia.length > 1)
//                 Positioned(
//                   bottom: 16,
//                   left: 0,
//                   right: 0,
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: List.generate(
//                       appProvider.allMedia.length,
//                       (index) => Container(
//                         margin: const EdgeInsets.symmetric(horizontal: 4),
//                         width: 8,
//                         height: 8,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: _currentMediaIndex == index
//                               ? AppColors.primary
//                               : Colors.white.withOpacity(0.5),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     required IconData icon,
//     int maxLines = 1,
//     TextInputType? keyboardType,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 8),
//         TextField(
//           controller: controller,
//           maxLines: maxLines,
//           keyboardType: keyboardType,
//           textAlign: TextAlign.end,
//           decoration: InputDecoration(
//             hintText: hint,
//             suffixIcon: Icon(icon, color: AppColors.primary),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide(color: Colors.grey[300]!),
//             ),
//             enabledBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: BorderSide(color: Colors.grey[300]!),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12),
//               borderSide: const BorderSide(color: AppColors.primary),
//             ),
//             filled: true,
//             fillColor: Colors.grey[50],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSectionTitle(String title) {
//     return Text(
//       title,
//       style: const TextStyle(
//         fontSize: 18,
//         fontWeight: FontWeight.bold,
//         color: Colors.black87,
//       ),
//     );
//   }

//   Widget _buildSwitchTile({
//     required String title,
//     required String subtitle,
//     required bool value,
//     required ValueChanged<bool> onChanged,
//     required IconData icon,
//   }) {
//     return Directionality(
//       textDirection: TextDirection.rtl,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: Colors.grey[300]!),
//           color: Colors.grey[50],
//         ),
//         child: Row(
//           children: [
//             Icon(icon, color: AppColors.primary, size: 24),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   Text(
//                     subtitle,
//                     style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//                   ),
//                 ],
//               ),
//             ),
//             Switch(
//               value: value,
//               onChanged: onChanged,
//               activeColor: AppColors.primary,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showAddMoreMediaBottomSheet() {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               width: 50,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text('إضافة وسائط', style: Theme.of(context).textTheme.titleLarge),
//             const SizedBox(height: 20),
//             ListTile(
//               leading: const Icon(Iconsax.camera, color: AppColors.primary),
//               title: const Text('التقاط صورة'),
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const CameraScreen(isVideo: false),
//                   ),
//                 );
//               },
//             ),
//             ListTile(
//               leading: const Icon(
//                 Iconsax.video_circle,
//                 color: AppColors.secondary,
//               ),
//               title: const Text('تسجيل فيديو'),
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const CameraScreen(isVideo: true),
//                   ),
//                 );
//               },
//             ),
//             ListTile(
//               leading: const Icon(Iconsax.gallery, color: Colors.green),
//               title: const Text('اختيار من المعرض'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _pickFromGallery();
//               },
//             ),
//             const SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }

//   void _pickFromGallery() async {
//     final ImagePicker picker = ImagePicker();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('اختيار نوع الوسائط'),
//         content: Consumer<AppProvider>(
//           builder: (context, appProvider, child) {
//             return Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 ListTile(
//                   leading: const Icon(Iconsax.image),
//                   title: const Text('صور'),
//                   onTap: () async {
//                     Navigator.pop(context);
//                     final List<XFile> images = await picker.pickMultiImage();
//                     if (images.isNotEmpty) {
//                       setState(() {
//                         appProvider.allMedia.addAll(
//                           images.map((image) => image.path),
//                         );
//                       });
//                     }
//                   },
//                 ),
//                 ListTile(
//                   leading: const Icon(Iconsax.video_play),
//                   title: const Text('فيديو'),
//                   onTap: () async {
//                     Navigator.pop(context);
//                     final XFile? video = await picker.pickVideo(
//                       source: ImageSource.gallery,
//                     );
//                     if (video != null) {
//                       setState(() {
//                         appProvider.allMedia.add(video.path);
//                       });
//                     }
//                   },
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }

//   void _submitProduct() async {
//     // Validate fields
//     if (_nameController.text.trim().isEmpty) {
//       _showError('يرجى إدخال اسم المنتج');
//       return;
//     }

//     if (_descriptionController.text.trim().isEmpty) {
//       _showError('يرجى إدخال وصف المنتج');
//       return;
//     }

//     if (_priceController.text.trim().isEmpty) {
//       _showError('يرجى إدخال سعر المنتج');
//       return;
//     }

//     if (_quantityController.text.trim().isEmpty) {
//       _showError('يرجى إدخال كمية المنتج');
//       return;
//     }

//     if (_categoryController.text.trim().isEmpty) {
//       _showError('يرجى إدخال تصنيف المنتج');
//       return;
//     }

//     // if (_currentItemId == null) {
//     //   _showError('خطأ في إنشاء المنتج');
//     //   return;
//     // }

//     setState(() {
//       _isUploading = true;
//     });

//     final appProvider = Provider.of<AppProvider>(context, listen: false);
//     String? uid = await FlutterSecureStorage().read(key: "user_uid");
//     String? userName = await AuthService.getCurrentName();
//     // Prepare data for background upload
//     Map<String, dynamic> data = {
//       'itemId': _currentItemId,
//       'uid': uid,
//       'userName': userName,
//       'name': _nameController.text.trim(),
//       'description': _descriptionController.text.trim(),
//       'price': _priceController.text.trim(),
//       'quantity': _quantityController.text.trim(),
//       'category': _categoryController.text.trim(),
//       'visibility': _isPublic ? 'public' : 'private',
//       'comments': _commentsEnabled ? 'on' : 'off',
//       'mediaFiles': appProvider.allMedia,
//       'timestamp': DateTime.now().millisecondsSinceEpoch,
//     };

//     // Start background upload
//     _startBackgroundUpload(data);

//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => TikTokFeedScreen()),
//     );
//     // Show success message
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('تم بدء رفع المنتج في الخلفية'),
//         backgroundColor: Colors.green,
//       ),
//     );
//   }

//   void _startBackgroundUpload(Map<String, dynamic> data) async {
//     try {
//       final appProvider = Provider.of<AppProvider>(context, listen: false);
//       final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

//       // Initialize notification service
//       await UploadNotificationService.initialize();

//       // Show initial notification
//       await UploadNotificationService.showUploadProgress(
//         id: notificationId,
//         title: 'جاري رفع المنتج',
//         body: 'جاري تحضير الملفات...',
//         progress: 0,
//         maxProgress: 100,
//       );

//       // Start background upload without isolate
//       _runBackgroundUploadWithNotification(data, notificationId);
//       appProvider.allMedia.clear();
//     } catch (e) {
//       print('Error starting background upload: $e');
//     }
//   }

//   void _runBackgroundUploadWithNotification(
//     Map<String, dynamic> data,
//     int notificationId,
//   ) async {
//     try {
//       print("🚀 Starting product upload: ${data['name']}");

//       final itemId = data['itemId'];
//       final mediaFiles = List<String>.from(data['mediaFiles']);

//       // Step 1: Upload media files to Bunny.net
//       print("📤 Uploading ${mediaFiles.length} media files...");

//       final uploadedUrls = await BunnyUploadService.uploadMediaFiles(
//         filePaths: mediaFiles,
//         itemId: itemId,
//         onProgress: (current, total, progress) async {
//           final overallProgress =
//               ((current - 1) / total * 100 + progress * 100 / total).toInt();
//           await UploadNotificationService.showUploadProgress(
//             id: notificationId,
//             title: 'جاري رفع المنتج',
//             body: 'رفع الملف $current من $total - ${overallProgress}%',
//             progress: overallProgress,
//             maxProgress: 100,
//           );
//         },
//       );

//       if (uploadedUrls.isEmpty) {
//         print("❌ No media files uploaded");
//         return;
//       }

//       // Step 2: Create media string for database
//       final mediaString = uploadedUrls
//           .map((url) {
//             final fileName = url.split('/').last;
//             return fileName;
//           })
//           .join(', ');

//       print("📝 Media string: $mediaString");

//       // Step 3: Update item in database
//       final updateResult = await DatabaseService.updateItem(
//         itemId: itemId,
//         uid: data['uid'],
//         name: data['name'],
//         description: data['description'],
//         category: data['category'],
//         price: data['price'],
//         quantity: data['quantity'],
//         visibility: data['visibility'],
//         comments: data['comments'],
//         media: mediaString,
//       );

//       if (updateResult['success'] == true) {
//         print("✅ Product uploaded successfully: ${data['name']}");

//         // Show success notification
//         await UploadNotificationService.showUploadComplete(
//           id: notificationId,
//           title: 'تم رفع المنتج بنجاح',
//           body: 'تم رفع منتج ${data['name']} بنجاح',
//         );
//         final request = await Dio().post(
//           "https://www.Globee-Trading.com/app2026/sql.php",
//           data: FormData.fromMap({"action": "get_tokens"}),
//         );
//         List player_ids = request.data['player_ids'];
//         List<String> setPlayers = [];
//         for (var player_id in player_ids) {
//           setPlayers.add(player_id['player_id'].toString());
//           await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
//             playerIds: setPlayers,
//             title: "المستخدم: ${data['userName']} رفع منتج جديد",
//             message:
//                 "تم رفع منتج جديد بواسطة ${data['userName']} في النظام. اضغط هنا لعرض التفاصيل أو متابعة النشاط.",
//           );
//         }

//         // final requestUsers = await Dio().post(
//         //   "https://www.Globee-Trading.com/app2026/sql.php",
//         //   data: FormData.fromMap({
//         //     "action": "get_token_followers",
//         //     "user_id": data['uid'],
//         //   }),
//         //   options: Options(headers: {'Content-Type': 'application/json'}),
//         // );
//         // List<String> tokens = [];

//         // for (var token in requestUsers.data['data']) {
//         //   tokens.add(token['user_token']);
//         // }
//         // OneSignalService.sendNotificationToMultipleUsers(
//         //   playerIds: tokens,
//         //   title: "يوجد منتج جديد",
//         //   message:
//         //       "تم رفع منتج جديد إسمه ${data['name']} بسعر ${data['price']} لا تفوته",
//         // );
//       } else {
//         print("❌ Failed to update database: ${updateResult['error']}");

//         // Show error notification
//         await UploadNotificationService.showUploadError(
//           id: notificationId,
//           title: 'فشل رفع المنتج',
//           body: 'حدث خطأ أثناء رفع المنتج',
//         );
//       }

//       data.clear();
//       mediaFiles.clear();
//     } catch (e) {
//       print("❌ Error uploading product: $e");

//       // Show error notification
//       await UploadNotificationService.showUploadError(
//         id: notificationId,
//         title: 'فشل رفع المنتج',
//         body: 'حدث خطأ: ${e.toString()}',
//       );
//     }
//   }

//   // Keep old method for compatibility
//   static void _runBackgroundUpload(Map<String, dynamic> data) async {
//     // This method is kept for backward compatibility but not used
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }
// }
