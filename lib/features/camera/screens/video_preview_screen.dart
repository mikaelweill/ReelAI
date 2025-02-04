import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../video/services/video_upload_service.dart';

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
  late VideoPlayerController _controller;
  final VideoUploadService _uploadService = VideoUploadService();
  bool _isPlaying = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    await _controller.setLooping(true);
    await _controller.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  Future<void> _handlePublish() async {
    setState(() {
      _isUploading = true;
    });

    try {
      await _uploadService.uploadVideo(
        filePath: widget.videoPath,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );
      
      if (mounted) {
        Navigator.of(context).pop(true); // true indicates published
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  void _handleDelete() {
    File(widget.videoPath).delete();
    Navigator.of(context).pop(false); // false indicates deleted/cancelled
  }

  @override
  void dispose() {
    _controller.dispose();
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
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
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

            // Upload Progress Overlay
            if (_isUploading) Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: _uploadProgress,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
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