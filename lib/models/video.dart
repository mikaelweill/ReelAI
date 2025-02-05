import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String title;
  final String? description;
  final bool isPrivate;
  final int likes;
  final int comments;
  final DateTime createdAt;
  final int duration;
  final int size;
  final double aspectRatio;
  final String status;
  final Map<String, String>? streamingUrls;
  final List<String>? qualities;

  Video({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.title,
    this.description,
    required this.isPrivate,
    required this.likes,
    required this.comments,
    required this.createdAt,
    required this.duration,
    required this.size,
    required this.aspectRatio,
    required this.status,
    this.streamingUrls,
    this.qualities,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      title: json['title'] ?? '',
      description: json['description'],
      isPrivate: json['isPrivate'] ?? false,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      duration: json['duration'] ?? 0,
      size: json['size'] ?? 0,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 16/9,
      status: json['status'] ?? 'ready',
      streamingUrls: json['streamingUrls'] != null 
          ? Map<String, String>.from(json['streamingUrls'])
          : null,
      qualities: json['qualities'] != null 
          ? List<String>.from(json['qualities'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'title': title,
    'description': description,
    'isPrivate': isPrivate,
    'likes': likes,
    'comments': comments,
    'createdAt': Timestamp.fromDate(createdAt),
    'duration': duration,
    'size': size,
    'aspectRatio': aspectRatio,
    'status': status,
    'streamingUrls': streamingUrls,
    'qualities': qualities,
  };
} 