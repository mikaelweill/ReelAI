import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadVideo({
    required String filePath,
    required String title,
    String? description,
    required bool isPrivate,
    void Function(double)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to upload videos');

    final videoFile = File(filePath);
    final videoId = DateTime.now().millisecondsSinceEpoch.toString();
    final videoPath = 'videos/${user.uid}/$videoId.mp4';

    try {
      // Initialize video metadata
      final videoController = VideoPlayerController.file(videoFile);
      await videoController.initialize();
      final duration = videoController.value.duration.inSeconds;
      final aspectRatio = videoController.value.aspectRatio;
      videoController.dispose();

      // Upload video
      final uploadTask = _storage.ref(videoPath).putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final videoUrl = await snapshot.ref.getDownloadURL();

      // Create video document in Firestore
      await _firestore.collection('videos').doc(videoId).set({
        'userId': user.uid,
        'videoUrl': videoUrl,
        'thumbnailUrl': '', // TODO: Generate and upload thumbnail
        'title': title,
        'description': description ?? '',
        'isPrivate': isPrivate,
        'likes': 0,
        'comments': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'duration': duration,
        'size': snapshot.totalBytes,
        'aspectRatio': aspectRatio,
        'status': 'ready',
      });

      return videoId;
    } catch (e) {
      print('Error uploading video: $e');
      rethrow;
    }
  }

  Future<void> deleteVideo(String videoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User must be logged in to delete videos');

    try {
      // Delete from Storage
      await _storage.ref('videos/${user.uid}/$videoId.mp4').delete();
      
      // Delete from Firestore
      await _firestore.collection('videos').doc(videoId).delete();
    } catch (e) {
      print('Error deleting video: $e');
      rethrow;
    }
  }
} 