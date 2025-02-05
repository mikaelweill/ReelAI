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
    final doc = await _firestore
        .collection('video_edits')
        .doc(widget.video.id)
        .get();
    
    if (doc.exists) {
      setState(() {
        _videoEdit = VideoEdit.fromJson(doc.data()!);
      });
    } else {
      setState(() {
        _videoEdit = VideoEdit(
          videoId: widget.video.id,
          textOverlays: [],
          chapters: [],
          lastModified: DateTime.now(),
        );
      });
    }
  }

  Future<void> _saveVideoEdit() async {
    if (_videoEdit == null) return;

    await _firestore
        .collection('video_edits')
        .doc(widget.video.id)
        .set(_videoEdit!.toJson());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully')),
      );
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
              onPressed: () {
                if (title.isNotEmpty) {
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
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.all(8),
                ),
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