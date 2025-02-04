import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_admin/firebase_admin.dart';

Future<void> main(List<String> args) async {
  // Initialize Firebase Admin
  final cert = ServiceAccountCredentials.fromFile('path/to/service-account.json');
  FirebaseAdmin.instance.initializeApp(
    AppOptions(
      credential: cert,
      projectId: 'reelai-c8ef6',
    ),
  );
  
  print('Starting Firestore migrations...');
  final migrator = FirestoreMigrator();
  await migrator.runMigrations();
  print('Migrations completed.');
}

class FirestoreMigrator {
  final Firestore _firestore = FirebaseAdmin.instance.firestore;
  
  Future<void> runMigrations() async {
    try {
      await _createVideosCollection();
    } catch (e) {
      print('Migration failed: $e');
      rethrow;
    }
  }
  
  Future<void> _createVideosCollection() async {
    print('Creating videos collection...');
    
    // Create collection with initial schema document
    final dummyDoc = _firestore.collection('videos').doc('schema_init');
    await dummyDoc.set({
      'userId': 'schema_init',
      'videoUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'duration': 0,
      'aspectRatio': 1.0,
      'status': 'ready',
      'isPrivate': false,
      'viewCount': 0,
      'title': '',
      'description': '',
    });
    
    // Clean up
    await dummyDoc.delete();
    print('Videos collection created successfully');
  }
} 