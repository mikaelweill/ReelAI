import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_feed_service.dart';
import '../../studio/models/video_edit.dart';
import 'video_chapter_list.dart';

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
  bool _isChapterListExpanded = false;
  VideoEdit? _videoEdit;

  @override
  void initState() {
    super.initState();
    _loadVideoEdit();
    widget.controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_videoListener);
    if (_isVisible) {
      widget.controller.pause();
    }
    super.dispose();
  }

  void _videoListener() {
    // Trigger rebuild when video position changes (for chapter highlighting)
    if (mounted && _videoEdit?.chapters.isNotEmpty == true) {
      setState(() {});
    }
  }

  Future<void> _loadVideoEdit() async {
    _feedService.getVideoEdits(widget.video.id).listen((videoEdit) {
      if (mounted && videoEdit?.chapters.isNotEmpty == true) {
        setState(() {
          _videoEdit = videoEdit;
          // Auto-expand if we have chapters
          _isChapterListExpanded = true;
        });
      }
    });
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
        child: Column(
          children: [
            // Title section - fixed height or Expanded with flex:2
            Expanded(
              flex: 2,  // 20% of space
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.video.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                    if (widget.video.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.video.description!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDate(widget.video.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video section - Expanded with largest flex
            Expanded(
              flex: 6,  // 60% of space
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.video.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
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
            ),

            // Chapters section - fixed height or Expanded with flex:2
            Expanded(
              flex: 2,  // 20% of space
              child: _videoEdit?.chapters.isNotEmpty == true
                ? VideoChapterList(
                    chapters: _videoEdit!.chapters,
                    currentPosition: widget.controller.value.position.inMilliseconds / 1000,
                    onSeek: (timestamp) {
                      widget.controller.seekTo(Duration(milliseconds: (timestamp * 1000).round()));
                    },
                    isExpanded: _isChapterListExpanded,
                    onToggleExpanded: () {
                      setState(() {
                        _isChapterListExpanded = !_isChapterListExpanded;
                      });
                    },
                  )
                : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
} 