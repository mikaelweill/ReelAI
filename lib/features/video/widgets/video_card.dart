import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_feed_service.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final VideoPlayerController controller;
  final VoidCallback? onDelete;
  final bool showPrivacyIndicator;
  final Function(bool)? onVisibilityChanged;

  const VideoCard({
    super.key,
    required this.video,
    required this.controller,
    this.onDelete,
    this.showPrivacyIndicator = false,
    this.onVisibilityChanged,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  final VideoFeedService _feedService = VideoFeedService();
  bool _isVisible = false;

  @override
  void dispose() {
    if (_isVisible) {
      widget.controller.pause();
    }
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showPrivacyConfirmation() async {
    final isPrivate = widget.video.isPrivate;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isPrivate 
            ? 'Make Video Public?' 
            : 'Make Video Private?'
        ),
        content: Text(
          isPrivate
            ? 'This video will be visible to everyone. Are you sure?'
            : 'This video will only be visible to you. Are you sure?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _feedService.updateVideoPrivacy(widget.video.id, !isPrivate);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update privacy: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.video.id),
      onVisibilityChanged: (info) {
        final wasVisible = _isVisible;
        _isVisible = info.visibleFraction > 0.7;
        
        if (wasVisible != _isVisible) {
          widget.onVisibilityChanged?.call(_isVisible);
        }
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Center the video with correct aspect ratio
            Center(
              child: AspectRatio(
                aspectRatio: widget.video.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Show placeholder if video is not ready
                    if (!widget.controller.value.isInitialized)
                      Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.video_library, color: Colors.white70, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Loading Video...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    VideoPlayer(widget.controller),
                  ],
                ),
              ),
            ),
            // Video controls overlay
            GestureDetector(
              onTap: () {
                if (widget.controller.value.isPlaying) {
                  widget.controller.pause();
                } else {
                  widget.controller.play();
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
            // Video info overlay
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 3.0,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ],
                    ),
                  ),
                  if (widget.video.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.video.description!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            offset: Offset(1.0, 1.0),
                            blurRadius: 3.0,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Created: ${_formatDate(widget.video.createdAt)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              offset: Offset(1.0, 1.0),
                              blurRadius: 3.0,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ],
                        ),
                      ),
                      if (widget.showPrivacyIndicator || widget.onDelete != null)
                        Row(
                          children: [
                            if (widget.showPrivacyIndicator)
                              GestureDetector(
                                onTap: _showPrivacyConfirmation,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    widget.video.isPrivate ? Icons.lock : Icons.public,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            if (widget.onDelete != null) ...[
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: widget.onDelete,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 