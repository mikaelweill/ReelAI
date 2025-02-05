import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video_feed_service.dart';
import 'video_card.dart';

class VideoFeed extends StatefulWidget {
  final Stream<List<Video>> videoStream;
  final bool showPrivacyControls;
  final bool allowDeletion;
  final VoidCallback? onVideoDeleted;
  final String? emptyMessage;
  
  const VideoFeed({
    super.key,
    required this.videoStream,
    this.showPrivacyControls = false,
    this.allowDeletion = false,
    this.onVideoDeleted,
    this.emptyMessage,
  });

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> {
  final Map<String, VideoPlayerController> _controllers = {};
  static const int _maxControllers = 3;
  String? _currentlyPlayingUrl;
  final Map<String, bool> _bufferingStates = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _disposeController(String videoUrl) async {
    try {
      final controller = _controllers.remove(videoUrl);
      if (controller != null) {
        controller.removeListener(() => _onVideoControllerUpdate(videoUrl));
        await controller.pause();
        await controller.dispose();
      }
      if (_currentlyPlayingUrl == videoUrl) {
        _currentlyPlayingUrl = null;
      }
      _bufferingStates.remove(videoUrl);
    } catch (e) {
      print('Error disposing controller: $e');
    }
  }

  Future<VideoPlayerController?> _getController(String videoUrl) async {
    try {
      if (_controllers.containsKey(videoUrl)) {
        return _controllers[videoUrl];
      }

      // Clean up old controllers if we have too many
      if (_controllers.length >= _maxControllers) {
        final oldestUrl = _controllers.keys.first;
        await _disposeController(oldestUrl);
      }

      print('Initializing video controller for: $videoUrl');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      // Add buffering listener
      controller.addListener(() => _onVideoControllerUpdate(videoUrl));
      _bufferingStates[videoUrl] = true;
      
      try {
        await controller.initialize();
        await controller.setLooping(true);
        _controllers[videoUrl] = controller;
        print('Successfully initialized video: $videoUrl');
        return controller;
      } catch (initError) {
        print('Error initializing specific video: $initError');
        await controller.dispose();
        return null;
      }
    } catch (e) {
      print('Error in _getController: $e');
      return null;
    }
  }

  void _onVideoControllerUpdate(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller == null) return;

    final buffered = controller.value.buffered;
    final isBuffering = buffered.isEmpty || 
        buffered.first.end < controller.value.position + const Duration(seconds: 1);
    
    if (_bufferingStates[videoUrl] != isBuffering && mounted) {
      setState(() {
        _bufferingStates[videoUrl] = isBuffering;
      });
    }
  }

  Widget _buildVideoPlaceholder(Video video, bool isBuffering) {
    return Container(
      color: Colors.black,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: AspectRatio(
        aspectRatio: video.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbnailUrl?.isNotEmpty == true)
              Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            if (isBuffering)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void onVideoVisibilityChanged(String videoUrl, bool isVisible) async {
    if (!mounted) return;

    final controller = _controllers[videoUrl];
    if (controller == null) return;

    if (isVisible) {
      // Pause any currently playing video
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != videoUrl) {
        final currentController = _controllers[_currentlyPlayingUrl];
        if (currentController != null) {
          await currentController.pause();
        }
      }
      // Play the new video
      _currentlyPlayingUrl = videoUrl;
      await controller.play();
    } else if (_currentlyPlayingUrl == videoUrl) {
      // Pause if this video was playing and is now hidden
      await controller.pause();
      _currentlyPlayingUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Video>>(
      stream: widget.videoStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final videos = snapshot.data!;
        if (videos.isEmpty) {
          return Center(
            child: Text(
              widget.emptyMessage ?? 'No videos available',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: videos.length,
          cacheExtent: 0,
          itemBuilder: (context, index) {
            final video = videos[index];
            
            return FutureBuilder<VideoPlayerController?>(
              future: _getController(video.videoUrl),
              builder: (context, controllerSnapshot) {
                if (!controllerSnapshot.hasData || controllerSnapshot.data == null) {
                  return _buildVideoPlaceholder(
                    video, 
                    _bufferingStates[video.videoUrl] ?? true
                  );
                }

                return Stack(
                  children: [
                    VideoCard(
                      video: video,
                      controller: controllerSnapshot.data!,
                      onVisibilityChanged: (isVisible) => 
                          onVideoVisibilityChanged(video.videoUrl, isVisible),
                      showPrivacyIndicator: widget.showPrivacyControls,
                      onDelete: widget.allowDeletion 
                          ? () {
                              VideoFeedService().deleteVideo(video.id);
                              widget.onVideoDeleted?.call();
                            }
                          : null,
                    ),
                    if (_bufferingStates[video.videoUrl] ?? false)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black26,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
} 