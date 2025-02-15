import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SimpleCameraController {
  CameraController? _controller;
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  CameraController get camera => _controller!;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request camera permission
    final status = await Permission.camera.request();
    if (status.isDenied) {
      throw CameraException('Permission denied', 'Camera permission is required');
    }

    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('No cameras', 'No cameras available on device');
      }

      // Select front camera if available, otherwise use the first camera
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('Initializing camera: ${camera.name}');

      // Create controller with minimal configuration
      _controller = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Initialize camera
      await _controller!.initialize();
      
      // Basic configuration
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
      
      _isInitialized = true;
      debugPrint('Camera initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      await dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('Error disposing camera: $e');
      }
      _controller = null;
    }
    _isInitialized = false;
  }
} 