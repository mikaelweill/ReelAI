import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../home/screens/home_screen.dart';
import '../../video/screens/feed_screen.dart';
import '../../camera/screens/camera_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
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

  void _onItemTapped(int index) {
    if (index == 1) {
      // Camera button tapped
      if (_isCameraInitialized) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CameraScreen(cameras: cameras),
          ),
        );
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          FeedScreen(),  // Public videos feed
          SizedBox(),    // Placeholder for camera
          HomeScreen(),  // My videos (private + public)
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 40),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Videos',
          ),
        ],
        currentIndex: _selectedIndex == 1 ? 0 : _selectedIndex,  // Never show camera as selected
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
} 