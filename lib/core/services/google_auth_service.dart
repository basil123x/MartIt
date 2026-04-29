import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class GoogleAuthService {
  final Dio _dio = Dio();

  Future<void> initialize() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: '35600706278-g91lt4njajab7v64mgi2s5brn8vr22kb.apps.googleusercontent.com',
      clientId: "35600706278-dmkqlb96t29dmcq4dbnntn288eidpmcc.apps.googleusercontent.com"
    );
  }
  // Android Release Key
  // 35600706278-dmkqlb96t29dmcq4dbnntn288eidpmcc.apps.googleusercontent.com
  // Android Debugging
  // 35600706278-3954gt7h529125sn0j0qi284cimt3soq.apps.googleusercontent.com

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    String? userId = OneSignal.User.pushSubscription.id;
  try {
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null) return null;

    final response = await _dio.post(
      'https://www.globee-trading.com/auth/google.php',
      data: {'id_token': idToken, 'player_id': userId},
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