import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

typedef Doc = (String id, Json data);

/// 서버 값에 더한다. 두 기기에서 동시에 저장해도 한쪽이 사라지지 않는다.
class Inc {
  const Inc(this.by);
  final num by;
}

class Op {
  const Op.set(this.collection, this.id, this.data) : merge = false;
  const Op.merge(this.collection, this.id, this.data) : merge = true;
  const Op.remove(this.collection, this.id) : data = null, merge = false;
  const Op.user(this.data) : collection = null, id = null, merge = true;
  final String? collection, id;
  final Json? data;
  final bool merge;
}

/// 저장소. 로그인하면 Firestore, 둘러보기는 메모리를 쓴다.
abstract class Store {
  /// 사용자 문서 아래의 모든 컬렉션.
  static const collections = ['transactions', 'assets', 'fixed', 'notices', 'snapshots'];

  /// 계정 삭제용. 이 사용자의 모든 데이터를 지운다.
  Future<void> wipe();

  Stream<List<Doc>> watch(String collection);
  Stream<Json> watchUser();
  /// 한 번에 모두 저장하거나 하나도 저장하지 않는다.
  Future<void> commit(List<Op> ops);
  Future<void> set(String collection, String id, Json data) => commit([Op.set(collection, id, data)]);
  Future<void> remove(String collection, String id) => commit([Op.remove(collection, id)]);
  Future<void> mergeUser(Json data) => commit([Op.user(data)]);
  String newId();

  /// 캐시가 아니라 서버 값을 다시 읽는다.
  Future<void> refresh() async {}
}

Object? _fromFire(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      Map m => {for (final e in m.entries) '${e.key}': _fromFire(e.value)},
      List l => [for (final e in l) _fromFire(e)],
      _ => v,
    };

class FirestoreStore extends Store {
  FirestoreStore(this.uid, {FirebaseFirestore? db, this.onLateError}) : _db = db ?? FirebaseFirestore.instance;
  final String uid;
  final FirebaseFirestore _db;

  /// 오프라인에서 저장한 뒤 서버가 거절했을 때.
  void Function(Object error)? onLateError;
  DocumentReference<Json> get _user => _db.collection('users').doc(uid);

  @override
  Stream<List<Doc>> watch(String c) =>
      _user.collection(c).snapshots().map((s) => [for (final d in s.docs) (d.id, _fromFire(d.data())! as Json)]);

  /// 새 기기에서 오프라인이면 캐시가 비어 있다. 이를 새 사용자로 오해해 덮어쓰지 않도록
  /// 서버가 확인해 줄 때까지 기다린다.
  @override
  Stream<Json> watchUser() => _user
      .snapshots(includeMetadataChanges: true)
      .where((d) => !(d.metadata.isFromCache && !d.exists))
      .map((d) => (_fromFire(d.data() ?? <String, dynamic>{})! as Map).cast<String, dynamic>());

  static Json _toFire(Json d) => {for (final e in d.entries) e.key: e.value is Inc ? FieldValue.increment((e.value as Inc).by) : e.value};

  @override
  Future<void> commit(List<Op> ops) async {
    final b = _db.batch();
    for (final o in ops) {
      final ref = o.collection == null ? _user : _user.collection(o.collection!).doc(o.id);
      if (o.data == null) {
        b.delete(ref);
        continue;
      }
      final d = _toFire(o.data!);
      if (o.collection == null) d['updatedAt'] = FieldValue.serverTimestamp();
      b.set(ref, d, o.merge ? SetOptions(merge: true) : null);
    }
    // 오프라인이면 서버 확인이 오지 않는다. 기기에는 이미 저장됐으므로 오래 기다리지 않는다.
    var late = false;
    final f = b.commit().catchError((Object e) {
      if (!late) throw e;
      onLateError?.call(e);
    });
    await f.timeout(const Duration(seconds: 3), onTimeout: () => late = true);
  }

  @override
  Future<void> refresh() => Future.wait([
        _user.get(const GetOptions(source: Source.server)),
        for (final c in Store.collections)
          _user.collection(c).get(const GetOptions(source: Source.server)),
      ]).timeout(const Duration(seconds: 8));

  @override
  String newId() => _db.collection('_').doc().id;

  /// 한 번에 지울 수 있는 문서는 500개라 400개씩 나눠 지운다.
  @override
  Future<void> wipe() async {
    for (final c in Store.collections) {
      while (true) {
        final q = await _user.collection(c).limit(400).get(const GetOptions(source: Source.server));
        if (q.docs.isEmpty) break;
        final b = _db.batch();
        for (final d in q.docs) {
          b.delete(d.reference);
        }
        await b.commit();
      }
    }
    await _user.delete();
  }
}

class MemoryStore extends Store {
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
  Future<void> commit(List<Op> ops) async {
    final touched = <String>{};
    for (final o in ops) {
      final c = o.collection;
      touched.add(c ?? '#user');
      if (o.data == null) {
        _docs[c]?.remove(o.id);
        continue;
      }
      final target = c == null ? _user : (_docs[c] ??= {})[o.id!] ??= {};
      if (!o.merge) target.clear();
      o.data!.forEach((k, v) => target[k] = v is Inc ? ((target[k] as num?) ?? 0) + v.by : v);
    }
    touched.forEach(_ch.add);
  }

  @override
  String newId() => 'm${_n++}';

  @override
  Future<void> wipe() async {
    final touched = {..._docs.keys, '#user'};
    _docs.clear();
    _user.clear();
    touched.forEach(_ch.add);
  }
}
