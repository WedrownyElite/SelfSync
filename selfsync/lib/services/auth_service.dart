import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../utils/app_logger.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? false;
  bool get hasEmailProvider => currentUser?.providerData.any(
          (info) => info.providerId == 'password'
  ) ?? false;
  bool get hasGoogleProvider => currentUser?.providerData.any(
          (info) => info.providerId == 'google.com'
  ) ?? false;
  String? get userEmail => currentUser?.email;
  String? get displayName => currentUser?.displayName;
  String? get photoUrl => currentUser?.photoURL;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      AppLogger.info(
        user != null ? 'User signed in: ${user.email ?? "anonymous"}' : 'User signed out',
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

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      AppLogger.info('Initiating email sign-in', tag: 'AuthService');

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      AppLogger.success('Email sign-in successful: $email', tag: 'AuthService');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Email sign-in failed: ${e.code}', tag: 'AuthService');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Email sign-in failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Register with email and password
  Future<bool> registerWithEmail(String email, String password, {String? displayName}) async {
    try {
      AppLogger.info('Initiating email registration', tag: 'AuthService');

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (displayName != null && displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
      }

      AppLogger.success('Email registration successful: $email', tag: 'AuthService');
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Email registration failed: ${e.code}', tag: 'AuthService');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Email registration failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Sign in anonymously
  Future<bool> signInAnonymously() async {
    try {
      AppLogger.info('Initiating anonymous sign-in', tag: 'AuthService');

      await _auth.signInAnonymously();

      AppLogger.success('Anonymous sign-in successful', tag: 'AuthService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Anonymous sign-in failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Link Google account to current user
  Future<bool> linkGoogleAccount() async {
    try {
      AppLogger.info('Linking Google account', tag: 'AuthService');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        AppLogger.info('User cancelled Google linking', tag: 'AuthService');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await currentUser?.linkWithCredential(credential);

      AppLogger.success('Google account linked successfully', tag: 'AuthService');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Google linking failed: ${e.code}', tag: 'AuthService');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Google linking failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Convert anonymous account to email/password
  Future<bool> convertAnonymousToEmail(String email, String password, {String? displayName}) async {
    try {
      AppLogger.info('Converting anonymous account to email', tag: 'AuthService');

      if (!isAnonymous) {
        AppLogger.warning('User is not anonymous', tag: 'AuthService');
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await currentUser?.linkWithCredential(credential);

      if (displayName != null && displayName.isNotEmpty) {
        await currentUser?.updateDisplayName(displayName);
      }

      AppLogger.success('Anonymous account converted successfully', tag: 'AuthService');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Anonymous conversion failed: ${e.code}', tag: 'AuthService');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Anonymous conversion failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Convert anonymous account to Google
  Future<bool> convertAnonymousToGoogle() async {
    try {
      AppLogger.info('Converting anonymous account to Google', tag: 'AuthService');

      if (!isAnonymous) {
        AppLogger.warning('User is not anonymous', tag: 'AuthService');
        return false;
      }

      return await linkGoogleAccount();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Anonymous to Google conversion failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      AppLogger.info('Sending password reset email', tag: 'AuthService');

      await _auth.sendPasswordResetEmail(email: email);

      AppLogger.success('Password reset email sent', tag: 'AuthService');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Password reset failed',
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

      // Sign out from Google first to clear credentials
      try {
        await _googleSignIn.signOut();
        await _googleSignIn.disconnect();
      } catch (e) {
        AppLogger.warning('Google sign-out warning: $e', tag: 'AuthService');
        // Continue even if Google sign-out fails
      }

      // Then sign out from Firebase
      await _auth.signOut();

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

  /// Complete sign-out including clearing all Google credentials
  Future<void> completeSignOut() async {
    try {
      AppLogger.info('Performing complete sign-out', tag: 'AuthService');

      // Disconnect Google account completely
      try {
        await _googleSignIn.disconnect();
      } catch (e) {
        AppLogger.warning('Google disconnect warning: $e', tag: 'AuthService');
      }

      // Sign out from Google
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        AppLogger.warning('Google sign-out warning: $e', tag: 'AuthService');
      }

      // Sign out from Firebase
      await _auth.signOut();

      AppLogger.success('Complete sign-out successful', tag: 'AuthService');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Complete sign-out failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      rethrow;
    }
  }

  /// Delete account
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
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Account deletion failed: ${e.code}', tag: 'AuthService');
      AppLogger.error('  └─ Error details: $e', tag: 'AuthService');

      // Re-throw FirebaseAuthException so caller can handle it
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Account deletion failed', tag: 'AuthService');
      AppLogger.error('  └─ Error details: $e', tag: 'AuthService');
      AppLogger.error('  └─ Stack trace:', tag: 'AuthService');
      AppLogger.error('$stackTrace', tag: 'AuthService');
      rethrow;
    }
  }

  /// Get Firebase Auth error message
  String getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'provider-already-linked':
        return 'This account is already linked';
      case 'credential-already-in-use':
        return 'This credential is already associated with another account';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  /// Update user profile picture
  Future<bool> updateProfilePicture(String photoURL) async {
    try {
      AppLogger.info('Updating profile picture', tag: 'AuthService');

      final user = currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in', tag: 'AuthService');
        return false;
      }

      // If empty string, delete the profile picture
      if (photoURL.isEmpty) {
        return await deleteProfilePicture();
      }

      await user.updatePhotoURL(photoURL);
      await user.reload();

      AppLogger.success('Profile picture updated', tag: 'AuthService');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Profile picture update failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Update display name
  Future<bool> updateDisplayName(String displayName) async {
    try {
      AppLogger.info('Updating display name', tag: 'AuthService');

      final user = currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in', tag: 'AuthService');
        return false;
      }

      await user.updateDisplayName(displayName);
      await user.reload();

      AppLogger.success('Display name updated', tag: 'AuthService');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Display name update failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Unlink Google account
  Future<bool> unlinkGoogleAccount() async {
    try {
      AppLogger.info('Unlinking Google account', tag: 'AuthService');

      final user = currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in', tag: 'AuthService');
        return false;
      }

      // Check if user has other providers (must have at least one)
      if (user.providerData.length <= 1) {
        AppLogger.warning('Cannot unlink - user must have at least one auth provider', tag: 'AuthService');
        throw FirebaseAuthException(
          code: 'requires-alternate-provider',
          message: 'You must have at least one sign-in method',
        );
      }

      await user.unlink('google.com');
      await user.reload();

      // Sign out from Google
      await _googleSignIn.signOut();

      AppLogger.success('Google account unlinked', tag: 'AuthService');
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Google unlinking failed: ${e.code}', tag: 'AuthService');
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Google unlinking failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Upload profile picture to Firebase Storage and update user profile
  Future<String?> uploadAndUpdateProfilePicture(String imagePath) async {
    try {
      AppLogger.info('Uploading profile picture to Firebase Storage', tag: 'AuthService');

      final user = currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in', tag: 'AuthService');
        return null;
      }

      // Create a reference to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final profilePicRef = storageRef.child('profile_pictures/${user.uid}.jpg');

      // Upload the file
      final file = File(imagePath);
      final uploadTask = await profilePicRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get the download URL
      final photoURL = await uploadTask.ref.getDownloadURL();

      AppLogger.info('Profile picture uploaded, URL: $photoURL', tag: 'AuthService');

      // Update user profile with the URL
      await user.updatePhotoURL(photoURL);
      await user.reload();

      AppLogger.success('Profile picture updated successfully', tag: 'AuthService');
      notifyListeners();

      return photoURL;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Profile picture upload failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return null;
    }
  }

  /// Delete profile picture from Firebase Storage
  Future<bool> deleteProfilePicture() async {
    try {
      AppLogger.info('Deleting profile picture', tag: 'AuthService');

      final user = currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in', tag: 'AuthService');
        return false;
      }

      // Delete from Firebase Storage if it exists
      try {
        final storageRef = FirebaseStorage.instance.ref();
        final profilePicRef = storageRef.child('profile_pictures/${user.uid}.jpg');
        await profilePicRef.delete();
        AppLogger.info('Profile picture deleted from storage', tag: 'AuthService');
      } catch (e) {
        AppLogger.warning('No profile picture to delete from storage: $e', tag: 'AuthService');
        // Continue even if deletion fails (file might not exist)
      }

      // Update user profile to remove photo URL
      await user.updatePhotoURL(null);
      await user.reload();

      AppLogger.success('Profile picture removed', tag: 'AuthService');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Profile picture deletion failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }

  /// Restore Google profile picture
  Future<bool> restoreGoogleProfilePicture() async {
    try {
      AppLogger.info('Restoring Google profile picture', tag: 'AuthService');

      final user = currentUser;
      if (user == null) {
        AppLogger.warning('No user signed in', tag: 'AuthService');
        return false;
      }

      // Check if user has Google provider
      final googleProvider = user.providerData.firstWhere(
            (provider) => provider.providerId == 'google.com',
        orElse: () => throw Exception('No Google provider found'),
      );

      final googlePhotoURL = googleProvider.photoURL;

      if (googlePhotoURL == null || googlePhotoURL.isEmpty) {
        AppLogger.warning('No Google photo URL available', tag: 'AuthService');
        return false;
      }

      // Delete custom profile picture from Firebase Storage if it exists
      try {
        final storageRef = FirebaseStorage.instance.ref();
        final profilePicRef = storageRef.child('profile_pictures/${user.uid}.jpg');
        await profilePicRef.delete();
        AppLogger.info('Deleted custom profile picture from storage', tag: 'AuthService');
      } catch (e) {
        AppLogger.info('No custom profile picture to delete', tag: 'AuthService');
      }

      // Update Firebase Auth profile with Google photo URL
      await user.updatePhotoURL(googlePhotoURL);
      await user.reload();

      AppLogger.success('Google profile picture restored', tag: 'AuthService');
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to restore Google profile picture',
        error: e,
        stackTrace: stackTrace,
        tag: 'AuthService',
      );
      return false;
    }
  }
}