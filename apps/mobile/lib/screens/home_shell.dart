import 'package:flutter/material.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../local/local_store.dart';
import '../theme/app_theme.dart';
import 'me_tab.dart';
import 'stories_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.api,
    this.localStore,
    this.offlineMode = false,
    this.onLocalStoreReady,
    this.onLoggedOut,
  });

  final ApiClient api;
  final LocalStore? localStore;
  final bool offlineMode;
  final void Function(LocalStore store)? onLocalStoreReady;
  /// Called after credentials are cleared so the root gate can show AuthScreen.
  final VoidCallback? onLoggedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final _storiesKey = GlobalKey<StoriesTabState>();
  bool _offlineBannerShown = false;

  @override
  void initState() {
    super.initState();
    if (widget.offlineMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _offlineBannerShown) return;
        _offlineBannerShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).homeOfflineSnackbar)),
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offlineMode && !oldWidget.offlineMode && !_offlineBannerShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _offlineBannerShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).homeOfflineSnackbar)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.localStore;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121828), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: index,
            children: [
              StoriesTab(
                key: _storiesKey,
                api: widget.api,
                localStore: store,
              ),
              MeTab(
                api: widget.api,
                localStore: store,
                onLocalStoreReady: widget.onLocalStoreReady,
                onLoggedOut: widget.onLoggedOut,
              ),
            ],
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: AppLocalizations.of(context).tabStories,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: AppLocalizations.of(context).meTitle,
          ),
        ],
      ),
    );
  }
}
