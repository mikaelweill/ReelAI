import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'video_preview_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  late CameraDescription _currentCamera;
  Timer? _recordingTimer;
  late AnimationController _progressController;
  static const int maxRecordingDuration = 30; // 30 seconds

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: maxRecordingDuration),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _stopRecording();
        }
      });
    
    // Find the front camera
    _currentCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      _currentCamera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _flipCamera() async {
    final lensDirection = _currentCamera.lensDirection;
    CameraDescription newCamera;
    
    if (lensDirection == CameraLensDirection.front) {
      newCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _currentCamera,
      );
    } else {
      newCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _currentCamera,
      );
    }

    if (newCamera != _currentCamera) {
      setState(() {
        _isInitialized = false;
        _currentCamera = newCamera;
      });
      
      await _controller.dispose();
      await _initializeCamera();
    }
  }

  Future<void> _startRecording() async {
    if (!_controller.value.isRecordingVideo) {
      try {
        await _controller.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
        _progressController.forward(from: 0.0);
      } catch (e) {
        print('Error starting recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_controller.value.isRecordingVideo) {
      try {
        _progressController.stop();
        final file = await _controller.stopVideoRecording();
        setState(() {
          _isRecording = false;
        });
        
        if (mounted) {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VideoPreviewScreen(videoPath: file.path),
            ),
          );
          
          if (result != null && result is Map<String, dynamic>) {
            if (result['shouldClose'] == true) {
              Navigator.of(context).pop();
            }
          }
        }
      } catch (e) {
        print('Error stopping recording: $e');
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _recordingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            Center(
              child: CameraPreview(_controller),
            ),
            
            // Top Controls
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close Button
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  // Flip Camera Button
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _flipCamera,
                  ),
                ],
              ),
            ),
            
            // Recording Button with Progress
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress Indicator
                    if (_isRecording)
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return CircularProgressIndicator(
                              value: _progressController.value,
                              color: Colors.red,
                              strokeWidth: 3,
                              backgroundColor: Colors.red.withOpacity(0.3),
                            );
                          },
                        ),
                      ),
                    // Recording Button
                    GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecording(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          color: _isRecording ? Colors.red : Colors.transparent,
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording ? Colors.red : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 