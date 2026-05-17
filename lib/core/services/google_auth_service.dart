import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google + Firebase sign-in payload used to persist session locally.
class GoogleSignInResult {
  final User firebaseUser;
  final String? idToken;
  final String? accessToken;

  const GoogleSignInResult({
    required this.firebaseUser,
    this.idToken,
    this.accessToken,
  });

  String? get email => firebaseUser.email;
  String? get displayName => firebaseUser.displayName;
  String? get photoUrl => firebaseUser.photoURL;
  String get firebaseUid => firebaseUser.uid;
}

class GoogleAuthService {
  Future<GoogleSignInResult?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      await GoogleSignIn.instance.signOut().catchError((_) {});

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) return null;

      String? firebaseIdToken;
      try {
        firebaseIdToken = await user.getIdToken();
      } catch (_) {}

      return GoogleSignInResult(
        firebaseUser: user,
        idToken: googleAuth.idToken,
        accessToken: firebaseIdToken,
      );
    } catch (e) {
      if (e.toString().contains('canceled')) {
        return null;
      }
      throw Exception('فشل تسجيل الدخول، حاول تاني');
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
