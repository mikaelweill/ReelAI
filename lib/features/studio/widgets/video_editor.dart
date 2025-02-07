import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../models/video.dart' as model;
import '../models/video_edit.dart';
import 'drawing_painter.dart';
import 'dart:async';
import 'dart:math';

class TrimRegionPainter extends CustomPainter {
  final double? trimStart;
  final double? trimEnd;
  final double totalDuration;

  TrimRegionPainter({
    required this.trimStart,
    required this.trimEnd,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trimStart == null || trimEnd == null) return;

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw dimmed region before trim start
    final startX = (trimStart! * 1000) * size.width / totalDuration;
    if (startX > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, startX, size.height),
        paint,
      );
    }

    // Draw dimmed region after trim end
    final endX = (trimEnd! * 1000) * size.width / totalDuration;
    if (endX < size.width) {
      canvas.drawRect(
        Rect.fromLTWH(endX, 0, size.width - endX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(TrimRegionPainter oldDelegate) =>
      trimStart != oldDelegate.trimStart ||
      trimEnd != oldDelegate.trimEnd;
}

class VideoEditor extends StatefulWidget {
  final model.Video video;

  const VideoEditor({
    super.key,
    required this.video,
  });

  @override
  State<VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends State<VideoEditor> {
  late Player _player;
  late mk.VideoController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  final _firestore = FirebaseFirestore.instance;
  
  VideoEdit? _videoEdit;
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  final _uuid = const Uuid();
  bool _isChapterListExpanded = false;
  bool _isTextOverlayListExpanded = false;
  bool _isDrawingsListExpanded = false;
  bool _isTrimMode = false;
  
  // Add save indicator state
  bool _isSaving = false;
  bool _showSaveIndicator = false;
  Timer? _saveIndicatorTimer;

  double? _tempTrimStart;
  double? _tempTrimEnd;

  // Add drawing mode state
  bool _isDrawingMode = false;
  List<Offset> _currentStroke = [];
  List<DrawingStroke> _strokes = [];
  Color _currentColor = Colors.white;
  double _currentStrokeWidth = 3.0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = mk.VideoController(_player);
    _initializeVideoPlayerFuture = _initializePlayer();
    
    print('Initializing video edit with ID: ${widget.video.id}');
    // Initialize _videoEdit immediately with empty state
    _videoEdit = VideoEdit(
      videoId: widget.video.id,
      textOverlays: [],
      chapters: [],
      captions: [],
      drawings: [],  // Initialize empty drawings list
      lastModified: DateTime.now(),
    );
    // Then load any existing edits
    _loadVideoEdit();
  }

  Future<void> _initializePlayer() async {
    await _player.open(Media(widget.video.videoUrl));
    await _player.setPlaylistMode(PlaylistMode.loop);
    
    // Set initial position to trim start if exists
    if (_videoEdit?.trimStartTime != null) {
      await _player.seek(Duration(milliseconds: (_videoEdit!.trimStartTime! * 1000).round()));
    }
    
    // Set up position listener
    _player.stream.position.listen((position) {
      if (mounted) {
        final currentPos = position.inMilliseconds / 1000.0;  // Convert to seconds
        setState(() {
          _currentPosition = currentPos;
        });

        // Handle trim boundaries during playback
        if (_videoEdit != null) {
          final trimStart = _videoEdit!.trimStartTime;
          final trimEnd = _videoEdit!.trimEndTime;
          
          if (trimEnd != null && currentPos >= trimEnd && _isPlaying) {
            // If we hit the trim end, loop back to trim start
            if (trimStart != null) {
              _player.seek(Duration(milliseconds: (trimStart * 1000).round()));
            } else {
              // If no trim start defined, go to beginning
              _player.seek(Duration.zero);
            }
          } else if (trimStart != null && currentPos < trimStart && _isPlaying) {
            // If somehow we're before trim start, seek to trim start
            _player.seek(Duration(milliseconds: (trimStart * 1000).round()));
          }
        }
      }
    });
    
    // Set up playing state listener
    _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
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
          _strokes = List.from(_videoEdit!.drawings);  // Load drawings from VideoEdit
          print('\nLoaded drawings from database:');
          print('- Number of drawings: ${_strokes.length}');
          print('- Drawings: ${_strokes.map((d) => 'id:${d.id} time:${d.startTime}-${d.endTime}s color:${d.color}').join('\n  ')}');
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
            drawings: [],  // Initialize empty drawings list
            lastModified: DateTime.now(),
          );
          _strokes = [];  // Clear strokes
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
          drawings: [],  // Initialize empty drawings list
          lastModified: DateTime.now(),
        );
        _strokes = [];  // Clear strokes
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

    setState(() {
      _isSaving = true;
      _showSaveIndicator = true;
    });

    print('\n--- Starting Save Operation ---');
    print('Video details:');
    print('- ID: ${widget.video.id}');
    print('- Title: ${widget.video.title}');
    print('- URL: ${widget.video.videoUrl}');
    
    print('\nVideoEdit details:');
    print('- VideoID: ${_videoEdit!.videoId}');
    print('- Number of chapters: ${_videoEdit!.chapters.length}');
    print('- Chapters: ${_videoEdit!.chapters.map((c) => '${c.title}@${c.timestamp}s').join(', ')}');
    print('- Trim Start: ${_videoEdit!.trimStartTime}');
    print('- Trim End: ${_videoEdit!.trimEndTime}');
    print('- Number of drawings: ${_strokes.length}');
    print('- Drawings: ${_strokes.map((d) => 'id:${d.id} time:${d.startTime}-${d.endTime}s color:${d.color}').join('\n  ')}');

    try {
      // Create a new VideoEdit with updated timestamp
      final updatedEdit = VideoEdit(
        videoId: widget.video.id, // Ensure we use the widget's video ID
        textOverlays: _videoEdit!.textOverlays,
        chapters: _videoEdit!.chapters,
        captions: _videoEdit!.captions,
        drawings: _strokes,  // Add drawings to save
        lastModified: DateTime.now(),
        trimStartTime: _videoEdit!.trimStartTime,  // Include trim start
        trimEndTime: _videoEdit!.trimEndTime,      // Include trim end
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
        _isSaving = false;
      });
      
      // Start timer to hide indicator
      _saveIndicatorTimer?.cancel();
      _saveIndicatorTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showSaveIndicator = false;
          });
        }
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
      
      setState(() {
        _isSaving = false;
        _showSaveIndicator = false;
      });
      
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

  Widget _buildTrimControls(double totalMillis) {
    return Column(
      children: [
        // Trim time indicators
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: (_tempTrimStart ?? 0 * 1000).round())),
                style: const TextStyle(color: Colors.blue),
              ),
              Text(
                _formatDuration(Duration(milliseconds: (_tempTrimEnd ?? totalMillis/1000).round())),
                style: const TextStyle(color: Colors.blue),
              ),
            ],
          ),
        ),
        // Double-ended trim slider
        SizedBox(
          height: 40,
          child: RangeSlider(
            values: RangeValues(
              _tempTrimStart ?? 0,
              _tempTrimEnd ?? totalMillis/1000,
            ),
            min: 0,
            max: totalMillis/1000,
            activeColor: Colors.blue,
            inactiveColor: Colors.white24,
            onChanged: (RangeValues values) {
              setState(() {
                _tempTrimStart = values.start;
                _tempTrimEnd = values.end;
              });
              // Seek to the current trim position
              _player.seek(Duration(milliseconds: (values.start * 1000).round()));
            },
          ),
        ),
        // Apply/Cancel buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isTrimMode = false;
                  _tempTrimStart = null;
                  _tempTrimEnd = null;
                });
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () async {
                // Update the video edit with new trim values
                if (_videoEdit != null) {
                  final updatedEdit = VideoEdit(
                    videoId: _videoEdit!.videoId,
                    textOverlays: _videoEdit!.textOverlays,
                    chapters: _videoEdit!.chapters,
                    captions: _videoEdit!.captions,
                    drawings: _strokes,
                    lastModified: DateTime.now(),
                    trimStartTime: _tempTrimStart,
                    trimEndTime: _tempTrimEnd,
                  );
                  setState(() {
                    _videoEdit = updatedEdit;
                    _isTrimMode = false;
                  });
                  await _saveVideoEdit();
                }
              },
              child: const Text('Apply Trim'),
            ),
          ],
        ),
      ],
    );
  }

  // Add this method to handle constrained seeking
  Future<void> _constrainedSeek(Duration position) async {
    if (_videoEdit?.trimStartTime != null && 
        position.inMilliseconds < _videoEdit!.trimStartTime! * 1000) {
      // If seeking before trim start, snap to trim start
      await _player.seek(Duration(milliseconds: (_videoEdit!.trimStartTime! * 1000).round()));
    } else if (_videoEdit?.trimEndTime != null && 
               position.inMilliseconds > _videoEdit!.trimEndTime! * 1000) {
      // If seeking after trim end, snap to trim end
      await _player.seek(Duration(milliseconds: (_videoEdit!.trimEndTime! * 1000).round()));
    } else {
      // Otherwise seek to requested position
      await _player.seek(position);
    }
  }

  Widget _buildScrubber() {
    final duration = _player.state.duration;
    final position = _player.state.position;
    final totalMillis = duration.inMilliseconds.toDouble();
    
    // Get the effective trim points (either temporary or saved)
    final effectiveTrimStart = _isTrimMode ? _tempTrimStart : _videoEdit?.trimStartTime;
    final effectiveTrimEnd = _isTrimMode ? _tempTrimEnd : _videoEdit?.trimEndTime;

    // Convert all values to seconds for consistent handling
    final positionInSeconds = position.inMilliseconds / 1000.0;
    final durationInSeconds = totalMillis / 1000.0;
    
    return Column(
      children: [
        // Time display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                effectiveTrimStart != null 
                  ? _formatDuration(Duration(milliseconds: (effectiveTrimStart * 1000).round()))
                  : _formatDuration(position),
                style: TextStyle(
                  color: effectiveTrimStart != null ? Colors.blue : Colors.white70,
                ),
              ),
              Text(
                effectiveTrimEnd != null
                  ? _formatDuration(Duration(milliseconds: (effectiveTrimEnd * 1000).round()))
                  : _formatDuration(duration),
                style: TextStyle(
                  color: effectiveTrimEnd != null ? Colors.blue : Colors.white70,
                ),
              ),
            ],
          ),
        ),
        // Slider with Chapter Markers
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Trim regions (dimmed areas)
              if (_videoEdit?.trimStartTime != null || _videoEdit?.trimEndTime != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: TrimRegionPainter(
                      trimStart: effectiveTrimStart,
                      trimEnd: effectiveTrimEnd,
                      totalDuration: totalMillis,
                    ),
                  ),
                ),
              // Chapter Markers
              if (_videoEdit != null && _videoEdit!.chapters.isNotEmpty)
                Positioned.fill(
                  child: CustomPaint(
                    painter: ChapterMarkerPainter(
                      chapters: _videoEdit!.chapters,
                      duration: totalMillis,
                      currentPosition: position.inMilliseconds.toDouble(),
                    ),
                  ),
                ),
              // Slider
              SliderTheme(
                data: SliderThemeData(
                  thumbColor: _isTrimMode ? Colors.blue : Colors.white,
                  activeTrackColor: _isTrimMode ? Colors.blue.withOpacity(0.5) : Colors.white,
                  inactiveTrackColor: Colors.white24,
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                    elevation: 4,
                    pressedElevation: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 6,
                    elevation: 4,
                    pressedElevation: 8,
                  ),
                ),
                child: _isTrimMode
                  ? RangeSlider(
                      values: RangeValues(
                        effectiveTrimStart ?? 0.0,
                        effectiveTrimEnd ?? durationInSeconds,
                      ),
                      min: 0.0,
                      max: durationInSeconds,
                      divisions: 100,
                      onChanged: (RangeValues values) {
                        // Validate the range
                        if (values.end - values.start >= 1.0) {  // Minimum 1 second difference
                          setState(() {
                            _tempTrimStart = values.start;
                            _tempTrimEnd = values.end;
                          });
                          _player.seek(Duration(milliseconds: (values.start * 1000).round()));
                        }
                      },
                    )
                  : Slider(
                      value: positionInSeconds,
                      min: 0.0,  // Always allow full range in normal mode
                      max: durationInSeconds,
                      onChanged: (value) {
                        final newPosition = Duration(milliseconds: (value * 1000).round());
                        _player.seek(newPosition);  // Direct seek in normal mode
                      },
                    ),
              ),
              // Chapter Titles
              if (_videoEdit != null)
                ..._buildChapterLabels(totalMillis),
            ],
          ),
        ),
        // Trim control buttons
        if (_isTrimMode)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isTrimMode = false;
                      _tempTrimStart = null;
                      _tempTrimEnd = null;
                    });
                  },
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () async {
                    if (_videoEdit != null) {
                      final updatedEdit = VideoEdit(
                        videoId: _videoEdit!.videoId,
                        textOverlays: _videoEdit!.textOverlays,
                        chapters: _videoEdit!.chapters,
                        captions: _videoEdit!.captions,
                        drawings: _strokes,
                        lastModified: DateTime.now(),
                        trimStartTime: _tempTrimStart,
                        trimEndTime: _tempTrimEnd,
                      );
                      setState(() {
                        _videoEdit = updatedEdit;
                        _isTrimMode = false;
                      });
                      await _saveVideoEdit();
                    }
                  },
                  child: const Text('Apply Trim'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildChapterLabels(double totalDuration) {
    const double showThreshold = 0.05; // Show label when within 5% of chapter
    final currentPos = _player.state.position.inMilliseconds.toDouble();
    
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

  void _toggleTrimMode() {
    setState(() {
      _isTrimMode = !_isTrimMode;
      if (_isTrimMode) {
        _tempTrimStart = _videoEdit?.trimStartTime;
        _tempTrimEnd = _videoEdit?.trimEndTime;
      } else {
        _tempTrimStart = null;
        _tempTrimEnd = null;
      }
    });
  }

  // Add color selection widget
  Widget _buildColorPicker() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final color in [
            Colors.white,
            Colors.red,
            Colors.blue,
            Colors.green,
            Colors.yellow,
            Colors.purple,
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: GestureDetector(
                onTap: () => setState(() => _currentColor = color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _currentColor == color ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add this method to build the drawings list section
  Widget _buildDrawingsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drawings header with expand/collapse
        GestureDetector(
          onTap: () => setState(() {
            _isDrawingsListExpanded = !_isDrawingsListExpanded;
          }),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.brush, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Drawings (${_strokes.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isDrawingsListExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        // Drawings list (collapsible)
        if (_isDrawingsListExpanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _strokes.length,
              itemBuilder: (context, index) {
                final sortedStrokes = _strokes.toList()
                  ..sort((a, b) => a.startTime.compareTo(b.startTime));
                
                final stroke = sortedStrokes[index];
                final isActive = _currentPosition >= stroke.startTime && 
                               _currentPosition <= stroke.endTime;
                
                return ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: stroke.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white24,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CustomPaint(
                          painter: StrokePreviewPainter(stroke: stroke),
                          size: const Size(40, 24),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    'Drawing ${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                    ),
                  ),
                  subtitle: Text(
                    '${stroke.startTime.toStringAsFixed(1)}s - ${stroke.endTime.toStringAsFixed(1)}s',
                    style: TextStyle(
                      color: isActive ? Colors.white70 : Colors.white38,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Drawing?'),
                          content: Text('Are you sure you want to delete Drawing ${index + 1}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _strokes.remove(stroke);
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
                    _player.seek(
                      Duration(
                        milliseconds: (stroke.startTime * 1000).round(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
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
                  aspectRatio: 16/9,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      mk.Video(controller: _controller),
                      // Add save indicator
                      if (_showSaveIndicator)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: AnimatedOpacity(
                            opacity: _showSaveIndicator ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSaving)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (_isSaving)
                                    const SizedBox(width: 8),
                                  Text(
                                    _isSaving ? 'Saving...' : 'Saved!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Drawing display layer (always visible)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SimpleDrawingPainter(
                            strokes: _strokes,
                            currentStroke: _currentStroke.isNotEmpty
                                ? DrawingStroke(
                                    id: 'temp',
                                    points: _currentStroke,
                                    color: _currentColor,
                                    width: _currentStrokeWidth,
                                    startTime: _currentPosition,
                                    endTime: _currentPosition + 3.0,
                                  )
                                : null,
                            currentTime: _currentPosition,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                      if (_videoEdit != null)
                        ..._videoEdit!.textOverlays
                            .where((overlay) =>
                                overlay.startTime <= _currentPosition &&
                                overlay.endTime >= _currentPosition)
                            .map(
                              (overlay) => Positioned(
                                left: 0,
                                right: 0,
                                bottom: 50,
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
                      // Drawing input layer (only in drawing mode)
                      if (_isDrawingMode)
                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: (details) {
                              setState(() {
                                _currentStroke = [details.localPosition];
                              });
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _currentStroke.add(details.localPosition);
                              });
                            },
                            onPanEnd: (_) async {
                              setState(() {
                                // Add completed stroke to strokes list
                                _strokes.add(DrawingStroke(
                                  id: _uuid.v4(),
                                  points: List.from(_currentStroke),
                                  color: _currentColor,
                                  width: _currentStrokeWidth,
                                  startTime: _currentPosition,
                                  endTime: _currentPosition + 3.0, // Default 3 second duration
                                ));
                                _currentStroke = [];
                              });
                              await _saveVideoEdit();  // Save after adding the stroke
                            },
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isPlaying = !_isPlaying;
                            _isPlaying
                                ? _player.play()
                                : _player.pause();
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
                                ? _player.play()
                                : _player.pause();
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
                      IconButton(
                        icon: const Icon(Icons.content_cut),
                        color: _isTrimMode ? Colors.blue : null,
                        onPressed: _toggleTrimMode,
                      ),
                      // Add drawing mode toggle
                      IconButton(
                        icon: const Icon(Icons.brush),
                        color: _isDrawingMode ? Colors.blue : null,
                        onPressed: () {
                          setState(() {
                            _isDrawingMode = !_isDrawingMode;
                            if (_isDrawingMode) {
                              _isTrimMode = false;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Add color picker when in drawing mode
                if (_isDrawingMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        _buildColorPicker(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.undo),
                              label: const Text('Undo'),
                              onPressed: _strokes.isNotEmpty
                                ? () => setState(() => _strokes.removeLast())
                                : null,
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear All'),
                              onPressed: _strokes.isNotEmpty
                                ? () => setState(() {
                                    _strokes.clear();
                                    _currentStroke = [];
                                  })
                                : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (_videoEdit != null && (_videoEdit!.chapters.isNotEmpty || _videoEdit!.textOverlays.isNotEmpty || _strokes.isNotEmpty))
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drawings section
                          if (_strokes.isNotEmpty)
                            _buildDrawingsList(),
                          
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
                                            _player.seek(
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
                                            _player.seek(
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
    _saveIndicatorTimer?.cancel();
    _player.dispose();
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

class StrokePreviewPainter extends CustomPainter {
  final DrawingStroke stroke;

  StrokePreviewPainter({required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Scale the points to fit in the preview
    final xPoints = stroke.points.map((p) => p.dx).toList();
    final yPoints = stroke.points.map((p) => p.dy).toList();
    final minX = xPoints.reduce(min);
    final maxX = xPoints.reduce(max);
    final minY = yPoints.reduce(min);
    final maxY = yPoints.reduce(max);
    
    final xScale = size.width / (maxX - minX);
    final yScale = size.height / (maxY - minY);
    final scale = min(xScale, yScale) * 0.8;  // 0.8 to add some padding

    final scaledPoints = stroke.points.map((p) => Offset(
      (p.dx - minX) * scale + (size.width - (maxX - minX) * scale) / 2,
      (p.dy - minY) * scale + (size.height - (maxY - minY) * scale) / 2,
    )).toList();

    for (int i = 0; i < scaledPoints.length - 1; i++) {
      canvas.drawLine(scaledPoints[i], scaledPoints[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(StrokePreviewPainter oldDelegate) => false;
} 