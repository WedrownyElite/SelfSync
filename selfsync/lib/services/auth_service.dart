import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  String? get userEmail => currentUser?.email;
  String? get displayName => currentUser?.displayName;
  String? get photoUrl => currentUser?.photoURL;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      AppLogger.info(
        user != null ? 'User signed in: ${user.email}' : 'User signed out',
        tag: 'AuthService',
      );
      notifyListeners();
    });
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      AppLogger.info('Initiating Google sign-in', tag: 'AuthService');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        AppLogger.info('User cancelled Google sign-in', tag: 'AuthService');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      AppLogger.success(
        'Google sign-in successful: ${userCredential.user?.email}',
        tag: 'AuthService',
      );

      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Google sign-in failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out user', tag: 'AuthService');

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      AppLogger.success('User signed out successfully', tag: 'AuthService');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Sign out failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      rethrow;
    }
  }

  /// Delete account (optional - for user privacy)
  Future<bool> deleteAccount() async {
    AppLogger.info('Deleting user account', tag: 'AuthService');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in to delete', tag: 'AuthService');
        return false;
      }

      await user.delete();
      AppLogger.success('Account deleted successfully', tag: 'AuthService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Account deletion failed', tag: 'AuthService');
      AppLogger.error('  └─ Error details: $e', tag: 'AuthService');
      AppLogger.error('  └─ Stack trace:', tag: 'AuthService');
      AppLogger.error('$stackTrace', tag: 'AuthService');

      // RE-THROW THE EXCEPTION instead of returning false
      rethrow;
    }
  }
}