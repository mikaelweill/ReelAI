import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../video/services/video_upload_service.dart';
import '../widgets/video_metadata_dialog.dart';

class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;

  const VideoPreviewScreen({
    super.key,
    required this.videoPath,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late Player _player;
  late VideoController _controller;
  final VideoUploadService _uploadService = VideoUploadService();
  bool _isPlaying = false;
  bool _isUploading = false;
  bool _uploadComplete = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _player = Player();
    _controller = VideoController(_player);
    await _player.open(Media('file://${widget.videoPath}'));
    await _player.setPlaylistMode(PlaylistMode.loop);
    await _player.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _player.play() : _player.pause();
    });
  }

  Future<void> _handlePublish() async {
    if (_isUploading) return; // Prevent double uploads

    // Verify file exists
    final videoFile = File(widget.videoPath);
    if (!await videoFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video file not found. Please try recording again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show metadata dialog first
    VideoMetadata? metadata;
    try {
      metadata = await showDialog<VideoMetadata>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const VideoMetadataDialog(),
      );
    } catch (e) {
      print('Error showing metadata dialog: $e');
      return;
    }

    // If user cancelled, return
    if (metadata == null) return;

    setState(() {
      _isUploading = true;
      _uploadComplete = false;
      _uploadProgress = 0.0;
    });

    try {
      // Pause video during upload
      await _player.pause();
      
      // Get video dimensions and calculate aspect ratio
      final width = _player.state.width ?? 1920;  // Default to 16:9 if null
      final height = _player.state.height ?? 1080;
      final aspectRatio = width / height;
      print('Video dimensions: ${width}x${height}');
      print('Calculated aspect ratio: $aspectRatio');
      
      // Track when the upload is complete
      bool uploadFinished = false;
      String? videoId = await _uploadService.uploadVideo(
        filePath: widget.videoPath,
        title: metadata.title,
        description: metadata.description,
        isPrivate: metadata.isPrivate,
        aspectRatio: aspectRatio,
        onProgress: (progress) {
          if (!mounted) return; // Safety check
          
          setState(() {
            _uploadProgress = progress;
            if (progress >= 1.0 && !uploadFinished) {
              uploadFinished = true;
              _uploadComplete = true;
              
              // Auto-navigate after showing "Upload Complete" for 2 seconds
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.of(context).pop({'success': true, 'shouldClose': true});
                }
              });
            }
          });
        },
      );

      // If upload failed but we didn't catch an error
      if (videoId == null && mounted) {
        throw Exception('Upload failed to complete');
      }

    } catch (e) {
      print('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadComplete = false;
        });
      }
    }
  }

  void _handleDelete() {
    try {
      final file = File(widget.videoPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
    if (mounted) {
      Navigator.of(context).pop({'success': false, 'shouldClose': false});
    }
  }

  @override
  void dispose() {
    try {
      _player.dispose();
    } catch (e) {
      print('Error disposing video player: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Preview
            Center(
              child: AspectRatio(
                aspectRatio: (_player.state.width ?? 1920) / (_player.state.height ?? 1080),
                child: Video(controller: _controller),
              ),
            ),

            // Play/Pause Button Overlay
            if (!_isUploading) Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  color: Colors.transparent,
                  child: AnimatedOpacity(
                    opacity: _isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Upload Progress/Success Overlay
            if (_isUploading) Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_uploadComplete) CircularProgressIndicator(
                    value: _uploadProgress,
                    color: Colors.white,
                  ),
                  if (_uploadComplete) const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _uploadComplete
                        ? 'Upload Complete!'
                        : '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Actions
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!_isUploading) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _handleDelete,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 48,
                      ),
                      onPressed: _handlePublish,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 