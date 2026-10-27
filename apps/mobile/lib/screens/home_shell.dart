import 'package:flutter/material.dart';

import '../analytics/analytics_tracker.dart';
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
    this.onRequestLogin,
    this.onLoggedOut,
  });

  final ApiClient api;
  final LocalStore? localStore;
  final bool offlineMode;
  final void Function(LocalStore store)? onLocalStoreReady;
  /// Opens login; returns true if the user signed in.
  final Future<bool> Function()? onRequestLogin;
  /// Called after credentials are cleared (stay on guest home).
  final VoidCallback? onLoggedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final _storiesKey = GlobalKey<StoriesTabState>();
  final _meKey = GlobalKey<MeTabState>();
  bool _offlineBannerShown = false;

  @override
  void initState() {
    super.initState();
    AnalyticsTracker.instance.bind(widget.api);
    if (!widget.offlineMode) {
      AnalyticsTracker.instance.track('app_open');
    }
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
                onRequestLogin: widget.onRequestLogin,
              ),
              MeTab(
                key: _meKey,
                api: widget.api,
                localStore: store,
                onLocalStoreReady: widget.onLocalStoreReady,
                onRequestLogin: widget.onRequestLogin,
                onLoggedOut: widget.onLoggedOut,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          final leavingStories = index == 0 && i != 0;
          setState(() => index = i);
          if (i == 0) {
            _storiesKey.currentState?.setTabActive(true);
            _storiesKey.currentState?.reload();
          } else {
            if (leavingStories) {
              _storiesKey.currentState?.setTabActive(false);
            }
            if (i == 1) {
              _meKey.currentState?.reload(quiet: true);
            }
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
