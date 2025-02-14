import 'package:flutter/material.dart';
import '../services/video_feed_service.dart';
import '../widgets/video_feed.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final GlobalKey<VideoFeedState> _videoFeedKey = GlobalKey<VideoFeedState>();

  void pauseVideos() {
    _videoFeedKey.currentState?.pauseAllVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: VideoFeed(
        key: _videoFeedKey,
        videoStream: VideoFeedService().getAllVideos(),
        emptyMessage: 'No videos available in the feed',
      ),
    );
  }
} 