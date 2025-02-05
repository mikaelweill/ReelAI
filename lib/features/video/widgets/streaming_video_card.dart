import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_feed_service.dart';

class StreamingVideoCard extends StatefulWidget {
  final Video video;
  final bool showPrivacyControls;
  final VoidCallback? onDelete;
  final Function(bool)? onVisibilityChanged;

  const StreamingVideoCard({
    super.key,
    required this.video,
    this.showPrivacyControls = false,
    this.onDelete,
    this.onVisibilityChanged,
  });

  @override
  State<StreamingVideoCard> createState() => _StreamingVideoCardState();
}

class _StreamingVideoCardState extends State<StreamingVideoCard> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  final VideoFeedService _feedService = VideoFeedService();
  bool _isVisible = false;
  bool _isBuffering = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final videoUrl = widget.video.streamingUrls?.hls ?? widget.video.videoUrl;
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      // Listen for buffering updates
      _videoPlayerController.addListener(_onVideoControllerUpdate);
      
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: true,
        aspectRatio: widget.video.aspectRatio,
        showControls: false,
        maxScale: 1.0,
        allowedScreenSleep: true,
        placeholder: _buildPlaceholder(),
      );

      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    }
  }

  void _onVideoControllerUpdate() {
    final buffered = _videoPlayerController.value.buffered;
    final isBuffering = buffered.isEmpty || 
        buffered.first.end < _videoPlayerController.value.position + const Duration(seconds: 1);
        
    if (_isBuffering != isBuffering && mounted) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }
  }

  Widget _buildPlaceholder() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.video.thumbnailUrl?.isNotEmpty == true)
          Image.network(
            widget.video.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => 
                const SizedBox(),
          ),
        if (_isBuffering)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _videoPlayerController.removeListener(_onVideoControllerUpdate);
    _videoPlayerController.pause();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(bool isVisible) {
    if (_isVisible != isVisible) {
      _isVisible = isVisible;
      if (isVisible) {
        _videoPlayerController.play();
      } else {
        _videoPlayerController.pause();
      }
      widget.onVisibilityChanged?.call(isVisible);
    }
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
    return Card(
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
              child: VisibilityDetector(
                key: Key(widget.video.id),
                onVisibilityChanged: (info) => 
                    _handleVisibilityChanged(info.visibleFraction > 0.7),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_chewieController != null)
                      Chewie(controller: _chewieController!)
                    else
                      _buildPlaceholder(),
                    if (_isBuffering)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
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
                    if (widget.showPrivacyControls || widget.onDelete != null)
                      Row(
                        children: [
                          if (widget.showPrivacyControls)
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
                            GestureDetector(
                              onTap: widget.onDelete,
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.grey[400],
                                size: 20,
                              ),
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
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 