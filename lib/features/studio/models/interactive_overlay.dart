import 'package:flutter/material.dart';

class InteractiveOverlay {
  final String id;
  final String title;
  final String description;
  final List<String> bulletPoints;
  final String? linkUrl;
  final String? linkText;
  final double startTime;  // in seconds
  final double endTime;    // in seconds
  final Offset position;   // normalized position (0-1)
  final Color dotColor;    // color of the hotspot dot
  final double dotSize;    // size of the hotspot dot

  InteractiveOverlay({
    required this.id,
    required this.title,
    required this.description,
    this.bulletPoints = const [],
    this.linkUrl,
    this.linkText,
    required this.startTime,
    required this.endTime,
    required this.position,
    this.dotColor = Colors.blue,
    this.dotSize = 12.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'bulletPoints': bulletPoints,
    'linkUrl': linkUrl,
    'linkText': linkText,
    'startTime': startTime,
    'endTime': endTime,
    'position': {
      'x': position.dx,
      'y': position.dy,
    },
    'dotColor': '#${dotColor.value.toRadixString(16).padLeft(8, '0')}',
    'dotSize': dotSize,
  };

  factory InteractiveOverlay.fromJson(Map<String, dynamic> json) => InteractiveOverlay(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    bulletPoints: List<String>.from(json['bulletPoints'] ?? []),
    linkUrl: json['linkUrl'],
    linkText: json['linkText'],
    startTime: json['startTime'].toDouble(),
    endTime: json['endTime'].toDouble(),
    position: Offset(
      json['position']['x'].toDouble(),
      json['position']['y'].toDouble(),
    ),
    dotColor: Color(int.parse(json['dotColor'].substring(1), radix: 16)),
    dotSize: json['dotSize'].toDouble(),
  );
} 