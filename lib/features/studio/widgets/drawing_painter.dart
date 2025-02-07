import 'package:flutter/material.dart';

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

class SimpleDrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  
  SimpleDrawingPainter({
    required this.strokes,
    this.currentStroke,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed strokes
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      _drawStroke(canvas, stroke.points, paint);
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
    strokes != oldDelegate.strokes || currentStroke != oldDelegate.currentStroke;
} 