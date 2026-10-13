import 'package:google_sign_in/google_sign_in.dart';

/// Profile returned by the Google Sign-In SDK.
class GoogleUserProfile {
  final String? displayName;
  final String email;
  final String? photoURL;

  const GoogleUserProfile({
    required this.email,
    this.displayName,
    this.photoURL,
  });
}

class GoogleAuthService {
  Future<GoogleUserProfile?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      return GoogleUserProfile(
        displayName: googleUser.displayName,
        email: googleUser.email,
        photoURL: googleUser.photoUrl,
      );
    } catch (e) {
      print('❌ Google Sign In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}
