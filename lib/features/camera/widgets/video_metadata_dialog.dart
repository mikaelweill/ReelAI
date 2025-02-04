import 'package:flutter/material.dart';

class VideoMetadata {
  final String title;
  final String? description;
  final bool isPrivate;

  VideoMetadata({
    required this.title,
    this.description,
    required this.isPrivate,
  });
}

class VideoMetadataDialog extends StatefulWidget {
  const VideoMetadataDialog({super.key});

  @override
  State<VideoMetadataDialog> createState() => _VideoMetadataDialogState();
}

class _VideoMetadataDialogState extends State<VideoMetadataDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = false;
  String? _titleError;

  void _validateTitle(String value) {
    setState(() {
      if (value.isEmpty) {
        _titleError = 'Title is required';
      } else if (value.length < 3) {
        _titleError = 'Title must be at least 3 characters';
      } else if (value.length > 50) {
        _titleError = 'Title must be less than 50 characters';
      } else {
        _titleError = null;
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Video Details',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                errorText: _titleError,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                counterText: '${_titleController.text.length}/50',
                helperText: 'Required, 3-50 characters',
                helperStyle: const TextStyle(height: 1),
                errorStyle: const TextStyle(height: 1),
              ),
              maxLength: 50,
              onChanged: _validateTitle,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                counterText: '${_descriptionController.text.length}/200',
                helperText: 'Optional, max 200 characters',
                helperStyle: const TextStyle(height: 1),
              ),
              maxLength: 200,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Private Video'),
              subtitle: const Text('Only visible to you'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _titleError == null && _titleController.text.isNotEmpty
                      ? () {
                          Navigator.of(context).pop(
                            VideoMetadata(
                              title: _titleController.text,
                              description: _descriptionController.text.isEmpty
                                  ? null
                                  : _descriptionController.text,
                              isPrivate: _isPrivate,
                            ),
                          );
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 