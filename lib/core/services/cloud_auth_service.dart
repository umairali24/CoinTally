import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';

class CloudAuthService {
  static final CloudAuthService _instance = CloudAuthService._internal();
  factory CloudAuthService() => _instance;
  CloudAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  GoogleSignInAccount? _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', _currentUser!.email);
        await prefs.setString('user_id', _currentUser!.id);
        if (_currentUser!.displayName != null) {
          await prefs.setString('user_name', _currentUser!.displayName!);
        }
      }
      return _currentUser;
    } catch (error) {
      log('Google Sign-In Error: $error');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (error) {
      log('Google Silent Sign-In Error: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<bool> hasPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_email');
  }

  Future<auth.AuthClient?> getAuthenticatedClient() async {
    if (_currentUser == null) {
      _currentUser = await signInSilently();
    }
    
    if (_currentUser == null) return null;
    
    return await _googleSignIn.authenticatedClient();
  }
}
