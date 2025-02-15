import 'package:flutter/material.dart';
import '../services/video_enhancements_service.dart';

class TranscriptSearchBox extends StatefulWidget {
  final List<Subtitle> subtitles;
  final Function(double) onTimestampSelected;

  const TranscriptSearchBox({
    super.key,
    required this.subtitles,
    required this.onTimestampSelected,
  });

  @override
  State<TranscriptSearchBox> createState() => _TranscriptSearchBoxState();
}

class _TranscriptSearchBoxState extends State<TranscriptSearchBox> {
  final _searchController = TextEditingController();
  List<Subtitle> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) {
    print('\n--- Performing Search ---');
    print('Query: "$query"');
    print('Number of subtitles to search: ${widget.subtitles.length}');
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Empty query, cleared results');
      return;
    }

    final results = widget.subtitles
        .where((subtitle) =>
            subtitle.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
        
    print('Found ${results.length} matches:');
    for (var result in results.take(3)) {
      print('- "${result.text}" at ${result.startTime}s');
    }
    if (results.length > 3) {
      print('... and ${results.length - 3} more');
    }

    setState(() {
      _isSearching = true;
      _searchResults = results;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search in transcript...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[800],
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: _performSearch,
          ),
        ),
        if (_isSearching && _searchResults.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  title: Text(
                    result.text,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatTimestamp(result.startTime)}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  onTap: () {
                    widget.onTimestampSelected(result.startTime);
                    // Clear search after selection
                    _searchController.clear();
                    _performSearch('');
                  },
                );
              },
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