import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mm_app/data/app_model.dart';
import 'package:mm_app/domain/growth.dart';
import 'package:mm_app/domain/money.dart';
import 'package:mm_app/domain/notice_parser.dart';
import 'package:mm_app/theme/app_theme.dart';

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({super.key, required AppModel model, required super.child}) : super(notifier: model);
  static AppModel of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppModel read(BuildContext c) => c.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// 새 화면에도 같은 모델을 넘긴다.
Future<T?> push<T>(BuildContext c, Widget page) {
  final m = AppScope.read(c);
  return Navigator.push<T>(c, MaterialPageRoute(builder: (_) => AppScope(model: m, child: page)));
}

Future<T?> sheet<T>(BuildContext c, Widget child) {
  final m = AppScope.read(c);
  return showModalBottomSheet<T>(
      context: c, isScrollControlled: true, useSafeArea: true, showDragHandle: true, backgroundColor: AppColors.background,
      builder: (x) => AppScope(model: m, child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(x).bottom), child: SingleChildScrollView(child: child))));
}

/// 99.6% 를 100% 로 올려 보이지 않는다.
String percentText(double p) => p < 10 ? '${(p * 10).floor() / 10}' : '${p.clamp(0, 999).floor()}';

/// 제스처 바에 가리지 않게 아래 여백을 더한다.
EdgeInsets pagePad(BuildContext c) => EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(c).bottom);

void toast(BuildContext c, String s) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(s)));

/// 저장이 실패하면 이유를 보이고 화면을 그대로 둔다.
Future<bool> attempt(BuildContext c, Future<void> Function() f) async {
  try {
    await f();
    return true;
  } catch (e) {
    if (c.mounted) toast(c, saveError(e));
    return false;
  }
}

String saveError(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied')) return '저장 권한이 없어요. 다시 로그인해 주세요.';
  if (s.contains('unavailable')) return '네트워크에 연결할 수 없어요. 연결되면 다시 시도해 주세요.';
  if (e is ArgumentError) return '${e.message}';
  return '저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(18), this.onTap});
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Material(
          color: color ?? AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22), side: color == null ? BorderSide(color: AppColors.line) : BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: SizedBox(width: double.infinity, child: child)))));
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]);
}

class Won extends StatelessWidget {
  const Won(this.value, {super.key, this.size = 30, this.color});
  final int value;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.toDouble()),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: 600),
          curve: Curves.easeOutExpo,
          builder: (_, v, _) => Text(won(v.round()),
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color ?? AppColors.deep, letterSpacing: -.6, fontFeatures: [FontFeature.tabularFigures()]))));
}

class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.color, this.track, this.height = 10});
  final double value, height;
  final Color? color, track;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.isFinite ? value.clamp(0, 1).toDouble() : 0),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: 700),
          curve: Curves.easeOutExpo,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: height, color: color ?? AppColors.olive, backgroundColor: track ?? AppColors.mist)));
}

class Donut extends StatelessWidget {
  const Donut(this.values, {super.key, required this.child, this.size = 148});
  final List<int> values;
  final Widget child;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size, child: CustomPaint(painter: _DonutPainter(values), child: Center(child: SizedBox(width: size * .6, child: child))));
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.v);
  final List<int> v;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width * .17, r = Rect.fromLTWH(w / 2, w / 2, s.width - w, s.height - w);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    final total = v.fold(0, (a, b) => a + b);
    if (total == 0) {
      c.drawArc(r, 0, 2 * pi, false, p..color = AppColors.mist);
      return;
    }
    var a = -pi / 2;
    for (final (i, x) in v.indexed) {
      final sweep = 2 * pi * x / total;
      c.drawArc(r, a, max(0, sweep - (v.length > 1 ? .025 : 0)), false, p..color = AppColors.chart[i % AppColors.chart.length]);
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => !listEquals(o.v, v);
  static bool listEquals(List<int> a, List<int> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
}

class TrendLine extends StatelessWidget {
  const TrendLine(this.values, {super.key});
  final List<int> values;
  @override
  Widget build(BuildContext context) => SizedBox(height: 84, width: double.infinity, child: CustomPaint(painter: _TrendPainter(values)));
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.v);
  final List<int> v;
  @override
  void paint(Canvas c, Size s) {
    if (v.length < 2) return;
    final lo = v.reduce(min), hi = v.reduce(max), span = max(1, hi - lo);
    Offset at(int i) => Offset(4 + (s.width - 8) * i / (v.length - 1), 8 + (s.height - 16) * (1 - (v[i] - lo) / span));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < v.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(s.width - 4, s.height)
      ..lineTo(4, s.height)
      ..close();
    c.drawPath(area, Paint()..color = AppColors.ink.withValues(alpha: .1));
    c.drawPath(line, Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.4);
    c.drawCircle(at(v.length - 1), 4.5, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_TrendPainter o) => true;
}

/// 팀 캐릭터. 단계에 따라 머리 위 장식이 바뀐다.
class Mascot extends StatefulWidget {
  const Mascot({super.key, required this.stage, this.size = 88, this.worried = false, this.percent = 0, this.crowns = 1});
  final PetStage stage;
  final double size, percent;
  final bool worried;
  final int crowns;
  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: Duration(milliseconds: 2600));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _a.stop() : _a.repeat(reverse: true);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: '펫, ${widget.stage.label} 단계${widget.worried ? ', 걱정하는 중' : ''}',
      child: RepaintBoundary(
          child: AnimatedBuilder(
              animation: _a,
              builder: (_, child) => Transform.translate(offset: Offset(0, -Curves.easeInOut.transform(_a.value) * widget.size * .025), child: child),
              child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                        top: widget.size * .12,
                        child: Image.asset('assets/images/mascot.png', fit: BoxFit.contain, filterQuality: FilterQuality.medium, excludeFromSemantics: true)),
                    Positioned.fill(child: CustomPaint(painter: StageDecor(widget.stage, widget.percent, widget.crowns, widget.worried))),
                  ])))));
}

class StageDecor extends CustomPainter {
  StageDecor(this.stage, this.percent, this.crowns, this.worried);
  final PetStage stage;
  final double percent;
  final int crowns;
  final bool worried;
  static const _line = Color(0xFF8A4B25);

  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 100);
    final o = Offset(43, 16);
    Paint f(Color k) => Paint()..color = k;
    final st = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;
    switch (stage) {
      case PetStage.none || PetStage.seed || PetStage.sprout:
        break;
      case PetStage.growing:
        for (var i = 0; i < growthTicks(percent).clamp(1, 4); i++) {
          c.save();
          c.translate(o.dx + [-9.0, 10.0, -5.0, 6.0][i], o.dy - [0.0, 2.0, 6.0, 8.0][i]);
          c.rotate([-.9, .9, -.4, .4][i]);
          final leaf = Path()
            ..moveTo(0, 4)
            ..quadraticBezierTo(-5, -2, 0, -8)
            ..quadraticBezierTo(5, -2, 0, 4);
          c.drawPath(leaf, f(Color(0xFF8FB258)));
          c.drawPath(leaf, st..color = Color(0xFF4F6B2C));
          c.restore();
        }
      case PetStage.flower:
        if (percent < 50) {
          final bud = Path()
            ..moveTo(o.dx, o.dy + 4)
            ..cubicTo(o.dx - 9, o.dy, o.dx - 5, o.dy - 9, o.dx, o.dy - 11)
            ..cubicTo(o.dx + 5, o.dy - 9, o.dx + 9, o.dy, o.dx, o.dy + 4);
          c.drawPath(bud, f(Color(0xFFF6A6A0)));
          c.drawPath(bud, st);
        } else {
          c.drawCircle(o.translate(0, -4), 19, Paint()..shader = RadialGradient(colors: [Color(0xFFFFE9A8), Color(0xFFFFE9A8).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o.translate(0, -4), radius: 19)));
          for (var i = 0; i < 5; i++) {
            final a = -pi / 2 + i * 2 * pi / 5;
            final p = o.translate(cos(a) * 6.4, sin(a) * 6.4 - 4);
            c.drawCircle(p, 4.8, f(Color(0xFFF6A6A0)));
            c.drawCircle(p, 4.8, st);
          }
          c.drawCircle(o.translate(0, -4), 4, f(Color(0xFFFFC94F)));
        }
      case PetStage.fruit:
        final ripe = percent >= 100;
        for (final (dx, dy) in ripe ? [(-9.0, 0.0), (9.0, -1.0), (0.0, -6.0)] : [(-6.0, 0.0), (6.0, -1.0)]) {
          c.drawCircle(o.translate(dx, dy - 3), 5.2, f(Color(0xFFE8703F)));
          c.drawCircle(o.translate(dx, dy - 3), 5.2, st);
          c.drawCircle(o.translate(dx - 1.6, dy - 5), 1.3, f(Colors.white70));
        }
      case PetStage.crown:
        final w = 13.0;
        final p = Path()
          ..moveTo(o.dx - w, o.dy + 3)
          ..lineTo(o.dx - w - 1, o.dy - 10)
          ..lineTo(o.dx - w / 2, o.dy - 4)
          ..lineTo(o.dx, o.dy - 13)
          ..lineTo(o.dx + w / 2, o.dy - 4)
          ..lineTo(o.dx + w + 1, o.dy - 10)
          ..lineTo(o.dx + w, o.dy + 3)
          ..close();
        c.drawPath(p, f(Color(0xFFFFCB45)));
        c.drawPath(p, st);
        for (var i = 0; i < crowns.clamp(1, 3); i++) {
          c.drawCircle(o.translate([0.0, -7.0, 7.0][i], -1), 1.9, f(Color(0xFFD8503A)));
        }
    }
    if (worried) {
      final d = Path()
        ..moveTo(84, 22)
        ..quadraticBezierTo(90, 31, 84, 34)
        ..quadraticBezierTo(78, 31, 84, 22);
      c.drawPath(d, f(Color(0xFF6FAEDD)));
    }
  }

  @override
  bool shouldRepaint(StageDecor o) => o.stage != stage || o.percent != percent || o.worried != worried || o.crowns != crowns;
}

/// 캐릭터가 말을 거는 줄.
class MascotSays extends StatelessWidget {
  const MascotSays(this.title, this.body, {super.key, this.worried = false, this.onTap});
  final String title;
  final String body;
  final bool worried;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    return SoftCard(
        color: worried ? AppColors.accentSoft : AppColors.mist,
        padding: EdgeInsets.fromLTRB(10, 6, 14, 6),
        onTap: onTap,
        child: Row(children: [
          Mascot(stage: m.stage, size: 84, percent: m.percent, crowns: m.completedGoals, worried: worried),
          SizedBox(width: 8),
          Expanded(
              child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: worried ? AppColors.accent : AppColors.text)),
                    if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4)),
                  ]))),
        ]));
  }
}

IconData categoryIcon(Category c) => switch (c) {
      Category.food => Icons.restaurant_outlined,
      Category.cafe => Icons.local_cafe_outlined,
      Category.transport => Icons.directions_bus_outlined,
      Category.shopping => Icons.shopping_bag_outlined,
      Category.living => Icons.home_repair_service_outlined,
      Category.health => Icons.favorite_border,
      Category.culture => Icons.movie_outlined,
      Category.fixed => Icons.event_repeat_outlined,
      Category.etc => Icons.more_horiz,
    };

/// 양 끝에 놓고, 자리가 모자라면 아래로 내린다.
class Between extends StatelessWidget {
  const Between(this.a, this.b, {super.key});
  final Widget a, b;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 2, children: [a, b]));
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color});
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
      width: 40, height: 40, decoration: BoxDecoration(color: color ?? AppColors.mist, borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, size: 21, color: AppColors.deep));
}

/// 천 단위 쉼표를 넣어 주는 금액 칸.
class MoneyField extends StatelessWidget {
  const MoneyField(this.controller, this.label, {super.key, this.helper, this.autofocus = false, this.allowZero = false});
  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool autofocus, allowZero;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12), CommaFormatter()],
          validator: (s) {
            final v = parseWon(s ?? '');
            if (v == null) return '금액을 숫자로 입력해 주세요';
            return v == 0 && !allowZero ? '1원 이상 입력해 주세요' : null;
          },
          decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 2, suffixText: '원')));
}

class CommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue a, TextEditingValue b) {
    if (b.text.isEmpty) return b;
    final t = comma(int.parse(b.text));
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

class SaveButton extends StatefulWidget {
  const SaveButton(this.label, this.onSave, {super.key});
  final String label;
  final Future<void> Function() onSave;
  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  var busy = false;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  await widget.onSave();
                  if (mounted) setState(() => busy = false);
                },
          child: busy ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ink)) : Text(widget.label)));
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.sub, height: 1.5))));
}
