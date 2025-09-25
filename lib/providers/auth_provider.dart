import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _setLoading(true);
    try {
      _auth.authStateChanges().listen((User? user) {
        _user = user;
        _setLoading(false);
        notifyListeners();
      });
    } catch (e) {
      debugPrint('AuthProvider initialization error: $e');
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await _updateLastLogin(result.user!.uid);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await result.user?.updateDisplayName(name);
      await result.user?.reload();
      final updatedUser = _auth.currentUser;

      if (updatedUser != null) {
        await _createFirestoreUser(updatedUser, name);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _setLoading(false);
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);

      await result.user?.reload();
      final updatedUser = _auth.currentUser;

      if (updatedUser != null) {
        await _updateOrCreateFirestoreUser(updatedUser);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred during Google sign-in.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      _setError('Sign out failed.');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      _setError(null);

      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        default:
          message = 'Password reset failed. Please try again.';
      }
      _setError(message);
    } catch (e) {
      _setError('An unexpected error occurred.');
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _setError(null);
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email.';
        break;
      case 'wrong-password':
        message = 'Wrong password provided.';
        break;
      case 'invalid-email':
        message = 'Invalid email address.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists for this email.';
        break;
      case 'account-exists-with-different-credential':
        message =
            'An account already exists with this email using a different sign-in method.';
        break;
      case 'invalid-credential':
        message = 'The credential received is malformed or has expired.';
        break;
      case 'operation-not-allowed':
        message = 'This sign-in method is not enabled.';
        break;
      default:
        message = 'Authentication failed. Please try again.';
    }
    _setError(message);
  }

  Future<void> _updateLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  Future<void> _createFirestoreUser(User user, String name) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating Firestore user document: $e');
    }
  }

  Future<void> _updateOrCreateFirestoreUser(User user) async {
    try {
      if (user.uid.isEmpty) {
        debugPrint('User UID is empty, cannot create Firestore document');
        return;
      }

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': user.displayName?.isNotEmpty == true
              ? user.displayName
              : 'User',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        await _updateLastLogin(user.uid);
      }
    } catch (e) {
      debugPrint('Error updating or creating Firestore user data: $e');
    }
  }

  // Method to get user's display name with Firestore fallback
  Future<String> getUserDisplayName() async {
    if (_user == null) return 'there';

    // First try to get display name from Firebase Auth (for Google Auth users)
    if (_user!.displayName != null && _user!.displayName!.isNotEmpty) {
      return _user!.displayName!;
    }

    // Fallback to Firestore if display name is not available (for Email/Password users)
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? name = userData['name'];
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    } catch (e) {
      debugPrint('Error getting user name from Firestore: $e');
    }

    // Final fallback to generic greeting
    return 'there';
  }
}
