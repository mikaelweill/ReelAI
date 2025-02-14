import 'package:flutter/material.dart';
import '../../video/services/video_feed_service.dart';
import '../../video/widgets/video_feed.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final VideoFeedService _feedService = VideoFeedService();
  final GlobalKey<VideoFeedState> _videoFeedKey = GlobalKey<VideoFeedState>();
  String _currentFilter = 'all';  // Track current filter state

  @override
  bool get wantKeepAlive => true;

  void pauseVideos() {
    _videoFeedKey.currentState?.pauseAllVideos();
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
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
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
            child: VideoFeed(
              key: _videoFeedKey,
              videoStream: _getFilteredVideos(),
              showPrivacyControls: true,
              allowDeletion: true,
              emptyMessage: 'No videos yet. Create your first video!',
              shouldAutoPlay: false,
            ),
          ),
        ],
      ),
    );
  }
} 