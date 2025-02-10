import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'video_preview_screen.dart';
import 'dart:io';

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
      
      // Log camera settings
      final previewSize = _controller.value.previewSize;
      
      print('Camera Settings:');
      print('Preview Size: ${previewSize?.width}x${previewSize?.height}');
      print('Camera Description:');
      print('- Name: ${_currentCamera.name}');
      print('- Lens Direction: ${_currentCamera.lensDirection}');
      print('- Sensor Orientation: ${_currentCamera.sensorOrientation}°');
      
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
        
        // Log recording settings
        final previewSize = _controller.value.previewSize;
        print('Started Recording:');
        print('Recording Size: ${previewSize?.width}x${previewSize?.height}');
      } catch (e) {
        print('Error starting recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_controller.value.isRecordingVideo) {
      try {
        // Reset animation first
        _progressController.stop();
        setState(() {
          _isRecording = false;
        });

        // Then handle video
        final file = await _controller.stopVideoRecording();
        
        // Log video file properties
        final videoFile = File(file.path);
        final fileSize = await videoFile.length();
        print('Recorded Video Properties:');
        print('File Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        print('File Path: ${file.path}');
        
        if (!mounted) return;  // Safety check before navigation

        try {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VideoPreviewScreen(videoPath: file.path),
            ),
          );
          
          // Only attempt navigation if still mounted
          if (mounted) {
            if (result != null && result is Map<String, dynamic> && result['shouldClose'] == true) {
              Navigator.of(context).pop();
            }
          }
        } catch (navError) {
          // If preview screen fails, at least stop recording cleanly
          print('Error navigating to preview: $navError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to preview video. Please try again.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        print('Error stopping recording: $e');
        // Reset state and show error
        setState(() {
          _isRecording = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save video. Please try again.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    try {
      _progressController.dispose();
      _recordingTimer?.cancel();
      if (_controller.value.isRecordingVideo) {
        _controller.stopVideoRecording();
      }
      _controller.dispose();
    } catch (e) {
      print('Error during cleanup: $e');
    }
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