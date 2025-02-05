import 'package:flutter/material.dart';
import '../../studio/models/video_edit.dart';

class VideoChapterList extends StatefulWidget {
  final List<ChapterMark> chapters;
  final double currentPosition;
  final Function(double) onSeek;
  final bool isEditable;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  
  const VideoChapterList({
    super.key,
    required this.chapters,
    required this.currentPosition,
    required this.onSeek,
    this.isEditable = false,
    this.isExpanded = false,
    required this.onToggleExpanded,
  });

  @override
  State<VideoChapterList> createState() => _VideoChapterListState();
}

class _VideoChapterListState extends State<VideoChapterList> {
  String? _highlightedId;

  void _handleChapterTap(ChapterMark chapter) {
    widget.onSeek(chapter.timestamp);
    setState(() {
      _highlightedId = chapter.id;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _highlightedId = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chapters.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedChapters = List<ChapterMark>.from(widget.chapters)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with expand/collapse
        GestureDetector(
          onTap: widget.onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.bookmark, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Chapters (${widget.chapters.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        
        // Chapter list
        if (widget.isExpanded)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: sortedChapters.map((chapter) {
                  final isHighlighted = _highlightedId == chapter.id;
                  return InkWell(
                    onTap: () => _handleChapterTap(chapter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isHighlighted ? Colors.white.withOpacity(0.1) : null,
                      child: Row(
                        children: [
                          // Chapter marker
                          SizedBox(
                            width: 24,
                            child: Column(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Chapter info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chapter.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                if (chapter.description?.isNotEmpty == true)
                                  Text(
                                    chapter.description!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Timestamp
                          Text(
                            _formatTimestamp(chapter.timestamp),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final minutes = duration.inMinutes;
    final remainingSeconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }
} 