import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mm_app/models/asset.dart';
import 'package:mm_app/services/auth_service.dart';

class AssetService {
  AssetService._();

  static final AssetService instance = AssetService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Asset>> watch() {
    final collection = _assets();
    if (collection == null) return const Stream.empty();
    return collection.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map(Asset.fromFirestore).toList();
    });
  }

  Future<void> add({
    required String name,
    required String category,
    required double quantity,
    required double purchasePrice,
    required double currentPrice,
    String? memo,
  }) async {
    _validate(
      name: name,
      category: category,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('로그인 후 자산을 기록할 수 있습니다.');
    }
    final userRef = _firestore.collection('users').doc(uid);
    final assetRef = userRef.collection('assets').doc();
    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      transaction.set(assetRef, {
        'name': name.trim(),
        'category': category,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'currentPrice': currentPrice,
        'memo': _memo(memo),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AuthService.instance.awardPointsForNewAsset(
        transaction: transaction,
        userRef: userRef,
        userSnapshot: userSnapshot,
      );
    });
  }

  Future<void> update({
    required String id,
    required String name,
    required String category,
    required double quantity,
    required double purchasePrice,
    required double currentPrice,
    String? memo,
  }) async {
    _validate(
      name: name,
      category: category,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice,
    );
    await _requireAssets().doc(id).update({
      'name': name.trim(),
      'category': category,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'currentPrice': currentPrice,
      'memo': _memo(memo),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String id) {
    return _requireAssets().doc(id).delete();
  }

  Future<double> totalValuation() async {
    final collection = _assets();
    if (collection == null) return 0;
    final snapshot = await collection.get();
    return snapshot.docs
        .map(Asset.fromFirestore)
        .fold<double>(0, (total, asset) => total + asset.valuation);
  }

  CollectionReference<Map<String, dynamic>>? _assets() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('assets');
  }

  CollectionReference<Map<String, dynamic>> _requireAssets() {
    final collection = _assets();
    if (collection == null) {
      throw StateError('로그인 후 자산을 기록할 수 있습니다.');
    }
    return collection;
  }

  void _validate({
    required String name,
    required String category,
    required double quantity,
    required double purchasePrice,
    required double currentPrice,
  }) {
    final message = Asset.validate(
      name: name,
      category: category,
      quantity: quantity,
      purchasePrice: purchasePrice,
      currentPrice: currentPrice,
    );
    if (message != null) throw ArgumentError(message);
  }

  String? _memo(String? memo) {
    final text = memo?.trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }
}