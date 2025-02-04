import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  });

  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      userId: data['userId'] as String,
      videoUrl: data['videoUrl'] as String,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      title: data['title'] as String,
      description: data['description'] as String?,
      isPrivate: data['isPrivate'] as bool? ?? false,
      likes: data['likes'] as int? ?? 0,
      comments: data['comments'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      duration: data['duration'] as int? ?? 0,
      size: data['size'] as int? ?? 0,
      aspectRatio: (data['aspectRatio'] as num?)?.toDouble() ?? 16/9,
      status: data['status'] as String? ?? 'ready',
    );
  }
}

class VideoFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all videos for the current user
  Stream<List<Video>> getUserVideos() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('videos')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList());
  }

  // Get all videos for the feed
  Stream<List<Video>> getAllVideos() {
    return _firestore
        .collection('videos')
        .where('isPrivate', isEqualTo: false)  // Only show public videos
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Video.fromFirestore(doc)).toList());
  }

  // Delete a video
  Future<void> deleteVideo(String videoId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    if (videoDoc.exists && videoDoc.get('userId') == userId) {
      await _firestore.collection('videos').doc(videoId).delete();
    }
  }
} 