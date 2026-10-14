import 'package:flutter/material.dart';

import '../api/client.dart';
import '../theme/app_theme.dart';
import 'me_tab.dart';
import 'stories_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final _storiesKey = GlobalKey<StoriesTabState>();

  late final List<Widget> _pages = [
    StoriesTab(key: _storiesKey, api: widget.api),
    MeTab(api: widget.api),
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
        onDestinationSelected: (i) {
          setState(() => index = i);
          if (i == 0) {
            _storiesKey.currentState?.reload();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '故事',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
