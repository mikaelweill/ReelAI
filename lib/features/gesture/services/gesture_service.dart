import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum SwipeDirection {
  up,
  down,
  none,
}

class GestureService {
  final _poseDetector = PoseDetector(options: PoseDetectorOptions());
  double? _lastWristY;
  DateTime? _lastSwipeTime;
  static const _swipeThreshold = 100.0;
  static const _swipeCooldown = Duration(milliseconds: 500);

  Future<SwipeDirection> detectSwipe(InputImage inputImage) async {
    try {
      // Check cooldown
      if (_lastSwipeTime != null && 
          DateTime.now().difference(_lastSwipeTime!) < _swipeCooldown) {
        return SwipeDirection.none;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) return SwipeDirection.none;

      final wrist = poses.first.landmarks[PoseLandmarkType.rightWrist];
      if (wrist == null) return SwipeDirection.none;

      if (_lastWristY == null) {
        _lastWristY = wrist.y;
        return SwipeDirection.none;
      }

      final delta = wrist.y - _lastWristY!;
      _lastWristY = wrist.y;

      if (delta.abs() >= _swipeThreshold) {
        _lastSwipeTime = DateTime.now();
        return delta > 0 ? SwipeDirection.down : SwipeDirection.up;
      }

      return SwipeDirection.none;
    } catch (e) {
      debugPrint('Error detecting swipe: $e');
      return SwipeDirection.none;
    }
  }

  void dispose() {
    _poseDetector.close();
  }
} 