import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../home/screens/home_screen.dart';
import '../../video/screens/feed_screen.dart';
import '../../camera/screens/camera_screen.dart';
import '../../video/screens/upload_screen.dart';
import '../../auth/services/auth_service.dart';
import '../../studio/screens/studio_screen.dart';

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
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      // Show upload options
      _showUploadOptions();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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
        children: const [
          FeedScreen(),      // Public videos feed
          SizedBox(),        // Placeholder for camera
          StudioScreen(),    // New Studio screen
          HomeScreen(),      // My videos (private + public)
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