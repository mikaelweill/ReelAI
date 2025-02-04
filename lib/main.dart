import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:reelai/features/auth/screens/login_screen.dart';
// import 'firebase_options.dart';  // Comment this out temporarily

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // App already initialized, we can continue
      print('Firebase already initialized');
    } else {
      print('Firebase initialization error: $e');
      rethrow;
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReelAI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const LoginScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TikTok Clone'),
      ),
      body: const Center(
        child: Text('Welcome to TikTok Clone!'),
      ),
    );
  }
} 