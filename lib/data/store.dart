import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

typedef Doc = (String id, Json data);

/// 저장소. 로그인하면 Firestore, 둘러보기는 메모리를 쓴다.
abstract class Store {
  Stream<List<Doc>> watch(String collection);
  Stream<Json> watchUser();
  Future<void> set(String collection, String id, Json data);
  Future<void> remove(String collection, String id);
  Future<void> mergeUser(Json data);
  String newId();
}

Object? _fromFire(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      Map m => {for (final e in m.entries) '${e.key}': _fromFire(e.value)},
      List l => [for (final e in l) _fromFire(e)],
      _ => v,
    };

class FirestoreStore implements Store {
  FirestoreStore(this.uid, [FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;
  final String uid;
  final FirebaseFirestore _db;
  DocumentReference<Json> get _user => _db.collection('users').doc(uid);

  @override
  Stream<List<Doc>> watch(String c) => _user.collection(c).snapshots(includeMetadataChanges: false).map(
      (s) => [for (final d in s.docs) (d.id, _fromFire(d.data())! as Json)]);

  @override
  Stream<Json> watchUser() => _user.snapshots().map((d) => (_fromFire(d.data() ?? <String, dynamic>{})! as Map).cast<String, dynamic>());

  /// 오프라인이면 서버 확인이 오지 않는다. 기기에는 이미 저장됐으므로 오래 기다리지 않는다.
  /// 권한 오류는 보통 이 시간 안에 돌아온다.
  Future<void> _ack(Future<void> f) => f.timeout(const Duration(seconds: 3), onTimeout: () {});

  @override
  Future<void> set(String c, String id, Json data) => _ack(_user.collection(c).doc(id).set(data));

  @override
  Future<void> remove(String c, String id) => _ack(_user.collection(c).doc(id).delete());

  @override
  Future<void> mergeUser(Json data) =>
      _ack(_user.set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));

  @override
  String newId() => _db.collection('_').doc().id;
}

class MemoryStore implements Store {
  final _docs = <String, Map<String, Json>>{};
  final _user = <String, dynamic>{};
  final _ch = StreamController<String>.broadcast(sync: true);
  var _n = 0;

  List<Doc> _list(String c) => [for (final e in (_docs[c] ?? const <String, Json>{}).entries) (e.key, {...e.value})];

  @override
  Stream<List<Doc>> watch(String c) async* {
    yield _list(c);
    yield* _ch.stream.where((x) => x == c).map((_) => _list(c));
  }

  @override
  Stream<Json> watchUser() async* {
    yield {..._user};
    yield* _ch.stream.where((x) => x == '#user').map((_) => {..._user});
  }

  @override
  Future<void> set(String c, String id, Json data) async {
    (_docs[c] ??= {})[id] = {...data};
    _ch.add(c);
  }

  @override
  Future<void> remove(String c, String id) async {
    _docs[c]?.remove(id);
    _ch.add(c);
  }

  @override
  Future<void> mergeUser(Json data) async {
    _user.addAll(data);
    _ch.add('#user');
  }

  @override
  String newId() => 'm${_n++}';
}
