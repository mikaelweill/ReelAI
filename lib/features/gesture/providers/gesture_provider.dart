import 'package:flutter/material.dart';
import '../services/gesture_service.dart';

class GestureProvider extends ChangeNotifier {
  bool _isEnabled = true;
  DateTime? _lastGestureTime;
  static const _gestureCooldown = Duration(milliseconds: 500);

  bool get isEnabled => _isEnabled;

  void toggleGestures() {
    _isEnabled = !_isEnabled;
    notifyListeners();
  }

  bool handleSwipe(SwipeDirection direction) {
    if (!_isEnabled) return false;

    // Check cooldown
    final now = DateTime.now();
    if (_lastGestureTime != null &&
        now.difference(_lastGestureTime!) < _gestureCooldown) {
      return false;
    }
    _lastGestureTime = now;

    // Process swipe
    switch (direction) {
      case SwipeDirection.up:
        debugPrint('Swipe Up Detected - Previous Video');
        return true;
      case SwipeDirection.down:
        debugPrint('Swipe Down Detected - Next Video');
        return true;
      case SwipeDirection.none:
        return false;
    }
  }
} 