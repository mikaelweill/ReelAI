import 'package:flutter/material.dart';
import '../../studio/models/video_edit.dart';

class VideoChapterList extends StatelessWidget {
  final List<ChapterMark> chapters;
  final double currentPosition;
  final Function(double) onSeek;
  final bool isEditable;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  
  const VideoChapterList({
    super.key,
    required this.chapters,
    required this.currentPosition,
    required this.onSeek,
    this.isEditable = false,
    this.isExpanded = true,
    this.onToggleExpanded,
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
        if (onToggleExpanded != null)
          InkWell(
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedChapters.length,
            itemBuilder: (context, index) {
              final chapter = sortedChapters[index];
              final isActive = currentPosition >= chapter.timestamp &&
                  (index == sortedChapters.length - 1 ||
                      currentPosition < sortedChapters[index + 1].timestamp);

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
                            if (index < sortedChapters.length - 1)
                              Container(
                                width: 2,
                                height: 24,
                                color: Colors.grey.withOpacity(0.3),
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
                      // Edit/Delete buttons for studio view
                      if (isEditable) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () {
                            // TODO: Implement edit
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () {
                            // TODO: Implement delete
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
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