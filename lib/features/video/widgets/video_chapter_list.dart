import 'package:flutter/material.dart';
import '../../studio/models/video_edit.dart';

class VideoChapterList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedChapters = List<ChapterMark>.from(chapters)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with expand/collapse
        GestureDetector(
          onTap: onToggleExpanded,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.bookmark, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Chapters (${chapters.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        
        // Chapter list
        if (isExpanded)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: sortedChapters.map((chapter) {
                  final isActive = currentPosition >= chapter.timestamp;
                  return InkWell(
                    onTap: () => onSeek(chapter.timestamp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isActive ? Colors.grey.withOpacity(0.2) : null,
                      child: Row(
                        children: [
                          // Chapter marker and line
                          SizedBox(
                            width: 24,
                            child: Column(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive ? Colors.blue : Colors.grey,
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
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: isActive ? FontWeight.bold : null,
                                  ),
                                ),
                                if (chapter.description?.isNotEmpty == true)
                                  Text(
                                    chapter.description!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Timestamp
                          Text(
                            _formatTimestamp(chapter.timestamp),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isActive ? Colors.blue : Colors.grey,
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