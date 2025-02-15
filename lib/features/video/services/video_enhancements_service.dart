import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class Subtitle {
  final String id;
  final double startTime;
  final double endTime;
  final String text;
  final SubtitleStyle style;

  Subtitle({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
    required this.style,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime,
    'endTime': endTime,
    'text': text,
    'style': style.toJson(),
  };

  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
    id: json['id'],
    startTime: json['startTime'],
    endTime: json['endTime'],
    text: json['text'],
    style: SubtitleStyle.fromJson(json['style']),
  );
}

class SubtitleStyle {
  final String color;
  final double size;
  final Position position;
  final String? background;
  final String fontWeight;

  SubtitleStyle({
    required this.color,
    required this.size,
    required this.position,
    this.background,
    required this.fontWeight,
  });

  Map<String, dynamic> toJson() => {
    'color': color,
    'size': size,
    'position': position.toJson(),
    'background': background,
    'fontWeight': fontWeight,
  };

  factory SubtitleStyle.fromJson(Map<String, dynamic> json) => SubtitleStyle(
    color: json['color'],
    size: json['size'],
    position: Position.fromJson(json['position']),
    background: json['background'],
    fontWeight: json['fontWeight'],
  );
}

class Position {
  final double x;
  final double y;

  Position({required this.x, required this.y});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Position.fromJson(Map<String, dynamic> json) => 
      Position(x: json['x'], y: json['y']);
}

class TimestampMark {
  final String id;
  final double time;
  final String title;
  final String? description;
  final String? thumbnail;

  TimestampMark({
    required this.id,
    required this.time,
    required this.title,
    this.description,
    this.thumbnail,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'title': title,
    'description': description,
    'thumbnail': thumbnail,
  };

  factory TimestampMark.fromJson(Map<String, dynamic> json) => TimestampMark(
    id: json['id'],
    time: json['time'],
    title: json['title'],
    description: json['description'],
    thumbnail: json['thumbnail'],
  );
}

class VideoEnhancements {
  final List<Subtitle> subtitles;
  final List<TimestampMark> timestamps;
  final DateTime lastModified;
  final int version;

  VideoEnhancements({
    required this.subtitles,
    required this.timestamps,
    required this.lastModified,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
    'subtitles': subtitles.map((s) => s.toJson()).toList(),
    'timestamps': timestamps.map((t) => t.toJson()).toList(),
    'lastModified': FieldValue.serverTimestamp(),
    'version': version,
  };

  factory VideoEnhancements.fromJson(Map<String, dynamic> json) => VideoEnhancements(
    subtitles: (json['subtitles'] as List)
        .map((s) => Subtitle.fromJson(s))
        .toList(),
    timestamps: (json['timestamps'] as List)
        .map((t) => TimestampMark.fromJson(t))
        .toList(),
    lastModified: (json['lastModified'] as Timestamp).toDate(),
    version: json['version'],
  );
}

class VideoEnhancementsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // Get enhancements for a video
  Stream<VideoEnhancements?> getEnhancements(String videoId) {
    return _firestore
        .collection('video_enhancements')
        .doc(videoId)
        .snapshots()
        .map((doc) => doc.exists 
            ? VideoEnhancements.fromJson(doc.data()!)
            : null);
  }

  // Save or update enhancements
  Future<void> saveEnhancements(String videoId, VideoEnhancements enhancements) async {
    await _firestore
        .collection('video_enhancements')
        .doc(videoId)
        .set(enhancements.toJson());
  }

  // Add a subtitle
  Future<void> addSubtitle(String videoId, Subtitle subtitle) async {
    await _firestore.collection('video_enhancements').doc(videoId).update({
      'subtitles': FieldValue.arrayUnion([subtitle.toJson()]),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  // Add a timestamp
  Future<void> addTimestamp(String videoId, TimestampMark timestamp) async {
    await _firestore.collection('video_enhancements').doc(videoId).update({
      'timestamps': FieldValue.arrayUnion([timestamp.toJson()]),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  // Track timestamp click
  Future<void> trackTimestampClick(String videoId, String timestampId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('video_interactions')
        .doc(videoId)
        .collection('interactions')
        .doc(userId)
        .set({
          'timestampClicks': FieldValue.arrayUnion([{
            'timestampId': timestampId,
            'clickedAt': FieldValue.serverTimestamp(),
          }]),
          'lastViewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // Update view progress
  Future<void> updateViewProgress(String videoId, double progress) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('video_interactions')
        .doc(videoId)
        .collection('interactions')
        .doc(userId)
        .set({
          'viewProgress': progress,
          'lastViewedAt': FieldValue.serverTimestamp(),
          'completedViews': progress >= 0.9 
              ? FieldValue.increment(1) 
              : FieldValue.increment(0),
        }, SetOptions(merge: true));
  }
} 