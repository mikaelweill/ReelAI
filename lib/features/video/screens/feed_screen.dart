import 'package:flutter/material.dart';
import '../services/video_feed_service.dart';
import '../widgets/video_feed.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: VideoFeed(
        videoStream: VideoFeedService().getAllVideos(),
        emptyMessage: 'No videos available in the feed',
      ),
    );
  }
} 