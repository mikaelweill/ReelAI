import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/video_feed_service.dart';
import '../services/video_enhancements_service.dart';
import '../../studio/models/video_edit.dart';
import '../../studio/widgets/drawing_painter.dart';
import 'video_chapter_list.dart';
import 'transcript_search_box.dart';

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
  final VideoEnhancementsService _enhancementsService = VideoEnhancementsService();
  bool _isVisible = false;
  bool _isChapterListExpanded = false;
  VideoEdit? _videoEdit;
  VideoEnhancements? _enhancements;
  double _currentPosition = 0.0;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadVideoEdit();
    _loadEnhancements();
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
    print('\n--- Loading Video Edit ---');
    print('Video ID: ${widget.video.id}');
    
    _feedService.getVideoEdits(widget.video.id).listen((videoEdit) {
      print('Received video edit: ${videoEdit != null}');
      if (videoEdit != null) {
        print('Video edit details:');
        print('- Has captions: ${videoEdit.captions.isNotEmpty}');
        print('- Number of captions: ${videoEdit.captions.length}');
        print('- Captions enabled: ${videoEdit.isCaptionsEnabled}');
        if (videoEdit.captions.isNotEmpty) {
          print('\nFirst few captions:');
          for (var caption in videoEdit.captions.take(3)) {
            print('- "${caption.text}" (${caption.startTime}s - ${caption.startTime + caption.duration}s)');
          }
        }
      }
      
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

  Future<void> _loadEnhancements() async {
    print('Loading enhancements for video: ${widget.video.id}');
    _enhancementsService.getEnhancements(widget.video.id).listen((enhancements) {
      if (mounted) {
        print('Received enhancements: ${enhancements != null}');
        if (enhancements != null) {
          print('Number of subtitles: ${enhancements.subtitles.length}');
        }
        setState(() {
          _enhancements = enhancements;
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

  void _showInfoCard() {
    if (_videoEdit?.interactiveOverlays.isEmpty == true) return;
    
    final card = _videoEdit!.interactiveOverlays.first;
    print('Debug - Info Card Data:');
    print('Title: ${card.title}');
    print('Description: ${card.description}');
    print('URL: ${card.linkUrl}');
    print('Link Text: ${card.linkText}');
    
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          dialogBackgroundColor: Colors.transparent,
        ),
        child: AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white24,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      if (card.bulletPoints.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...card.bulletPoints.map((point) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                      if (card.linkUrl != null) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () async {
                            try {
                              String url = card.linkUrl!.trim();
                              // Add https:// if not present and no other protocol is specified
                              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                                url = 'https://$url';
                              }
                              
                              print('Attempting to launch URL: $url');
                              final uri = Uri.parse(url);
                              
                              // First check if we can launch
                              if (await canLaunchUrl(uri)) {
                                print('URL can be launched, attempting launch...');
                                final launched = await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                  webViewConfiguration: const WebViewConfiguration(
                                    enableJavaScript: true,
                                    enableDomStorage: true,
                                  ),
                                );
                                
                                if (!launched) {
                                  print('URL launch returned false');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Could not open the URL'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              } else {
                                print('canLaunchUrl returned false for $url');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('This URL cannot be opened'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              print('Error launching URL: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error opening URL: $e'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  card.linkText ?? card.linkUrl!,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white24, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCurrentCaptionText() {
    if (_videoEdit == null || _videoEdit!.captions.isEmpty) {
      return '';
    }

    final currentCaption = _videoEdit!.captions.firstWhere(
      (caption) => _currentPosition >= caption.startTime &&
                   _currentPosition <= caption.startTime + caption.duration,
      orElse: () => Caption(id: '', text: '', startTime: 0, duration: 0),
    );
    return currentCaption.text;
  }

  void _seekToTimestamp(double timestamp) {
    widget.player.seek(Duration(milliseconds: (timestamp * 1000).round()));
  }

  @override
  Widget build(BuildContext context) {
    // Debug prints for search functionality
    print('\n--- Building VideoCard ---');
    print('Video ID: ${widget.video.id}');
    print('Has video edit: ${_videoEdit != null}');
    print('Number of captions: ${_videoEdit?.captions.length ?? 0}');
    print('Show search: $_showSearch');
    
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
                        const SizedBox(width: 8),
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
                      // Add captions display
                      if (_videoEdit?.isCaptionsEnabled == true && _videoEdit?.captions.isNotEmpty == true)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 50,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getCurrentCaptionText(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
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