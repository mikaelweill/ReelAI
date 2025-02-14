import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../home/screens/home_screen.dart';
import '../../video/screens/feed_screen.dart';
import '../../camera/screens/camera_screen.dart';
import '../../video/screens/upload_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../studio/screens/studio_screen.dart';
import '../../video/services/video_upload_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  late List<CameraDescription> cameras;
  bool _isCameraInitialized = false;
  int _previousIndex = 0;
  
  final GlobalKey<FeedScreenState> _feedScreenKey = GlobalKey<FeedScreenState>();
  final GlobalKey<StudioScreenState> _studioScreenKey = GlobalKey<StudioScreenState>();
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white, size: 32),
              title: const Text(
                'Record Video',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                if (_isCameraInitialized) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CameraScreen(cameras: cameras),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white, size: 32),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onTap: () {
                Navigator.pop(context); // Close bottom sheet
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UploadScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.youtube_searched_for, color: Colors.white, size: 32),
              title: const Text(
                'Import from YouTube',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onTap: () {
                Navigator.pop(context);
                _showYouTubeImportDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showYouTubeImportDialog() {
    final urlController = TextEditingController();
    bool isLoading = false;
    double progress = 0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import from YouTube'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'YouTube URL',
                  hintText: 'https://youtube.com/...',
                ),
              ),
              if (isLoading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading ? null : () async {
                final url = urlController.text.trim();
                if (url.isEmpty) return;
                
                setState(() {
                  isLoading = true;
                  progress = 0;
                });
                
                try {
                  final videoId = await VideoUploadService().importYoutubeVideo(
                    url,
                    onProgress: (p) {
                      setState(() => progress = p);
                    },
                  );
                  
                  if (videoId != null) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video imported successfully!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    throw Exception('Failed to import video');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setState(() => isLoading = false);
                  }
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    // Always pause videos when switching tabs
    _feedScreenKey.currentState?.pauseVideos();
    _studioScreenKey.currentState?.pauseVideos();
    _homeScreenKey.currentState?.pauseVideos();

    // If it's the upload screen (index 1), we've already paused everything
    if (index == 1) {
      _showUploadOptions();
    }

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> titles = ['Feed', '', 'Studio', 'My Videos'];
    
    return Scaffold(
      appBar: _selectedIndex != 1 ? AppBar(
        title: Text(titles[_selectedIndex]),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ) : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          FeedScreen(key: _feedScreenKey),      // Public videos feed
          const SizedBox(),                     // Placeholder for camera
          StudioScreen(key: _studioScreenKey),  // Studio screen
          HomeScreen(key: _homeScreenKey),      // My videos (private + public)
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Studio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Videos',
          ),
        ],
        currentIndex: _selectedIndex == 1 ? 0 : _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        backgroundColor: Colors.black,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
} 