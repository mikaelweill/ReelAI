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
      for (var controller in _controllers.values) {
        if (controller != null && controller.value.isInitialized) {
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
      if (_controllers.containsKey(videoUrl)) {
        return _controllers[videoUrl];
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      await controller.setLooping(true);
      _controllers[videoUrl] = controller;
      return controller;
    } catch (e) {
      print('Error initializing video controller: $e');
      return null;
    }
  }

  void _disposeController(String videoUrl) {
    try {
      final controller = _controllers.remove(videoUrl);
      if (controller != null && controller.value.isInitialized) {
        controller.pause();
        controller.dispose();
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