import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../video/services/video_feed_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VideoFeedService _feedService = VideoFeedService();
  final Map<String, VideoPlayerController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<VideoPlayerController> _getController(String videoUrl) async {
    if (_controllers.containsKey(videoUrl)) {
      return _controllers[videoUrl]!;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controllers[videoUrl] = controller;
    await controller.initialize();
    await controller.setLooping(true);
    return controller;
  }

  Widget _buildVideoCard(Video video, VideoPlayerController controller) {
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
              aspectRatio: video.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  IconButton(
                    icon: Icon(
                      controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 50,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
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
                  video.title?.isNotEmpty == true 
                    ? video.title! 
                    : 'Untitled Video',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Created: ${_formatDate(video.createdAt)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[400],
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _feedService.deleteVideo(video.id),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Videos'),
        elevation: 0,
      ),
      body: StreamBuilder<List<Video>>(
        stream: _feedService.getUserVideos(),
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
              child: Text('No videos yet. Create your first video!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return FutureBuilder<VideoPlayerController>(
                future: _getController(video.videoUrl),
                builder: (context, controllerSnapshot) {
                  if (!controllerSnapshot.hasData) {
                    return const Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  return _buildVideoCard(video, controllerSnapshot.data!);
                },
              );
            },
          );
        },
      ),
    );
  }
} 