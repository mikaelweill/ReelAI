import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/drawing_painter.dart';
import 'interactive_overlay.dart';

class TextOverlay {
  final String id;
  final String text;
  final double startTime;  // in seconds
  final double endTime;    // in seconds
  final double top;        // position from top (0-1)
  final double left;       // position from left (0-1)
  final String style;      // predefined style name

  TextOverlay({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.top,
    required this.left,
    required this.style,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'startTime': startTime,
    'endTime': endTime,
    'top': top,
    'left': left,
    'style': style,
  };

  factory TextOverlay.fromJson(Map<String, dynamic> json) => TextOverlay(
    id: json['id'],
    text: json['text'],
    startTime: json['startTime'].toDouble(),
    endTime: json['endTime'].toDouble(),
    top: json['top'].toDouble(),
    left: json['left'].toDouble(),
    style: json['style'],
  );
}

class ChapterMark {
  final String id;
  final String title;
  final double timestamp;  // in seconds
  final String? description;

  ChapterMark({
    required this.id,
    required this.title,
    required this.timestamp,
    this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'timestamp': timestamp,
    'description': description,
  };

  factory ChapterMark.fromJson(Map<String, dynamic> json) => ChapterMark(
    id: json['id'],
    title: json['title'],
    timestamp: json['timestamp'].toDouble(),
    description: json['description'],
  );
}

class Caption {
  final String id;
  final String text;
  final double startTime;  // in seconds
  final double duration;   // in seconds

  Caption({
    required this.id,
    required this.text,
    required this.startTime,
    required this.duration,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'startTime': startTime,
    'duration': duration,
  };

  factory Caption.fromJson(Map<String, dynamic> json) => Caption(
    id: json['id'],
    text: json['text'],
    startTime: json['startTime'].toDouble(),
    duration: json['duration'].toDouble(),
  );
}

class VideoEdit {
  final String videoId;
  final List<TextOverlay> textOverlays;
  final List<ChapterMark> chapters;
  final List<Caption> captions;
  final List<DrawingStroke> drawings;
  final List<InteractiveOverlay> interactiveOverlays;
  final Map<String, dynamic>? soundEdits;
  final DateTime lastModified;
  final double? trimStartTime;  // in seconds, null means no trim
  final double? trimEndTime;    // in seconds, null means no trim

  VideoEdit({
    required this.videoId,
    required this.textOverlays,
    required this.chapters,
    required this.captions,
    List<DrawingStroke>? drawings,
    List<InteractiveOverlay>? interactiveOverlays,
    this.soundEdits,
    required this.lastModified,
    this.trimStartTime,
    this.trimEndTime,
  }) : drawings = drawings ?? [],
       interactiveOverlays = interactiveOverlays ?? [];

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'textOverlays': textOverlays.map((e) => e.toJson()).toList(),
    'chapters': chapters.map((e) => e.toJson()).toList(),
    'captions': captions.map((e) => e.toJson()).toList(),
    'drawings': drawings.map((e) => e.toJson()).toList(),
    'interactiveOverlays': interactiveOverlays.map((e) => e.toJson()).toList(),
    'soundEdits': soundEdits,
    'lastModified': Timestamp.fromDate(lastModified),
    'trimStartTime': trimStartTime,
    'trimEndTime': trimEndTime,
  };

  factory VideoEdit.fromJson(Map<String, dynamic> json) => VideoEdit(
    videoId: json['videoId'],
    textOverlays: (json['textOverlays'] as List? ?? [])
        .map((e) => TextOverlay.fromJson(e))
        .toList(),
    chapters: (json['chapters'] as List? ?? [])
        .map((e) => ChapterMark.fromJson(e))
        .toList(),
    captions: (json['captions'] as List? ?? [])
        .map((e) => Caption.fromJson(e))
        .toList(),
    drawings: (json['drawings'] as List? ?? [])
        .map((e) => DrawingStroke.fromJson(e))
        .toList(),
    interactiveOverlays: (json['interactiveOverlays'] as List? ?? [])
        .map((e) => InteractiveOverlay.fromJson(e))
        .toList(),
    soundEdits: json['soundEdits'],
    lastModified: (json['lastModified'] as Timestamp).toDate(),
    trimStartTime: json['trimStartTime']?.toDouble(),
    trimEndTime: json['trimEndTime']?.toDouble(),
  );
} 