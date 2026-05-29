import 'dart:io';
import 'dart:async';
import 'package:GES/shared/providers/app_provider.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../add_product/add_product_screen.dart';

class CameraScreen extends StatefulWidget {
  final bool isVideo;

  const CameraScreen({super.key, required this.isVideo});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<String> capturedFiles = [];
  int videoDuration = 15;
  bool isRecording = false;
  int recordingSeconds = 0;
  Timer? recordingTimer;
  bool permissionsGranted = false;

  @override
  void dispose() {
    recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    // اطلب إذن الكاميرا والميكروفون
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    // تحقق إن الأذونات اتمنحت
    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted) {
      setState(() {
        permissionsGranted = true;
      });
    } else {
      // لو المستخدم رفض الأذونات
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'نحتاج أذونات الكاميرا والميكروفون لتسجيل الفيديو بالصوت',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'الإعدادات',
              textColor: Colors.white,
              onPressed: () {
                openAppSettings(); // يفتح إعدادات التطبيق
              },
            ),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  // Build capture request for photos
  Future<CaptureRequest> _captureRequestBuilder(List<Sensor> sensors) async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return SingleCaptureRequest(path, sensors.first);
  }

  // Build capture request for videos
  Future<CaptureRequest> _videoCaptureRequestBuilder(
    List<Sensor> sensors,
  ) async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
    return SingleCaptureRequest(path, sensors.first);
  }

  void _startRecordingTimer(CameraState state) {
    setState(() {
      isRecording = true;
      recordingSeconds = 0;
    });

    recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        recordingSeconds++;
      });

      // Stop recording after specified duration
      if (recordingSeconds >= videoDuration) {
        _stopRecording(state);
      }
    });
  }

  void _stopRecording(CameraState state) {
    recordingTimer?.cancel();
    state.when(
      onVideoRecordingMode: (videoState) {
        videoState.stopRecording();
      },
    );

    setState(() {
      isRecording = false;
      recordingSeconds = 0;
    });
  }

  @override
  void initState() {
    requestPermissions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: permissionsGranted
          ? Consumer<AppProvider>(
              builder: (context, appProvider, child) {
                return CameraAwesomeBuilder.awesome(
                  saveConfig: SaveConfig.photoAndVideo(
                    initialCaptureMode: widget.isVideo
                        ? CaptureMode.video
                        : CaptureMode.photo,
                    photoPathBuilder: _captureRequestBuilder,
                    videoPathBuilder: _videoCaptureRequestBuilder,
                    videoOptions: VideoOptions(
                      enableAudio: true, // ⭐ده المهم!
                      quality: VideoRecordingQuality.fhd,
                    ),
                  ),
                  sensorConfig: SensorConfig.single(
                    sensor: Sensor.position(SensorPosition.back),
                    aspectRatio: CameraAspectRatios.ratio_16_9,
                    flashMode: FlashMode.none,
                  ),
                  enablePhysicalButton: true,
                  onMediaCaptureEvent: (MediaCapture capture) {
                    final file = File(capture.captureRequest.path!);

                    if (file.existsSync() && mounted) {
                      setState(() {
                        capturedFiles.add(capture.captureRequest.path!);
                        appProvider.setMedia(capture.captureRequest.path ?? "");
                      });

                      // Show success feedback
                      final isVideo = capture.captureRequest.path!.endsWith(
                        '.mp4',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isVideo
                                ? 'تم تسجيل الفيديو ✅'
                                : 'تم التقاط الصورة ✅',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  topActionsBuilder: (state) => _buildTopActions(state),
                  bottomActionsBuilder: (state) => _buildBottomActions(state),
                  middleContentBuilder: (state) => _buildMiddleContent(state),
                );
              },
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'جاري طلب الأذونات...',
                    style: GoogleFonts.cairo(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopActions(CameraState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!isRecording)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.close_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              )
            else
              SizedBox(width: 48),

            // Counter during recording
            if (isRecording)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${recordingSeconds}s / ${videoDuration}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(width: 48),

            IconButton(
              onPressed: () => state.switchCameraSensor(),
              icon: Container(
                width: 50,
                height: 50,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.refresh_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(CameraState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isVideo && !isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.timer_1, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          videoDuration = videoDuration == 15 ? 30 : 15;
                        });
                      },
                      child: Text(
                        '${videoDuration}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: capturedFiles.isNotEmpty ? _showPreview : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: capturedFiles.isNotEmpty
                          ? AppColors.primary
                          : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: capturedFiles.isNotEmpty
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildMediaPreview(capturedFiles.last),
                              ),
                              if (capturedFiles.length > 1)
                                Positioned(
                                  top: -7,
                                  right: -7,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${capturedFiles.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const Icon(
                            Iconsax.gallery,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),

                // Capture button
                state.when(
                  onPhotoMode: (photoState) =>
                      AwesomeCaptureButton(state: state),
                  onVideoMode: (videoState) => GestureDetector(
                    onTap: () {
                      videoState.startRecording();
                      _startRecordingTimer(state);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  onVideoRecordingMode: (recordingState) => GestureDetector(
                    onTap: () => _stopRecording(state),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  onPreparingCamera: (_) => SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return AddProductScreen(mediaFiles: capturedFiles);
                        },
                      ),
                    );
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: capturedFiles.isNotEmpty
                          ? Colors.green
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Iconsax.tick_circle,
                      color: Colors.white,
                      size: 24,
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

  Widget _buildMiddleContent(CameraState state) {
    return const SizedBox.shrink();
  }

  Widget _buildMediaPreview(String path) {
    final isVideo = path.endsWith('.mp4');

    if (isVideo) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Icon(Iconsax.video_play, color: Colors.white, size: 30),
        ),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  void _showPreview() {
    if (capturedFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                alignment: Alignment.centerRight,
                child: Text(
                  'الوسائط المحفوظة (${capturedFiles.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: capturedFiles.length,
                itemBuilder: (context, index) {
                  final file = File(capturedFiles[index]);
                  final isVideo = capturedFiles[index].endsWith('.mp4');

                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildMediaPreview(capturedFiles[index]),
                      ),

                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              capturedFiles.removeAt(index);
                            });
                            Navigator.pop(context);
                            if (capturedFiles.isNotEmpty) {
                              _showPreview();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Iconsax.trash,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
