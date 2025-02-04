import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> sendSignInLinkToEmail(String email) async {
    try {
      // Call our custom cloud function
      final callable = _functions.httpsCallable('send_magic_link_email');
      final result = await callable.call({
        'email': email,
      });

      // The function should return a success message
      print('Magic link sent: ${result.data}');
    } catch (e) {
      print('Error sending magic link: $e');
      rethrow;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
} 