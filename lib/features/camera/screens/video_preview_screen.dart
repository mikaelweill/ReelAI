import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  late VideoPlayerController _controller;
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
    // Show metadata dialog first
    final metadata = await showDialog<VideoMetadata>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const VideoMetadataDialog(),
    );

    // If user cancelled, return
    if (metadata == null) return;

    setState(() {
      _isUploading = true;
      _uploadComplete = false;
      _uploadProgress = 0.0;
    });

    try {
      // Track when the upload is complete
      bool uploadFinished = false;
      String? videoId = await _uploadService.uploadVideo(
        filePath: widget.videoPath,
        title: metadata.title,
        description: metadata.description,
        isPrivate: metadata.isPrivate,
        onProgress: (progress) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
    File(widget.videoPath).delete();
    Navigator.of(context).pop({'success': false, 'shouldClose': false}); // Return with no close request
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