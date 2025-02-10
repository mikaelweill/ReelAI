import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../camera/screens/video_preview_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Open gallery picker immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickVideo();
    });
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5), // 5 minute limit
      );

      if (!mounted) return;

      if (video == null) {
        // User cancelled selection
        Navigator.of(context).pop();
        return;
      }

      // Navigate to preview screen
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPreviewScreen(videoPath: video.path),
        ),
      );

      if (!mounted) return;

      if (result != null && result['shouldClose'] == true) {
        // Upload was successful
        Navigator.of(context).pop();
      } else {
        // Upload was cancelled or failed, go back
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show empty black screen while picker is opening
    return const Scaffold(
      backgroundColor: Colors.black,
    );
  }
} 