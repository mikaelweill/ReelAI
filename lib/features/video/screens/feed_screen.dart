import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video_feed_service.dart';
import '../widgets/video_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final VideoFeedService _feedService = VideoFeedService();
  final Map<String, VideoPlayerController> _controllers = {};
  static const int _maxControllers = 3;  // Maximum number of active controllers

  @override
  void dispose() {
    try {
      for (var controller in _controllers.values) {
        if (controller.value.isInitialized) {
          controller.dispose();
        }
      }
      _controllers.clear();
    } catch (e) {
      print('Error disposing controllers: $e');
    }
    super.dispose();
  }

  Future<VideoPlayerController?> _getController(String videoUrl) async {
    try {
      // Return existing controller if available
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
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
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

  Future<void> _disposeController(String videoUrl) async {
    try {
      final controller = _controllers.remove(videoUrl);
      if (controller != null) {
        print('Disposing controller for: $videoUrl');
        await controller.pause();
        await controller.dispose();
      }
    } catch (e) {
      print('Error disposing controller: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Video Feed',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<Video>>(
        stream: _feedService.getAllVideos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final videos = snapshot.data!;
          if (videos.isEmpty) {
            return const Center(
              child: Text('No videos available', style: TextStyle(color: Colors.white)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: videos.length,
            cacheExtent: 0, // Disable caching to better control video loading
            itemBuilder: (context, index) {
              final video = videos[index];
              return FutureBuilder<VideoPlayerController?>(
                future: _getController(video.videoUrl),
                builder: (context, controllerSnapshot) {
                  if (!controllerSnapshot.hasData || controllerSnapshot.data == null) {
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
                            const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return VideoCard(
                    video: video,
                    controller: controllerSnapshot.data!,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 