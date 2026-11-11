import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api.dart';

/// Google sign-in, turned into the Firebase ID token the server checks (the same proof the web
/// sign-in sends). Firebase is only the proof: the server's own tokens are the session, so the
/// Firebase session is dropped right after.
class GoogleAuth {
  static Future<void>? _ready;

  /// Null when the person closed the Google chooser.
  static Future<String?> firebaseIdToken() async {
    // No client ID here: Android reads the Web client ID google-services.json generated.
    await (_ready ??= GoogleSignIn.instance.initialize());
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ApiError(0, _failed);
    }
    final googleToken = account.authentication.idToken;
    if (googleToken == null) throw ApiError(0, _failed);
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: googleToken));
      return await result.user?.getIdToken();
    } on FirebaseAuthException {
      throw ApiError(0, _failed);
    } finally {
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Signing out of the app also forgets the Google account, so the chooser shows next time.
  static Future<void> signOut() async {
    if (_ready != null) await GoogleSignIn.instance.signOut();
  }

  static String get _failed =>
      session.lang == 'bn' ? 'গুগল দিয়ে সাইন ইন হয়নি। আবার চেষ্টা করুন।' : 'Google sign-in did not work. Try again.';
}
