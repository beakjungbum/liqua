import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _listening = false;
  bool _googleInitialized = false;

  Stream<User?> authStateChanges() {
    if (Firebase.apps.isEmpty) {
      return const Stream.empty();
    }
    return _auth.authStateChanges();
  }

  void listenToAuthState() {
    if (Firebase.apps.isEmpty || _listening) return;
    _listening = true;
    _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      try {
        await ensureUserDocument(user);
      } catch (e) {
        debugPrint('사용자 문서 저장에 실패했습니다.\n$e');
      }
    });
  }

  Future<void> signInWithGoogle() async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase가 초기화되지 않았습니다.');
    }

    try {
      final UserCredential credential = await _googleCredential();
      final User? user = credential.user;
      if (user == null) {
        throw StateError('로그인 사용자 정보를 가져오지 못했습니다.');
      }
      await ensureUserDocument(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_canUseGoogleSignInPlugin) {
      try {
        await _ensureGoogleInitialized();
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Google 세션 정리에 실패했습니다.\n$e');
      }
    }
    await _auth.signOut();
  }

  /// 같은 uid 문서가 있으면 createdAt은 유지하고 프로필만 갱신한다.
  Future<void> ensureUserDocument(User user) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection('users')
        .doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(ref);
      final Map<String, dynamic> profile = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (snapshot.exists) {
        transaction.update(ref, profile);
      } else {
        profile['createdAt'] = FieldValue.serverTimestamp();
        transaction.set(ref, profile);
      }
    });
  }

  Future<UserCredential> _googleCredential() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }
    if (!_canUseGoogleSignInPlugin) {
      throw UnsupportedError(
        'Google 로그인은 Android, iOS, macOS, 웹에서 사용할 수 있습니다.',
      );
    }

    await _ensureGoogleInitialized();
    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate();
    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google ID 토큰이 없습니다. Firebase Console에 SHA-1을 등록한 뒤 google-services.json을 다시 받아 주세요.',
      );
    }
    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  bool get _canUseGoogleSignInPlugin {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }
}