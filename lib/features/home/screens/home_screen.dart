import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../video/services/video_feed_service.dart';
import '../../video/widgets/video_card.dart';
import '../../auth/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VideoFeedService _feedService = VideoFeedService();
  final AuthService _authService = AuthService();
  final Map<String, VideoPlayerController> _controllers = {};
  String _currentFilter = 'all';  // Track current filter state

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

      // Clean up old controllers if we have too many
      if (_controllers.length > 5) {  // Keep only 5 videos in memory
        final oldestUrl = _controllers.keys.first;
        await _disposeController(oldestUrl);
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

  Future<void> _disposeController(String videoUrl) async {
    try {
      final controller = _controllers.remove(videoUrl);
      if (controller != null && controller.value.isInitialized) {
        await controller.pause();
        await controller.dispose();
      }
    } catch (e) {
      print('Error disposing controller: $e');
    }
  }

  // Get the filtered stream based on current filter
  Stream<List<Video>> _getFilteredVideos() {
    switch (_currentFilter) {
      case 'public':
        return _feedService.getUserVideos(isPrivate: false);
      case 'private':
        return _feedService.getUserVideos(isPrivate: true);
      case 'all':
      default:
        return _feedService.getUserVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (value) {
                    setState(() {
                      _currentFilter = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Text('All Videos'),
                    ),
                    const PopupMenuItem(
                      value: 'public',
                      child: Text('Public Only'),
                    ),
                    const PopupMenuItem(
                      value: 'private',
                      child: Text('Private Only'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Video>>(
              stream: _getFilteredVideos(),
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
                          onDelete: () => _feedService.deleteVideo(video.id),
                          showPrivacyIndicator: true,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 