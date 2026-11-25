import 'package:flutter/material.dart';
import 'package:mm_app/models/entry.dart';
import 'package:mm_app/screens/home_screen.dart';
import 'package:mm_app/screens/asset_screen.dart';
import 'package:mm_app/screens/goal_screen.dart';
import 'package:mm_app/screens/chat_screen.dart';
import 'package:mm_app/screens/settings_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}
class _ShellScreenState extends State<ShellScreen> {
  int index = 0; // 0:홈, 1:자산, 2:목표, 3:챗봇
  int goal = 0; // 목표 금액
  final entries = <Entry>[]; // 수입·지출 목록
  final questions = <String>[]; // 질문 목록
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(entries: entries, goal: goal, onSettings: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),

      AssetScreen(entries: entries, onAdd: (e) => setState(() => entries.add(e))),

      GoalScreen(goal: goal, onSave: (v) => setState(() => goal = v)),
      
      ChatScreen(questions: questions, onAsk: (t) => setState(() => questions.add(t))),
      ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: index,
        onTap: (v) => setState(() => index = v),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: '자산'),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: '목표'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '챗봇'),
        ],
      ),
    );
  }
}