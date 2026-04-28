import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class GoogleAuthService {
  final Dio _dio = Dio();
  Future<void> initialize() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: '707992130855-cgmrkrhuk4lqmlmhdih90ar83te6rqlj.apps.googleusercontent.com',
      clientId: "707992130855-0vhjanj38jr6hpfnm0nncge94fna80sf.apps.googleusercontent.com"
    );
  }

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    String? userId = OneSignal.User.pushSubscription.id;
  try {
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null) return null;

    final response = await _dio.post(
      'https://www.globee-trading.com/auth/google.php',
      data: {'id_token': idToken, 'player_id': userId, 'store_id': '3'},
      options: Options(
        validateStatus: (status) => true, // متوقفش على أي status code
      ),
    );

    // اطبع كل حاجة
    print('STATUS: ${response.statusCode}');
    print('BODY: ${response.data}');

    return response.data;
  } catch (e) {
    print('Google Sign In Error: $e');
    return null;
  }
}

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}