import 'package:flutter/material.dart';
import '../services/gesture_service.dart';

class GestureOverlay extends StatelessWidget {
  final SwipeDirection direction;
  
  const GestureOverlay({
    super.key,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String text;
    
    switch (direction) {
      case SwipeDirection.up:
        icon = Icons.arrow_upward;
        text = "Previous Video";
        break;
      case SwipeDirection.down:
        icon = Icons.arrow_downward;
        text = "Next Video";
        break;
      case SwipeDirection.none:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
} 