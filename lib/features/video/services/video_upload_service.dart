import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'video_compression_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
    required double aspectRatio,
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
        'aspectRatio': aspectRatio,
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

  Future<String?> importYoutubeVideo(String url, {Function(double)? onProgress}) async {
    final yt = YoutubeExplode();
    File? videoFile;
    
    try {
      print('Processing YouTube video: $url');
      
      // Get video details
      final video = await yt.videos.get(url);
      print('\nVideo Info:');
      print('Title: ${video.title}');
      print('Duration: ${video.duration}');
      print('Author: ${video.author}');
      
      // Get manifest and log available streams
      print('\nFetching video manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(url);
      
      print('\nAll available streams:');
      print('Muxed streams (video+audio):');
      manifest.muxed.forEach((stream) {
        print('- ${stream.videoQuality}, ${stream.size.totalMegaBytes.toStringAsFixed(2)}MB, ${stream.container}');
      });
      
      print('\nVideo-only streams:');
      manifest.videoOnly.forEach((stream) {
        print('- ${stream.videoQuality}, ${stream.size.totalMegaBytes.toStringAsFixed(2)}MB, ${stream.container}');
      });
      
      // Combine both muxed and video-only streams
      final allStreams = [...manifest.muxed, ...manifest.videoOnly]
        .where((s) => s.videoQuality.toString().contains('720') || 
                     s.videoQuality.toString().contains('480') ||
                     s.videoQuality.toString().contains('360'))
        .toList();
      
      print('\nFiltered streams (720p or lower):');
      allStreams.forEach((stream) {
        print('- ${stream.videoQuality}, ${stream.size.totalMegaBytes.toStringAsFixed(2)}MB, ${stream.container}');
      });
      
      if (allStreams.isEmpty) {
        throw Exception('No suitable video streams found after filtering for 720p or lower');
      }
      
      // Sort by quality and log
      allStreams.sort((a, b) {
        // Extract resolution numbers (e.g., "720p" -> 720)
        final aRes = int.tryParse(a.videoQuality.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bRes = int.tryParse(b.videoQuality.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return bRes.compareTo(aRes);
      });
      
      print('\nSorted streams (highest quality first):');
      allStreams.forEach((stream) {
        print('- ${stream.videoQuality}, ${stream.size.totalMegaBytes.toStringAsFixed(2)}MB, ${stream.container}');
      });
      
      // Select stream and log selection criteria
      print('\nAttempting to select stream under 10MB...');
      final selectedStream = allStreams
        .firstWhere(
          (s) => s.size.totalMegaBytes <= 10,
          orElse: () {
            print('No streams under 10MB found, selecting smallest available stream');
            return allStreams.reduce((a, b) => 
              a.size.totalBytes < b.size.totalBytes ? a : b
            );
          },
        );
      
      print('\nSelected stream for download:');
      print('Quality: ${selectedStream.videoQuality}');
      print('Size: ${selectedStream.size.totalMegaBytes.toStringAsFixed(2)}MB');
      print('Container: ${selectedStream.container}');
      print('Bitrate: ${selectedStream.bitrate}');
      
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, '${video.id}.mp4');
      videoFile = File(tempPath);
      
      // Download the video
      print('\nStarting download to: $tempPath');
      final fileStream = await yt.videos.streamsClient.get(selectedStream);
      final fileLength = selectedStream.size.totalBytes;
      var downloaded = 0;
      
      final output = videoFile.openWrite();
      
      await for (final data in fileStream) {
        output.add(data);
        downloaded += data.length;
        final progress = downloaded / fileLength;
        onProgress?.call(progress * 0.5); // First 50% is download
        if (downloaded % (fileLength ~/ 10) == 0) {  // Log every 10%
          print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
        }
      }
      
      await output.close();
      print('Download complete! File size: ${(await videoFile.length()) / (1024 * 1024)}MB');
      
      // Upload to Firebase
      print('\nStarting Firebase upload...');
      final width = selectedStream.videoResolution.width;
      final height = selectedStream.videoResolution.height;
      print('\nVideo dimensions: ${width}x${height}');
      final aspectRatio = width / height;
      print('Calculated aspect ratio: $aspectRatio');
      
      final videoId = await uploadVideo(
        filePath: tempPath,
        title: video.title,
        description: video.description,
        isPrivate: false,
        aspectRatio: aspectRatio,
        onProgress: (progress) {
          onProgress?.call(0.5 + (progress * 0.5));
        },
      );
      
      return videoId;
      
    } catch (e, stackTrace) {
      print('Error importing YouTube video:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return null;
    } finally {
      yt.close();
      // Clean up temp file
      try {
        if (videoFile != null && await videoFile.exists()) {
          await videoFile.delete();
          print('Cleaned up temporary file');
        }
      } catch (e) {
        print('Warning: Could not clean up temporary file: $e');
      }
    }
  }
} 