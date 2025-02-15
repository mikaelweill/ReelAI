import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import '../services/video_feed_service.dart';
import 'video_card.dart';

class VideoFeed extends StatefulWidget {
  final Stream<List<Video>> videoStream;
  final bool showPrivacyControls;
  final bool allowDeletion;
  final VoidCallback? onVideoDeleted;
  final String? emptyMessage;
  final bool shouldAutoPlay;
  
  const VideoFeed({
    super.key,
    required this.videoStream,
    this.showPrivacyControls = false,
    this.allowDeletion = false,
    this.onVideoDeleted,
    this.emptyMessage,
    this.shouldAutoPlay = true,
  });

  @override
  State<VideoFeed> createState() => VideoFeedState();
}

class VideoFeedState extends State<VideoFeed> {
  final Map<String, Player> _players = {};
  final Map<String, mk.VideoController> _controllers = {};
  static const int _maxControllers = 3;
  String? _currentlyPlayingUrl;
  final Map<String, bool> _bufferingStates = {};
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  List<Video> _videos = [];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPageIndex && mounted) {
      setState(() {
        _currentPageIndex = page;
      });
    }
  }

  void _performSearch(String query, List<Video> videos) {
    if (_currentPageIndex >= videos.length) return;
    
    final currentVideo = videos[_currentPageIndex];
    final player = _players[currentVideo.videoUrl];
    if (player == null) return;

    // Get video edit for current video
    final videoEdit = VideoFeedService().getVideoEdits(currentVideo.id).first;
    videoEdit.then((edit) {
      if (edit == null || edit.captions.isEmpty) {
        print('No captions found for video ${currentVideo.id}');
        return;
      }

      if (query.isEmpty) {
        print('Empty query');
        return;
      }

      // Search through captions
      final matches = edit.captions.where(
        (caption) => caption.text.toLowerCase().contains(query.toLowerCase())
      ).toList();

      print('Found ${matches.length} matches in video ${currentVideo.id}');
      
      if (matches.isNotEmpty) {
        // Jump to first match
        final firstMatch = matches.first;
        player.seek(Duration(milliseconds: (firstMatch.startTime * 1000).round()));
        print('Jumped to ${firstMatch.startTime}s: "${firstMatch.text}"');
      }
    });
  }

  void pauseAllVideos() {
    // Pause all active players
    for (var player in _players.values) {
      player.pause();
    }
    _currentlyPlayingUrl = null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _controllers.clear();
    super.dispose();
  }

  Future<void> _disposeController(String videoUrl) async {
    try {
      final player = _players.remove(videoUrl);
      final controller = _controllers.remove(videoUrl);
      if (player != null) {
        await player.dispose();
      }
      if (_currentlyPlayingUrl == videoUrl) {
        _currentlyPlayingUrl = null;
      }
      _bufferingStates.remove(videoUrl);
    } catch (e) {
      print('Error disposing controller: $e');
    }
  }

  Future<mk.VideoController?> _getController(String videoUrl) async {
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
      
      // Create a new player instance
      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 32 * 1024 * 1024, // 32MB buffer
        ),
      );
      
      // Create the video controller
      final controller = mk.VideoController(player);
      
      _bufferingStates[videoUrl] = true;
      
      try {
        // Open the media source
        await player.open(Media(videoUrl));
        await player.setPlaylistMode(PlaylistMode.loop);
        
        // Store references
        _players[videoUrl] = player;
        _controllers[videoUrl] = controller;
        
        // Add state listener
        player.stream.buffering.listen((buffering) {
          if (mounted) {
            setState(() {
              _bufferingStates[videoUrl] = buffering;
            });
          }
        });
        
        print('Successfully initialized video: $videoUrl');
        return controller;
      } catch (initError) {
        print('Error initializing specific video: $initError');
        await player.dispose();
        return null;
      }
    } catch (e) {
      print('Error in _getController: $e');
      return null;
    }
  }

  void onVideoVisibilityChanged(String videoUrl, bool isVisible) async {
    if (!mounted) return;

    final player = _players[videoUrl];
    if (player == null) return;

    if (isVisible && widget.shouldAutoPlay) {  // Only auto-play if shouldAutoPlay is true
      // Pause any currently playing video
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != videoUrl) {
        final currentPlayer = _players[_currentlyPlayingUrl];
        if (currentPlayer != null) {
          await currentPlayer.pause();
        }
      }
      // Play the new video
      _currentlyPlayingUrl = videoUrl;
      await player.play();
    } else if (_currentlyPlayingUrl == videoUrl) {
      // Pause if this video was playing and is now hidden
      await player.pause();
      _currentlyPlayingUrl = null;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Box
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search in current video...',
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (query) {
              _performSearch(query, _videos);
            },
          ),
        ),
        // Video Feed
        Expanded(
          child: StreamBuilder<List<Video>>(
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

              _videos = snapshot.data!;
              if (_videos.isEmpty) {
                return Center(
                  child: Text(
                    widget.emptyMessage ?? 'No videos available',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              return PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  
                  return FutureBuilder<mk.VideoController?>(
                    future: _getController(video.videoUrl),
                    builder: (context, controllerSnapshot) {
                      if (!controllerSnapshot.hasData || controllerSnapshot.data == null) {
                        return SizedBox.expand(
                          child: _buildVideoPlaceholder(
                            video, 
                            _bufferingStates[video.videoUrl] ?? true
                          ),
                        );
                      }

                      return SizedBox.expand(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            mk.Video(controller: controllerSnapshot.data!),
                            VideoCard(
                              video: video,
                              controller: controllerSnapshot.data!,
                              player: _players[video.videoUrl]!,
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
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
} 
