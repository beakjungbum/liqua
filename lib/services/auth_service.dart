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

  Stream<UserProgress> watchProgress() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || Firebase.apps.isEmpty) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      return UserProgress.fromMap(snapshot.data());
    });
  }

  Future<UserProgress> currentProgress() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const UserProgress();
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return UserProgress.fromMap(snapshot.data());
  }

  Future<void> saveTargetAmount(int amount) async {
    if (amount < 0) {
      throw ArgumentError('목표 금액은 0보다 작을 수 없습니다.');
    }
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('로그인 후 목표를 저장할 수 있습니다.');
    }
    await _firestore.collection('users').doc(uid).set({
      'targetAmount': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 자산 문서가 새로 만들어진 뒤에만 호출한다.
  void awardPointsForNewAsset({
    required Transaction transaction,
    required DocumentReference<Map<String, dynamic>> userRef,
    required DocumentSnapshot<Map<String, dynamic>> userSnapshot,
  }) {
    final current = (userSnapshot.data()?['points'] as num?)?.toInt() ?? 0;
    final points = current + 10;
    final fields = <String, dynamic>{
      'points': points,
      'currentLevel': levelForPoints(points),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (userSnapshot.exists) {
      transaction.update(userRef, fields);
    } else {
      fields['uid'] = userRef.id;
      fields['targetAmount'] = 0;
      fields['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(userRef, fields);
    }
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
      final data = snapshot.data();
      if (snapshot.exists) {
        if (data == null || !data.containsKey('targetAmount')) {
          profile['targetAmount'] = 0;
        }
        if (data == null || !data.containsKey('points')) {
          profile['points'] = 0;
        }
        if (data == null || !data.containsKey('currentLevel')) {
          profile['currentLevel'] = 1;
        }
        transaction.update(ref, profile);
      } else {
        profile['createdAt'] = FieldValue.serverTimestamp();
        profile['targetAmount'] = 0;
        profile['points'] = 0;
        profile['currentLevel'] = 1;
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

class UserProgress {
  const UserProgress({
    this.targetAmount = 0,
    this.points = 0,
    this.currentLevel = 1,
  });

  final int targetAmount;
  final int points;
  final int currentLevel;

  factory UserProgress.fromMap(Map<String, dynamic>? data) {
    final points = (data?['points'] as num?)?.toInt() ?? 0;
    return UserProgress(
      targetAmount: (data?['targetAmount'] as num?)?.toInt() ?? 0,
      points: points,
      currentLevel:
          (data?['currentLevel'] as num?)?.toInt() ?? levelForPoints(points),
    );
  }
}

int levelForPoints(int points) {
  if (points >= 600) return 4;
  if (points >= 300) return 3;
  if (points >= 100) return 2;
  return 1;
}

double achievementPercent(double totalAssets, int targetAmount) {
  if (targetAmount <= 0) return 0;
  return totalAssets / targetAmount * 100;
}
