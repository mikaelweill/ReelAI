import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../models/video.dart';
import '../models/video_edit.dart';

class VideoEditor extends StatefulWidget {
  final Video video;

  const VideoEditor({
    super.key,
    required this.video,
  });

  @override
  State<VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends State<VideoEditor> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  final _firestore = FirebaseFirestore.instance;
  
  VideoEdit? _videoEdit;
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.video.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      })
      ..addListener(_videoListener);
    _initializeVideoPlayerFuture = _controller.initialize();
    // Initialize _videoEdit immediately with empty state
    _videoEdit = VideoEdit(
      videoId: widget.video.id,
      textOverlays: [],
      chapters: [],
      lastModified: DateTime.now(),
    );
    // Then load any existing edits
    _loadVideoEdit();
  }

  void _videoListener() {
    if (_controller.value.isInitialized) {
      setState(() {
        _currentPosition = _controller.value.position.inMilliseconds / 1000;
      });
    }
  }

  Future<void> _loadVideoEdit() async {
    try {
      print('Loading video edit for video ID: ${widget.video.id}');
      final doc = await _firestore
          .collection('video_edits')
          .doc(widget.video.id)
          .get();
      
      if (doc.exists) {
        print('Found existing video edit document');
        setState(() {
          _videoEdit = VideoEdit.fromJson(doc.data()!);
        });
      } else {
        print('No existing video edit document found, using empty state');
        // _videoEdit is already initialized with empty state in initState
      }
    } catch (e) {
      print('Error loading video edit: $e');
      // _videoEdit will remain as initialized in initState
    }
  }

  Future<void> _saveVideoEdit() async {
    if (_videoEdit == null) {
      print('Error: _videoEdit is null');
      return;
    }

    // Update lastModified before saving
    _videoEdit = VideoEdit(
      videoId: _videoEdit!.videoId,
      textOverlays: _videoEdit!.textOverlays,
      chapters: _videoEdit!.chapters,
      lastModified: DateTime.now(),
    );

    print('Starting save operation...');
    print('Video ID from widget: ${widget.video.id}');
    print('Video ID from _videoEdit: ${_videoEdit!.videoId}');
    print('Number of chapters: ${_videoEdit!.chapters.length}');
    print('Video edit data: ${_videoEdit!.toJson()}');
    
    try {
      final docRef = _firestore
          .collection('video_edits')
          .doc(widget.video.id);
          
      print('Saving to document: ${docRef.path}');
      await docRef.set(_videoEdit!.toJson());

      print('Save successful');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e, stackTrace) {
      print('Error saving video edit: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    }
  }

  void _addTextOverlay() {
    final currentTime = _currentPosition;
    showDialog(
      context: context,
      builder: (context) {
        String text = '';
        return AlertDialog(
          title: const Text('Add Text Overlay'),
          content: TextField(
            onChanged: (value) => text = value,
            decoration: const InputDecoration(
              hintText: 'Enter text',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (text.isNotEmpty) {
                  setState(() {
                    _videoEdit?.textOverlays.add(
                      TextOverlay(
                        id: _uuid.v4(),
                        text: text,
                        startTime: currentTime,
                        endTime: currentTime + 3.0, // Default 3 second duration
                        top: 0.5,
                        left: 0.5,
                        style: 'default',
                      ),
                    );
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addChapterMark() {
    final currentTime = _currentPosition;
    showDialog(
      context: context,
      builder: (context) {
        String title = '';
        String? description;
        return AlertDialog(
          title: const Text('Add Chapter Mark'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) => title = value,
                decoration: const InputDecoration(
                  hintText: 'Chapter title',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => description = value,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (title.isNotEmpty) {
                  print('Adding chapter and preparing to save...');
                  setState(() {
                    _videoEdit?.chapters.add(
                      ChapterMark(
                        id: _uuid.v4(),
                        title: title,
                        timestamp: currentTime,
                        description: description,
                      ),
                    );
                  });
                  print('Added chapter mark at ${currentTime}s');
                  print('Current number of chapters: ${_videoEdit?.chapters.length}');
                  Navigator.pop(context);
                  // Call save after dialog is closed
                  await _saveVideoEdit();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildScrubber() {
    final duration = _controller.value.duration;
    final totalMillis = duration.inMilliseconds.toDouble();
    
    return Column(
      children: [
        // Time display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_controller.value.position),
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        // Slider with Chapter Markers
        SizedBox(
          height: 40, // Explicit height for the slider area
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Chapter Markers
              if (_videoEdit != null && _videoEdit!.chapters.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChapterMarkerPainter(
                      chapters: _videoEdit!.chapters,
                      duration: totalMillis,
                      currentPosition: _controller.value.position.inMilliseconds.toDouble(),
                    ),
                  ),
                ),
              // Main Slider
              SliderTheme(
                data: SliderThemeData(
                  thumbColor: Colors.white,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: _controller.value.position.inMilliseconds.toDouble(),
                  min: 0.0,
                  max: totalMillis,
                  onChanged: (value) {
                    final Duration newPosition = Duration(milliseconds: value.round());
                    _controller.seekTo(newPosition);
                  },
                ),
              ),
              // Chapter Titles (show when near marker)
              if (_videoEdit != null)
                ..._buildChapterLabels(totalMillis),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChapterLabels(double totalDuration) {
    const double showThreshold = 0.05; // Show label when within 5% of chapter
    final currentPos = _controller.value.position.inMilliseconds.toDouble();
    
    return _videoEdit!.chapters.map((chapter) {
      final chapterPos = chapter.timestamp * 1000;
      final distance = (currentPos - chapterPos).abs() / totalDuration;
      
      // Only show label when scrubbing near the chapter
      if (distance > showThreshold) return const SizedBox.shrink();
      
      // Calculate position for the label
      final position = chapterPos / totalDuration;
      
      return Positioned(
        left: position * MediaQuery.of(context).size.width,
        bottom: 20, // Position above the slider
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            chapter.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveVideoEdit,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (_videoEdit != null)
                        ..._videoEdit!.textOverlays
                            .where((overlay) =>
                                overlay.startTime <= _currentPosition &&
                                overlay.endTime >= _currentPosition)
                            .map(
                              (overlay) => Positioned(
                                top: overlay.top * _controller.value.size.height,
                                left: overlay.left * _controller.value.size.width,
                                child: Text(
                                  overlay.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 4,
                                        color: Colors.black,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPlaying = !_isPlaying;
                            _isPlaying
                                ? _controller.play()
                                : _controller.pause();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                _buildScrubber(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          setState(() {
                            _isPlaying = !_isPlaying;
                            _isPlaying
                                ? _controller.play()
                                : _controller.pause();
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_fields),
                        onPressed: _addTextOverlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add),
                        onPressed: _addChapterMark,
                      ),
                    ],
                  ),
                ),
                if (_videoEdit != null && _videoEdit!.chapters.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _videoEdit!.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = _videoEdit!.chapters[index];
                        return ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(chapter.title),
                          subtitle: Text(
                            '${chapter.timestamp.toStringAsFixed(1)}s' +
                                (chapter.description != null
                                    ? ' - ${chapter.description}'
                                    : ''),
                          ),
                          onTap: () {
                            _controller.seekTo(
                              Duration(
                                milliseconds:
                                    (chapter.timestamp * 1000).round(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ChapterMarkerPainter extends CustomPainter {
  final List<ChapterMark> chapters;
  final double duration;
  final double currentPosition;

  ChapterMarkerPainter({
    required this.chapters,
    required this.duration,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final chapter in chapters) {
      final position = (chapter.timestamp * 1000) / duration;
      final x = position * size.width;
      
      // Draw marker line
      canvas.drawRect(
        Rect.fromLTWH(x - 1, 0, 2, size.height),
        paint,
      );
      
      // Draw dot at top
      canvas.drawCircle(
        Offset(x, size.height / 2),
        3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ChapterMarkerPainter oldDelegate) =>
      currentPosition != oldDelegate.currentPosition;
} 