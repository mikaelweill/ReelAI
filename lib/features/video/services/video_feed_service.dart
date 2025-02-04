import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Video {
  final String id;
  final String userId;
  final String videoUrl;
  final DateTime createdAt;
  final int duration;
  final double aspectRatio;
  final String status;
  final String? title;
  final String? description;
  final bool isPrivate;

  Video({
    required this.id,
    required this.userId,
    required this.videoUrl,
    required this.createdAt,
    required this.duration,
    required this.aspectRatio,
    required this.status,
    this.title,
    this.description,
    this.isPrivate = false,
  });

  factory Video.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Video(
      id: doc.id,
      userId: data['userId'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      duration: data['duration'] ?? 0,
      aspectRatio: (data['aspectRatio'] ?? 1.0).toDouble(),
      status: data['status'] ?? 'ready',
      title: data['title'],
      description: data['description'],
      isPrivate: data['isPrivate'] ?? false,
    );
  }
}

class VideoFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all videos for the current user
  Stream<List<Video>> getUserVideos() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Video.fromFirestore(doc))
              .where((video) => video.status == 'ready')
              .toList();
        });
  }

  // Get all videos for the feed
  Stream<List<Video>> getAllVideos() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Video.fromFirestore(doc))
              .where((video) => video.status == 'ready')
              .toList();
        });
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