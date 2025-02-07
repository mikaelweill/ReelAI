import 'package:flutter/material.dart';

class SimpleDrawingPainter extends CustomPainter {
  final List<Offset> points;
  
  SimpleDrawingPainter(this.points);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    if (points.length < 2) return;
    
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }
  
  @override
  bool shouldRepaint(SimpleDrawingPainter oldDelegate) => true;
} 