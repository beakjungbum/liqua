import 'package:flutter/material.dart';
import 'package:mm_app/models/asset.dart';
import 'package:mm_app/models/entry.dart';
import 'package:mm_app/services/asset_service.dart';
import 'package:mm_app/services/auth_service.dart';
import 'package:mm_app/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final List<Entry> entries;
  final int goal;
  final void Function()? onSettings;
  const HomeScreen({
    super.key,
    this.entries = const [],
    this.goal = 0,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final food = entries
        .where((e) => !e.income && e.category == '식비')
        .fold(0, (s, e) => s + e.amount);
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Asset>>(
          stream: AssetService.instance.watch(),
          builder: (context, assetSnapshot) {
            final assets = assetSnapshot.data ?? const <Asset>[];
            final total = assets.fold<double>(
              0,
              (sum, asset) => sum + asset.valuation,
            );
            return StreamBuilder<UserProgress>(
              stream: AuthService.instance.watchProgress(),
              builder: (context, progressSnapshot) {
                final progress = progressSnapshot.data ?? const UserProgress();
                final target = progressSnapshot.hasData
                    ? progress.targetAmount
                    : goal;
                final percent = achievementPercent(total, target);
                final bar = (percent / 100).clamp(0.0, 1.0);
                final empty = assets.isEmpty;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        const Text(
                          '총 자산',
                          style: TextStyle(color: AppColors.sub),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onSettings,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                    Text(
                      formatWon(total),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${progress.points}점 · ${progress.currentLevel}레벨',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.sub,
                      ),
                    ),
                    if (empty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '자산 탭에서 첫 내역을 기록해 보세요!',
                          style: TextStyle(fontSize: 14, color: AppColors.sub),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _card('목표 달성률', '${percent.round()}%', bar),
                    const SizedBox(height: 12),
                    _card('이번 달 식비', '$food원', null),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Widget _card(String title, String value, double? bar) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: const BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.all(Radius.circular(20)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      if (bar != null) const SizedBox(height: 14),
      if (bar != null)
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: LinearProgressIndicator(
            value: bar,
            minHeight: 10,
            backgroundColor: AppColors.background,
            color: AppColors.primary,
          ),
        ),
    ],
  ),
);
