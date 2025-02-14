import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/video.dart';
import '../models/video_edit.dart';
import '../widgets/video_editor.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => StudioScreenState();
}

class StudioScreenState extends State<StudioScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final GlobalKey<VideoEditorState> _videoEditorKey = GlobalKey<VideoEditorState>();

  void pauseVideos() {
    _videoEditorKey.currentState?.pauseVideo();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog with editing instructions
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Editing Help'),
                  content: const SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Tap a video to start editing'),
                        Text('• Add text overlays with timestamps'),
                        Text('• Create chapter markers'),
                        Text('• Adjust sound levels'),
                        Text('• Save changes to update your video'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('videos')
            .where('userId', isEqualTo: _auth.currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final videos = snapshot.data?.docs ?? [];
          
          if (videos.isEmpty) {
            return const Center(
              child: Text(
                'No videos uploaded yet.\nCreate content to start editing!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final videoData = videos[index].data() as Map<String, dynamic>;
              videoData['id'] = videos[index].id;
              final video = Video.fromJson(videoData);

              return ListTile(
                leading: Container(
                  width: 100,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: video.thumbnailUrl != null ? null : Colors.grey[300],
                    image: video.thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(video.thumbnailUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: video.thumbnailUrl == null
                      ? const Icon(Icons.video_library, color: Colors.grey)
                      : null,
                ),
                title: Text(video.title),
                subtitle: Text(
                  'Created ${_formatDate(video.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoEditor(video: video),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
} 