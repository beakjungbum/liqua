import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/data/models.dart';
import 'package:mm_app/data/store.dart';
import 'package:mm_app/domain/money.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 결제 알림 읽기(Android)와 기기 안 알림.
class DeviceService {
  DeviceService._();
  static final instance = DeviceService._();
  static const _ch = MethodChannel('liqua/notices');
  final _local = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _draining = false;
  AppModel? _again;

  bool get supportsCapture => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    await _local.initialize(
        settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat'), iOS: DarwinInitializationSettings()));
    _ready = true;
  }

  Future<bool> askPermission() async =>
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true;

  Future<bool> captureEnabled() async => supportsCapture && (await _ch.invokeMethod<bool>('enabled') ?? false);
  Future<void> openCaptureSettings() async => supportsCapture ? await _ch.invokeMethod('openSettings') : null;

  /// 알림은 이 계정으로만 모은다. 다른 계정의 대기열은 읽지 않는다.
  Future<void> setOwner(String? uid) async {
    if (supportsCapture) await _ch.invokeMethod('setOwner', uid);
  }

  /// 로그아웃하면 남은 알림과 예약을 지운다.
  Future<void> clearAccount() async {
    onArrived(null);
    try {
      await setOwner(null);
      if (_ready) await _local.cancelAll();
    } catch (e) {
      debugPrint('계정 정리 실패: $e');
    }
  }

  void onArrived(Future<void> Function()? f) {
    if (!supportsCapture) return;
    _ch.setMethodCallHandler(f == null ? null : (c) async {
      if (c.method == 'arrived') await f();
    });
  }

  /// 저장까지 끝난 알림만 대기열에서 지운다.
  Future<void> drain(AppModel m) async {
    if (!supportsCapture || !m.ready || m.disposed) return;
    if (_draining) {
      _again = m;
      return;
    }
    _draining = true;
    try {
      do {
        m = _again ?? m;
        _again = null;
        final list = await _ch.invokeListMethod<String>('peek') ?? const [];
        final owner = m.store is FirestoreStore ? (m.store as FirestoreStore).uid : 'demo';
        final done = <String>[];
        for (final s in list) {
          if (m.disposed) break;
          try {
            final j = jsonDecode(s) as Map<String, dynamic>;
            if (j['owner'] != owner) continue;
            await m.handleNotice(j['raw'] as String,
                app: j['app'] as String, at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()));
            done.add(j['id'] as String);
          } catch (e) {
            debugPrint('알림 저장 실패: $e');
            break;
          }
        }
        if (done.isNotEmpty) await _ch.invokeMethod('ack', done);
      } while (_again != null);
    } finally {
      _draining = false;
    }
  }

  static const _details = NotificationDetails(
      android: AndroidNotificationDetails('liqua', 'Liqua 알림', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails());

  Future<void> alert(AppAlert a) async {
    if (!_ready) return;
    await _local.show(id: 100 + a.kind.index, title: a.title, body: a.body, notificationDetails: _details);
  }

  /// 결제일 하루 전 오전 9시. 기기 안 예약이라 서버가 필요 없다.
  static DateTime? remindAt(FixedExpense f, DateTime now) {
    if (!f.remind) return null;
    var due = f.nextDue(now);
    for (var i = 0; i < 3; i++) {
      final at = DateTime(due.year, due.month, due.day - 1, 9);
      if (at.isAfter(now)) return at;
      due = f.nextDue(DateTime(due.year, due.month, due.day + 1));
    }
    return null;
  }

  Future<void> schedule(List<FixedExpense> fixed) async {
    if (!_ready) return;
    await _local.cancelAllPendingNotifications();
    for (final (i, f) in fixed.indexed) {
      final at = remindAt(f, DateTime.now());
      if (at == null) continue;
      await _local.zonedSchedule(
          id: 1000 + i,
          title: '내일 ${f.name} 결제일이에요',
          body: '${won(f.amount)}이 나갈 예정이에요',
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
