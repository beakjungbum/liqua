import 'dart:async';
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
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(x).bottom + MediaQuery.viewPaddingOf(c).bottom), child: SingleChildScrollView(child: child))));
}

/// 99.6% 를 100% 로 올려 보이지 않는다.
String percentText(double p) => p < 10 ? '${(p * 10).floor() / 10}' : '${p.clamp(0, 999).floor()}';

/// 제스처 바에 가리지 않게 아래 여백을 더한다.
EdgeInsets pagePad(BuildContext c) => EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.paddingOf(c).bottom);

/// 저장하는 사이 경고가 위에 떠도 경고가 아니라 이 화면을 닫는다.
void closeThis(BuildContext c) {
  final r = ModalRoute.of(c);
  if (r == null) return;
  r.isCurrent ? Navigator.pop(c) : Navigator.of(c).removeRoute(r);
}

/// 원인을 찾을 수 있게 에러 원문을 짧게 보인다. 긴 토큰은 가린다.
String errorDetail(Object e) {
  final s = e.toString().replaceAll(RegExp(r'[A-Za-z0-9_\-]{32,}'), '…').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > 220 ? '${s.substring(0, 220)}…' : s;
}

void toast(BuildContext c, String s) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(s)));

/// 저장이 실패하면 이유를 보이고 화면을 그대로 둔다.
/// 0.4초 안에 답한다(도허티 임계). 그 뒤에 온 실패는 나중에 알린다.
Future<bool> attempt(BuildContext c, Future<void> Function() f) {
  final messenger = ScaffoldMessenger.of(c);
  final done = Completer<bool>();
  final timer = Timer(const Duration(milliseconds: 400), () {
    if (!done.isCompleted) done.complete(true);
  });
  f().then((_) {
    HapticFeedback.lightImpact();
    if (!done.isCompleted) done.complete(true);
  }, onError: (Object e) {
    if (!done.isCompleted) done.complete(false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(saveError(e))));
  }).whenComplete(timer.cancel);
  return done.future;
}

String saveError(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied')) return '저장 권한이 없어요. 다시 로그인해 주세요.';
  if (s.contains('unavailable') || e is TimeoutException) return '네트워크에 연결할 수 없어요. 연결되면 다시 시도해 주세요.';
  if (e is ArgumentError) return '${e.message}';
  return '저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(16), this.onTap});
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

/// 팀 캐릭터. 단계마다 그림과 크기가 바뀐다.
/// 왕관 단계는 달성한 목표 수만큼 왕관이 바뀐다(6개째부터 같은 그림).
String petImage(PetStage s, {int crowns = 1}) => 'assets/images/pets/${switch (s) {
      PetStage.none || PetStage.seed => 'seed',
      PetStage.sprout => 'sprout',
      PetStage.growing => 'growing',
      PetStage.flower => 'flower',
      PetStage.fruit => 'fruit',
      PetStage.crown => 'crown${crowns.clamp(1, 6)}',
    }}.png';

/// 앞 단계일수록 작게 그려 자라는 느낌을 준다.
double petScale(PetStage s) => switch (s) {
      PetStage.none || PetStage.seed => .6,
      PetStage.sprout => .72,
      PetStage.growing => .86,
      PetStage.flower || PetStage.fruit => .94,
      PetStage.crown => 1,
    };

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
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
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
  Widget build(BuildContext context) {
    final k = petScale(widget.stage);
    return Semantics(
        image: true,
        label: '펫, ${widget.stage.label} 단계${widget.worried ? ', 걱정하는 중' : ''}',
        child: RepaintBoundary(
            child: SizedBox.square(
                dimension: widget.size,
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                  AnimatedBuilder(
                      animation: _a,
                      builder: (_, child) => Transform.translate(offset: Offset(0, -Curves.easeInOut.transform(_a.value) * widget.size * .025), child: child),
                      child: AnimatedSwitcher(
                          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 500),
                          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: .8, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: FadeTransition(opacity: a, child: c)),
                          child: Image.asset(petImage(widget.stage, crowns: widget.crowns),
                              key: ValueKey(petImage(widget.stage, crowns: widget.crowns)), width: widget.size * k, height: widget.size * k, fit: BoxFit.contain, filterQuality: FilterQuality.medium, excludeFromSemantics: true))),
                  if (widget.worried) Positioned.fill(child: CustomPaint(painter: _Drop())),
                ]))));
  }
}

class _Drop extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 100);
    final d = Path()
      ..moveTo(84, 22)
      ..quadraticBezierTo(90, 31, 84, 34)
      ..quadraticBezierTo(78, 31, 84, 22);
    c.drawPath(d, Paint()..color = const Color(0xFF6FAEDD));
  }

  @override
  bool shouldRepaint(_Drop o) => false;
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
        padding: EdgeInsets.fromLTRB(8, 8, 16, 8),
        onTap: onTap,
        child: Row(children: [
          Mascot(stage: m.stage, size: 84, percent: m.percent, crowns: m.completedGoals, worried: worried),
          SizedBox(width: 8),
          Expanded(
              child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: worried ? AppColors.accent : AppColors.text)),
                    if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4)),
                  ]))),
        ]));
  }
}

IconData categoryIcon(Category c) => switch (c) {
      Category.food => Icons.restaurant_rounded,
      Category.cafe => Icons.local_cafe_rounded,
      Category.transport => Icons.directions_bus_rounded,
      Category.shopping => Icons.shopping_bag_rounded,
      Category.living => Icons.home_repair_service_rounded,
      Category.health => Icons.favorite_rounded,
      Category.culture => Icons.movie_rounded,
      Category.fixed => Icons.event_repeat_rounded,
      Category.etc => Icons.more_horiz_rounded,
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
      width: 44, height: 44, decoration: BoxDecoration(color: color ?? AppColors.mist, borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, size: 24, color: AppColors.text));
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
          child: Text(busy ? '저장하는 중' : widget.label)));
}

/// 주황 버튼은 화면에 하나만 둔다(폰 레스토프 효과). 나머지는 이 모양을 쓴다.
ButtonStyle tonal() => FilledButton.styleFrom(backgroundColor: AppColors.mist, foregroundColor: AppColors.text);

/// 들어올 내용과 같은 자리를 먼저 보여 준다.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width = double.infinity, this.height = 16, this.radius = 8});
  final double width, height, radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900), value: 1);
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
  Widget build(BuildContext context) => FadeTransition(
      opacity: Tween(begin: .45, end: 1.0).animate(_a),
      child: Container(width: widget.width, height: widget.height, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(widget.radius))));
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: '불러오는 중',
      child: ListView(physics: NeverScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(20, 16, 20, 0), children: [
        Align(alignment: Alignment.centerLeft, child: Skeleton(width: 88)),
        SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Skeleton(width: 200, height: 36)),
        SizedBox(height: 16),
        Skeleton(height: 168, radius: 22),
        SizedBox(height: 12),
        Skeleton(height: 112, radius: 22),
        SizedBox(height: 24),
        Skeleton(height: 224, radius: 22),
      ]));
}

/// 당겨서 새로고침. 실패하면 이유를 알린다.
class RefreshPage extends StatelessWidget {
  const RefreshPage({super.key, required this.child, this.also});
  final Widget child;
  final Future<void> Function()? also;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
      color: AppColors.ink,
      backgroundColor: AppColors.main,
      onRefresh: () async {
        HapticFeedback.selectionClick();
        final m = AppScope.read(context);
        try {
          await Future.wait([m.refresh(), if (also != null) also!()]);
        } catch (e) {
          if (context.mounted) toast(context, saveError(e));
        }
      },
      child: child);
}

/// 홈의 「오늘 할 일」 한 줄.
class TodoRow extends StatelessWidget {
  const TodoRow(this.icon, this.text, this.value, {super.key, this.onTap, this.strong = false});
  final IconData icon;
  final String text, value;
  final VoidCallback? onTap;
  final bool strong;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 48),
          child: Row(children: [
            Icon(icon, size: 24, color: strong ? AppColors.accent : AppColors.olive),
            SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: strong ? AppColors.accent : AppColors.text))),
            SizedBox(width: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700)),
          ])));
}

/// 분류마다 같은 색을 써서 글자를 읽기 전에 알아본다.
Color categoryTint(Category c) {
  final base = switch (c) {
    Category.food => AppColors.peach,
    Category.cafe => Color(0xFFD9C9A3),
    Category.transport => Color(0xFFA9C2C4),
    Category.shopping => Color(0xFFE8B7B0),
    Category.living => AppColors.sage,
    Category.health => Color(0xFFB9D0AE),
    Category.culture => Color(0xFFC6BBD6),
    Category.fixed => AppColors.main,
    Category.etc => Color(0xFFCCCFC2),
  };
  return Color.lerp(AppColors.card, base, AppColors.dark ? .38 : .62)!;
}

class Empty extends StatelessWidget {
  const Empty(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.sub, height: 1.5))));
}
