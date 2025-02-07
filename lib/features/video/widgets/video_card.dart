import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_feed_service.dart';
import '../../studio/models/video_edit.dart';
import '../../studio/widgets/drawing_painter.dart';
import 'video_chapter_list.dart';

class VideoCard extends StatefulWidget {
  final Video video;
  final mk.VideoController controller;
  final Player player;
  final VoidCallback? onDelete;
  final bool showPrivacyIndicator;
  final Function(bool)? onVisibilityChanged;

  const VideoCard({
    super.key,
    required this.video,
    required this.controller,
    required this.player,
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
  double _currentPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _loadVideoEdit();
    _setupPositionListener();
  }

  void _setupPositionListener() {
    widget.player.stream.position.listen((position) {
      if (mounted) {
        final currentPos = position.inMilliseconds / 1000.0;
        setState(() {
          _currentPosition = currentPos;
        });

        // Enforce trim boundaries during playback
        if (_videoEdit != null && widget.player.state.playing) {
          final trimStart = _videoEdit!.trimStartTime;
          final trimEnd = _videoEdit!.trimEndTime;
          
          if (trimEnd != null && currentPos >= trimEnd) {
            // If we hit the trim end, loop back to trim start
            if (trimStart != null) {
              widget.player.seek(Duration(milliseconds: (trimStart * 1000).round()));
            } else {
              // If no trim start defined, go to beginning
              widget.player.seek(Duration.zero);
            }
          } else if (trimStart != null && currentPos < trimStart) {
            // If somehow we're before trim start, seek to trim start
            widget.player.seek(Duration(milliseconds: (trimStart * 1000).round()));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    if (_isVisible) {
      widget.player.pause();
    }
    super.dispose();
  }

  Future<void> _loadVideoEdit() async {
    _feedService.getVideoEdits(widget.video.id).listen((videoEdit) {
      if (mounted) {
        setState(() {
          _videoEdit = videoEdit;
          _isChapterListExpanded = false;
        });
        
        // If we have trim points, seek to start point
        if (videoEdit?.trimStartTime != null && widget.player.state.playing) {
          widget.player.seek(Duration(milliseconds: (videoEdit!.trimStartTime! * 1000).round()));
        }
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
            // Title section
            Expanded(
              flex: 2,
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

            // Video section
            Expanded(
              flex: 6,
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.video.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!widget.player.state.playing)
                        Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.play_arrow, color: Colors.white70, size: 64),
                          ),
                        ),
                      mk.Video(
                        controller: widget.controller,
                        controls: null,
                      ),
                      // Add drawing layer
                      if (_videoEdit != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: SimpleDrawingPainter(
                              strokes: _videoEdit!.drawings,
                              currentTime: _currentPosition,
                              currentStroke: null,  // No current stroke in playback
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      if (_videoEdit != null)
                        ..._videoEdit!.textOverlays
                            .where((overlay) =>
                                overlay.startTime <= _currentPosition &&
                                overlay.endTime >= _currentPosition)
                            .map(
                              (overlay) => Positioned(
                                left: 0,
                                right: 0,
                                bottom: 50,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Text(
                                      overlay.text,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      GestureDetector(
                        onTap: () {
                          if (widget.player.state.playing) {
                            widget.player.pause();
                          } else {
                            widget.player.play();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Chapters section
            if (_videoEdit?.chapters.isNotEmpty == true)
              Expanded(
                flex: 2,
                child: VideoChapterList(
                  chapters: _videoEdit!.chapters,
                  currentPosition: _currentPosition,
                  onSeek: (timestamp) {
                    widget.player.seek(Duration(milliseconds: (timestamp * 1000).round()));
                  },
                  isExpanded: _isChapterListExpanded,
                  onToggleExpanded: () {
                    setState(() {
                      _isChapterListExpanded = !_isChapterListExpanded;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
} 