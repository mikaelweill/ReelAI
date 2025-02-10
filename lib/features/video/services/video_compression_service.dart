import 'dart:io';
import 'package:video_compress/video_compress.dart';

class VideoCompressionService {
  static final VideoCompressionService _instance = VideoCompressionService._internal();
  Subscription? _subscription;
  
  factory VideoCompressionService() {
    return _instance;
  }
  
  VideoCompressionService._internal();

  Future<String?> compressVideo(String videoPath, {
    Function(double)? onProgress,
  }) async {
    try {
      // Clean up any previous compression cache first
      // await VideoCompress.deleteAllCache();  // Removing this line
      
      // Subscribe to compression progress
      _subscription = VideoCompress.compressProgress$.subscribe((progress) {
        if (onProgress != null) {
          onProgress(progress / 100);
        }
      });

      final File videoFile = File(videoPath);
      final int originalSize = await videoFile.length();
      
      // Get video info
      final MediaInfo? info = await VideoCompress.getMediaInfo(videoPath);
      print('\nOriginal Video Properties:');
      print('Resolution: ${info?.width}x${info?.height}');
      print('Duration: ${info?.duration} seconds');
      print('File size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // Check if video is already small enough
      if (originalSize < 5 * 1024 * 1024 && (info?.width ?? 0) <= 1280) {
        print('Video already optimized, skipping compression');
        return videoPath;
      }
      
      print('\nStarting compression...');
      
      print('Original video size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality,  // Use lower quality for better performance
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24, // Lower frame rate
      );
      
      if (mediaInfo?.file == null) {
        throw Exception('Compression failed: no output file');
      }

      final int compressedSize = await mediaInfo!.file!.length();
      print('Compressed video size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('Compression ratio: ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(2)}%');
      
      return mediaInfo.file!.path;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    } finally {
      // Clean up subscription and ensure we free up memory
      _subscription?.unsubscribe();
      _subscription = null;
      // await VideoCompress.deleteAllCache();  // Removing this problematic call
    }
  }

  Future<void> cancelCompression() async {
    try {
      _subscription?.unsubscribe();
      _subscription = null;
      await VideoCompress.cancelCompression();
    } catch (e) {
      print('Error canceling compression: $e');
    }
  }

  Future<void> dispose() async {
    try {
      _subscription?.unsubscribe();
      _subscription = null;
      // await VideoCompress.deleteAllCache();  // Removing this problematic call
    } catch (e) {
      print('Error cleaning up compression cache: $e');
    }
  }
} 