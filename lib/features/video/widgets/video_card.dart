import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_feed_service.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final VideoPlayerController controller;
  final VoidCallback? onDelete;
  final bool showPrivacyIndicator;

  const VideoCard({
    super.key,
    required this.video,
    required this.controller,
    this.onDelete,
    this.showPrivacyIndicator = false,
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
        _isVisible = info.visibleFraction > 0.5;  // Only consider visible if more than half shown
        
        if (wasVisible != _isVisible) {
          if (_isVisible) {
            widget.controller.play();
          } else {
            widget.controller.pause();
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: widget.video.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(widget.controller),
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            widget.controller.value.isPlaying
                                ? widget.controller.pause()
                                : widget.controller.play();
                          });
                        },
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (widget.video.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.video.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Created: ${_formatDate(widget.video.createdAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                      if (widget.showPrivacyIndicator || widget.onDelete != null)
                        Row(
                          children: [
                            if (widget.showPrivacyIndicator)
                              GestureDetector(
                                onTap: _showPrivacyConfirmation,
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.video.isPrivate ? Icons.lock : Icons.public,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                            if (widget.onDelete != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: widget.onDelete,
                              ),
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