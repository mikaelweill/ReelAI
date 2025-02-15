import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/gesture_service.dart';
import '../services/simple_camera_controller.dart';

class GestureDetectorWidget extends StatefulWidget {
  final Function(SwipeDirection) onSwipeDetected;
  
  const GestureDetectorWidget({
    Key? key,
    required this.onSwipeDetected,
  }) : super(key: key);

  @override
  State<GestureDetectorWidget> createState() => _GestureDetectorWidgetState();
}

class _GestureDetectorWidgetState extends State<GestureDetectorWidget> {
  final _cameraController = SimpleCameraController();
  final _gestureService = GestureService();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraController.initialize();
      if (!mounted) return;
      
      setState(() {});
      await _startImageStream();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _startImageStream() async {
    await _cameraController.camera.startImageStream((image) async {
      if (_isProcessing) return;
      _isProcessing = true;
      
      try {
        final inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotation.rotation270deg,
            format: InputImageFormat.yuv420,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final direction = await _gestureService.detectSwipe(inputImage);
        if (direction != SwipeDirection.none && mounted) {
          widget.onSwipeDetected(direction);
        }
      } finally {
        if (mounted) {
          _isProcessing = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: _cameraController.camera.value.aspectRatio,
          child: CameraPreview(_cameraController.camera),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _gestureService.dispose();
    super.dispose();
  }
} 