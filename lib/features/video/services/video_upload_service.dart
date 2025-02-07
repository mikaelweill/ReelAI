import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'video_compression_service.dart';

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoCompressionService _compressionService = VideoCompressionService();

  Future<String?> uploadVideo({
    required String filePath,
    required String title,
    String? description,
    required bool isPrivate,
    Function(double)? onProgress,
  }) async {
    File? compressedFile;
    try {
      // First compress the video
      onProgress?.call(0.0);
      print('Starting video compression...');
      
      final String? compressedPath = await _compressionService.compressVideo(
        filePath,
        onProgress: (progress) {
          // Compression takes up first 50% of progress
          onProgress?.call(progress * 0.5);
        },
      );

      if (compressedPath == null) {
        throw Exception('Video compression failed');
      }

      print('Video compression complete. Starting upload...');

      compressedFile = File(compressedPath);
      if (!await compressedFile.exists()) {
        throw Exception('Compressed file not found');
      }

      // Upload the compressed video
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}';
      final Reference ref = _storage
          .ref()
          .child('videos/${_auth.currentUser!.uid}/$fileName');

      final UploadTask uploadTask = ref.putFile(
        compressedFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'title': title,
            'isPrivate': isPrivate.toString(),
          },
        ),
      );

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final double uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Upload takes up second 50% of progress
        onProgress?.call(0.5 + (uploadProgress * 0.5));
      });

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Create Firestore document
      final DocumentReference docRef = await _firestore.collection('videos').add({
        'userId': _auth.currentUser!.uid,
        'videoUrl': downloadUrl,
        'title': title,
        'description': description,
        'isPrivate': isPrivate,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'ready',
        'size': snapshot.totalBytes,
      });

      print('Upload complete. Video ID: ${docRef.id}');

      // Clean up compressed file
      try {
        if (compressedFile != null && await compressedFile.exists()) {
          await compressedFile.delete();
          print('Cleaned up compressed file');
        }
      } catch (e) {
        print('Warning: Could not clean up compressed file: $e');
      }

      return docRef.id;
    } catch (e) {
      print('Error in uploadVideo: $e');
      return null;
    } finally {
      // Clean up compression cache
      await _compressionService.dispose();
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      // Get the video document
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) return;

      // Delete from Storage
      final String videoUrl = doc.data()?['videoUrl'];
      if (videoUrl != null) {
        final ref = _storage.refFromURL(videoUrl);
        await ref.delete();
      }

      // Delete from Firestore
      await _firestore.collection('videos').doc(videoId).delete();
    } catch (e) {
      print('Error deleting video: $e');
      rethrow;
    }
  }
} 