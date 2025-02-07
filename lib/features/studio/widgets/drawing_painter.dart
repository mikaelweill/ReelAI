import 'package:flutter/material.dart';

class DrawingStroke {
  final String id;
  final List<Offset> points;
  final Color color;
  final double width;
  final double startTime;
  final double endTime;

  DrawingStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    required this.startTime,
    required this.endTime,
  });

  // Helper method to convert Color to hex string for storage
  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}';
  }

  // Helper method to convert hex string to Color
  static Color _hexToColor(String hex) {
    return Color(int.parse(hex.substring(1), radix: 16));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': _colorToHex(color),
      'width': width,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      id: json['id'],
      points: (json['points'] as List).map((p) => Offset(p['x'], p['y'])).toList(),
      color: _hexToColor(json['color']),
      width: json['width'],
      startTime: json['startTime'],
      endTime: json['endTime'],
    );
  }
}

class SimpleDrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final double currentTime;
  
  SimpleDrawingPainter({
    required this.strokes,
    this.currentStroke,
    required this.currentTime,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes that should be visible at current time
    for (final stroke in strokes) {
      if (currentTime >= stroke.startTime && currentTime <= stroke.endTime) {
        final paint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.width
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        
        _drawStroke(canvas, stroke.points, paint);
      }
    }
    
    // Draw current stroke if exists
    if (currentStroke != null) {
      final paint = Paint()
        ..color = currentStroke!.color
        ..strokeWidth = currentStroke!.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      _drawStroke(canvas, currentStroke!.points, paint);
    }
  }
  
  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }
  
  @override
  bool shouldRepaint(SimpleDrawingPainter oldDelegate) => 
    strokes != oldDelegate.strokes || 
    currentStroke != oldDelegate.currentStroke ||
    currentTime != oldDelegate.currentTime;
} 