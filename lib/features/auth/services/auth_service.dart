import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendSignInLinkToEmail(String email) async {
    try {
      // Configure sign-in link settings
      var actionCodeSettings = ActionCodeSettings(
        url: 'https://reelai-c8ef6.web.app/finishSignUp?email=$email',
        handleCodeInApp: true,
        iOSBundleId: 'com.reelai.app',
        androidPackageName: 'com.reelai.reelai',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      // Send sign-in link directly using Firebase Auth
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      // Save the email locally to use it later
      SharedPreferences storage = await SharedPreferences.getInstance();
      await storage.setString('emailForSignIn', email);
      
      print('Magic link sent successfully');
    } catch (e) {
      print('Error sending magic link: $e');
      rethrow;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
} 