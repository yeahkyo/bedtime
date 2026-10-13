import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import 'create_story_screen.dart';
import 'history_screen.dart';
import 'voice_clone_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  late final List<Widget> _pages = [
    CreateStoryScreen(api: widget.api),
    HistoryScreen(api: widget.api),
    VoiceCloneScreen(api: widget.api),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121A29), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: index,
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '创作室',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '藏书阁',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: '音色',
          ),
        ],
      ),
    );
  }
}
