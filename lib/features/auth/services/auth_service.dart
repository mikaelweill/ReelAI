import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      print('Attempting to create user with email: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User created successfully with uid: ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during sign up: ${e.code} - ${e.message}');
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign up.';
      }
      throw FirebaseAuthException(
        code: e.code,
        message: message,
      );
    } catch (e) {
      print('Unexpected error during sign up: $e');
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      print('Attempting to sign in user with email: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('User signed in successfully with uid: ${credential.user?.uid}');
      return credential.user;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during sign in: ${e.code} - ${e.message}');
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'user-disabled':
          message = 'This user account has been disabled.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign in.';
      }
      throw FirebaseAuthException(
        code: e.code,
        message: message,
      );
    } catch (e) {
      print('Unexpected error during sign in: $e');
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    print('Signing out user: ${currentUser?.email}');
    await _auth.signOut();
    print('User signed out successfully');
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
} 