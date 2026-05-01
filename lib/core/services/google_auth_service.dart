import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  Future<User?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize();
      await GoogleSignIn.instance.signOut().catchError((_) {});

      final GoogleSignInAccount? googleUser =
          await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final User? user = userCredential.user;
      print('✅ Name: ${user?.displayName}');
      print('✅ Email: ${user?.email}');
      print('✅ UID: ${user?.uid}');
      return user;
    } catch (e) {
      print('❌ Google Sign In Error: $e');
      
      if (e.toString().contains('canceled')) {
        return null;
      }
      
      // أي error تاني وريه رسالة
      throw Exception('فشل تسجيل الدخول، حاول تاني');
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}