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

  @override
  void dispose() {
    try {
      print('Disposing all controllers...');
      for (var entry in _controllers.entries) {
        print('Disposing controller for: ${entry.key}');
        final controller = entry.value;
        if (controller.value.isInitialized) {
          controller.pause();
          controller.dispose();
        }
      }
      _controllers.clear();
    } catch (e) {
      print('Error during feed screen disposal: $e');
    }
    super.dispose();
  }

  Future<VideoPlayerController?> _getController(String videoUrl) async {
    try {
      if (_controllers.containsKey(videoUrl)) {
        return _controllers[videoUrl];
      }

      // Clean up old controllers if we have too many
      if (_controllers.length >= 3) {  // Keep only 3 videos in memory
        final oldestUrl = _controllers.keys.first;
        await _disposeController(oldestUrl);
      }

      print('Initializing video controller for: $videoUrl');
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      
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
      appBar: AppBar(
        title: const Text('Video Feed'),
        elevation: 0,
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
              child: CircularProgressIndicator(),
            );
          }

          final videos = snapshot.data!;
          if (videos.isEmpty) {
            return const Center(
              child: Text('No videos available'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return FutureBuilder<VideoPlayerController?>(
                future: _getController(video.videoUrl),
                builder: (context, controllerSnapshot) {
                  if (!controllerSnapshot.hasData || controllerSnapshot.data == null) {
                    return const Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Center(child: CircularProgressIndicator()),
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