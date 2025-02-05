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
  bool _isChapterListExpanded = false;
  bool _isTextOverlayListExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.video.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      })
      ..addListener(_videoListener);
    _initializeVideoPlayerFuture = _controller.initialize();
    
    print('Initializing video edit with ID: ${widget.video.id}');
    // Initialize _videoEdit immediately with empty state
    _videoEdit = VideoEdit(
      videoId: widget.video.id,
      textOverlays: [],
      chapters: [],
      captions: [],
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
      if (widget.video.id.isEmpty) {
        print('Error: Video ID is empty');
        return;
      }

      final doc = await _firestore
          .collection('video_edits')
          .doc(widget.video.id)
          .get();
      
      if (doc.exists) {
        print('Found existing video edit document');
        final data = doc.data()!;
        // Ensure videoId is set correctly when loading existing document
        data['videoId'] = widget.video.id;
        setState(() {
          _videoEdit = VideoEdit.fromJson(data);
        });
      } else {
        print('No existing video edit document found, using empty state');
        // Ensure videoId is set correctly in empty state
        setState(() {
          _videoEdit = VideoEdit(
            videoId: widget.video.id,
            textOverlays: [],
            chapters: [],
            captions: [],
            lastModified: DateTime.now(),
          );
        });
      }
    } catch (e) {
      print('Error loading video edit: $e');
      // Ensure videoId is set correctly even after error
      setState(() {
        _videoEdit = VideoEdit(
          videoId: widget.video.id,
          textOverlays: [],
          chapters: [],
          captions: [],
          lastModified: DateTime.now(),
        );
      });
    }
  }

  Future<void> _saveVideoEdit() async {
    if (_videoEdit == null) {
      print('Error: _videoEdit is null');
      return;
    }

    if (widget.video.id.isEmpty) {
      print('Error: widget.video.id is empty. Video data: ${widget.video.toJson()}');
      return;
    }

    print('\n--- Starting Save Operation ---');
    print('Video details:');
    print('- ID: ${widget.video.id}');
    print('- Title: ${widget.video.title}');
    print('- URL: ${widget.video.videoUrl}');
    
    print('\nVideoEdit details:');
    print('- VideoID: ${_videoEdit!.videoId}');
    print('- Number of chapters: ${_videoEdit!.chapters.length}');
    print('- Chapters: ${_videoEdit!.chapters.map((c) => '${c.title}@${c.timestamp}s').join(', ')}');

    try {
      // Create a new VideoEdit with updated timestamp
      final updatedEdit = VideoEdit(
        videoId: widget.video.id, // Ensure we use the widget's video ID
        textOverlays: _videoEdit!.textOverlays,
        chapters: _videoEdit!.chapters,
        captions: _videoEdit!.captions,
        lastModified: DateTime.now(),
      );

      final docRef = _firestore
          .collection('video_edits')
          .doc(widget.video.id);
          
      print('\nSaving to Firestore:');
      print('- Collection: video_edits');
      print('- Document path: ${docRef.path}');
      print('- Data to save: ${updatedEdit.toJson()}');

      await docRef.set(updatedEdit.toJson());

      print('\nSave successful!');
      setState(() {
        _videoEdit = updatedEdit;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e, stackTrace) {
      print('\nError saving to Firestore:');
      print('- Error: $e');
      print('- Stack trace:\n$stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
    print('--- End Save Operation ---\n');
  }

  void _addTextOverlay({TextOverlay? existingOverlay}) {
    final currentTime = existingOverlay?.startTime ?? _currentPosition;
    String text = existingOverlay?.text ?? '';
    double duration = existingOverlay != null 
        ? existingOverlay.endTime - existingOverlay.startTime 
        : 3.0;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingOverlay != null ? 'Edit Text Overlay' : 'Add Text Overlay'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: text)..selection = TextSelection.fromPosition(
                      TextPosition(offset: text.length),
                    ),
                    onChanged: (value) => text = value,
                    decoration: const InputDecoration(
                      hintText: 'Enter text',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Duration: ${duration.toStringAsFixed(1)}s'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: duration,
                          min: 1.0,
                          max: 10.0,
                          divisions: 18,
                          onChanged: (value) {
                            setDialogState(() {
                              duration = value;
                            });
                          },
                        ),
                      ),
                    ],
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
                    if (text.isNotEmpty) {
                      setState(() {
                        if (existingOverlay != null) {
                          // Remove existing overlay
                          _videoEdit?.textOverlays.removeWhere(
                            (overlay) => overlay.id == existingOverlay.id
                          );
                        }
                        // Add new or updated overlay
                        _videoEdit?.textOverlays.add(
                          TextOverlay(
                            id: existingOverlay?.id ?? _uuid.v4(),
                            text: text,
                            startTime: currentTime,
                            endTime: currentTime + duration,
                            top: 0.5,
                            left: 0.5,
                            style: 'default',
                          ),
                        );
                      });
                      Navigator.pop(context);
                      await _saveVideoEdit();
                    }
                  },
                  child: Text(existingOverlay != null ? 'Save' : 'Add'),
                ),
              ],
            );
          },
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
                                left: 0,
                                right: 0,
                                bottom: 50, // Add some padding from bottom
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    child: Text(
                                      overlay.text,
                                      textAlign: TextAlign.center,
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
                        onPressed: () => _addTextOverlay(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add),
                        onPressed: _addChapterMark,
                      ),
                    ],
                  ),
                ),
                if (_videoEdit != null && (_videoEdit!.chapters.isNotEmpty || _videoEdit!.textOverlays.isNotEmpty))
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Chapters section
                          if (_videoEdit!.chapters.isNotEmpty)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Chapter header with expand/collapse
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _isChapterListExpanded = !_isChapterListExpanded;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.bookmark, size: 16, color: Colors.white70),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Chapters (${_videoEdit!.chapters.length})',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _isChapterListExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Chapter list (collapsible)
                                if (_isChapterListExpanded)
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: _videoEdit!.chapters.length,
                                      itemBuilder: (context, index) {
                                        final sortedChapters = _videoEdit!.chapters.toList()
                                          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
                                        
                                        _videoEdit!.chapters.clear();
                                        _videoEdit!.chapters.addAll(sortedChapters);
                                        
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
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Delete Chapter?'),
                                                  content: Text('Are you sure you want to delete "${chapter.title}"?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          _videoEdit!.chapters.remove(chapter);
                                                        });
                                                        _saveVideoEdit();
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          onTap: () {
                                            _controller.seekTo(
                                              Duration(
                                                milliseconds: (chapter.timestamp * 1000).round(),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          
                          // Text Overlays section
                          if (_videoEdit!.textOverlays.isNotEmpty)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text overlay header with expand/collapse
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _isTextOverlayListExpanded = !_isTextOverlayListExpanded;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.text_fields, size: 16, color: Colors.white70),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Text Overlays (${_videoEdit!.textOverlays.length})',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _isTextOverlayListExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Text overlay list (collapsible)
                                if (_isTextOverlayListExpanded)
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: _videoEdit!.textOverlays.length,
                                      itemBuilder: (context, index) {
                                        final sortedOverlays = _videoEdit!.textOverlays.toList()
                                          ..sort((a, b) => a.startTime.compareTo(b.startTime));
                                        
                                        _videoEdit!.textOverlays.clear();
                                        _videoEdit!.textOverlays.addAll(sortedOverlays);
                                        
                                        final overlay = _videoEdit!.textOverlays[index];
                                        final isActive = _currentPosition >= overlay.startTime && 
                                                       _currentPosition <= overlay.endTime;
                                        
                                        return ListTile(
                                          leading: Icon(
                                            Icons.text_fields,
                                            color: isActive ? Colors.white : Colors.white38,
                                          ),
                                          title: Text(
                                            overlay.text,
                                            style: TextStyle(
                                              color: isActive ? Colors.white : Colors.white70,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${overlay.startTime.toStringAsFixed(1)}s - ${overlay.endTime.toStringAsFixed(1)}s',
                                            style: TextStyle(
                                              color: isActive ? Colors.white70 : Colors.white38,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.white70),
                                                onPressed: () => _addTextOverlay(existingOverlay: overlay),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Delete Text Overlay?'),
                                                      content: Text('Are you sure you want to delete "${overlay.text}"?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: const Text('Cancel'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              _videoEdit!.textOverlays.remove(overlay);
                                                            });
                                                            _saveVideoEdit();
                                                            Navigator.pop(context);
                                                          },
                                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            _controller.seekTo(
                                              Duration(
                                                milliseconds: (overlay.startTime * 1000).round(),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
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