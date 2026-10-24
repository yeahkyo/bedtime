import 'package:flutter/material.dart';

import '../api/client.dart';
import '../config.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../local/user_scope.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import 'children_manage_screen.dart';
import 'voices_manage_screen.dart';

/// Tab 2: profile card + settings entries.
class MeTab extends StatefulWidget {
  const MeTab({
    super.key,
    required this.api,
    this.localStore,
    this.onLocalStoreReady,
    this.onLoggedOut,
  });

  final ApiClient api;
  final LocalStore? localStore;
  final void Function(LocalStore store)? onLocalStoreReady;
  final VoidCallback? onLoggedOut;

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  bool loading = true;
  bool loggedIn = false;
  String displayName = '';
  String? quotaText;
  String? error;

  LocalStore? get _store => widget.localStore;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _applySnapshot(Map<String, dynamic> snap) {
    final name = (snap['display_name'] as String?)?.trim();
    final q = snap['quota'] as Map<String, dynamic>?;
    loggedIn = true;
    displayName = (name != null && name.isNotEmpty) ? name : '枕边家长';
    if (q != null) {
      final story = '本月故事 ${q['story_used']}/${q['story_limit']}';
      quotaText = kFeatureVoiceClone
          ? '$story · 克隆 ${q['clone_used']}/${q['clone_limit']}'
          : story;
    }
  }

  Future<LocalStore?> _ensureStore(Map<String, dynamic> me) async {
    final id = me['id'];
    final userId = id is int ? id : int.tryParse('$id');
    if (userId == null || userId <= 0) return _store;
    if (_store != null && _store!.userId == userId) return _store;
    await UserScope.save(userId);
    final store = await LocalStore.openOrBootstrap(api: widget.api, userId: userId);
    widget.onLocalStoreReady?.call(store);
    return store;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    final hasToken = widget.api.token != null && widget.api.token!.isNotEmpty;
    final hasRefresh =
        widget.api.refreshToken != null && widget.api.refreshToken!.isNotEmpty;
    if (!hasToken && !hasRefresh) {
      if (!mounted) return;
      setState(() {
        loggedIn = false;
        displayName = '';
        quotaText = null;
        loading = false;
      });
      return;
    }

    final store = _store;
    if (store != null) {
      final cached = await store.account.loadCached();
      if (cached != null && mounted) {
        setState(() {
          _applySnapshot(cached);
          loading = false;
        });
      }
    }

    try {
      if (store != null) {
        final snap = await store.account.refresh(
          onCached: (cached) {
            if (!mounted || cached == null) return;
            setState(() {
              _applySnapshot(cached);
              loading = false;
            });
          },
          onNetworkError: (msg) {
            if (!mounted) return;
            setState(() {
              error = msg;
              loading = false;
              if (displayName.isNotEmpty) loggedIn = true;
            });
          },
        );
        if (!mounted) return;
        if (snap != null) {
          setState(() {
            _applySnapshot(snap);
            loading = false;
            error = null;
          });
        } else {
          setState(() => loading = false);
        }
        return;
      }

      final me = await widget.api.me();
      final q = await widget.api.quota();
      final ensured = await _ensureStore(me);
      await ensured?.account.saveSnapshot(me: me, quota: q);
      if (!mounted) return;
      setState(() {
        loggedIn = true;
        displayName = (me['display_name'] as String?)?.trim().isNotEmpty == true
            ? me['display_name'] as String
            : '枕边家长';
        final story = '本月故事 ${q['story_used']}/${q['story_limit']}';
        quotaText = kFeatureVoiceClone
            ? '$story · 克隆 ${q['clone_used']}/${q['clone_limit']}'
            : story;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.unauthorized) {
        setState(() {
          loggedIn = false;
          displayName = '';
          quotaText = null;
          loading = false;
        });
        return;
      }
      setState(() {
        error = e.message;
        loading = false;
        if (displayName.isNotEmpty) loggedIn = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = friendlyNetworkError(e);
        loading = false;
        if (displayName.isNotEmpty) loggedIn = true;
      });
    }
  }

  Future<void> _logout() async {
    setState(() => loading = true);
    try {
      await widget.api.logout();
    } catch (_) {
      /* ignore */
    }
    if (!mounted) return;
    final leave = widget.onLoggedOut;
    if (leave != null) {
      leave();
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && displayName.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        BrandHeader(
          title: '我的',
          subtitle: quotaText,
        ),
        const SizedBox(height: 18),
        _ProfileCard(
          loggedIn: loggedIn,
          displayName: displayName,
          onLogin: () {
            // Root gate owns AuthScreen; request session end → login.
            widget.onLoggedOut?.call();
          },
          onLogout: _logout,
          onRefresh: _load,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent)),
        ],
        const SizedBox(height: 22),
        Text('设置', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.mic_none,
          title: '音色管理',
          subtitle: kFeatureVoiceClone ? '系统音色与家长声音克隆' : '系统朗读音色',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => VoicesManageScreen(api: widget.api)),
            );
          },
        ),
        const SizedBox(height: 10),
        _SettingsTile(
          icon: Icons.child_care_outlined,
          title: '角色管理',
          subtitle: '小听众档案与故事角色',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChildrenManageScreen(api: widget.api)),
            );
          },
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.loggedIn,
    required this.displayName,
    required this.onLogin,
    required this.onLogout,
    required this.onRefresh,
  });

  final bool loggedIn;
  final String displayName;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final initial = loggedIn && displayName.isNotEmpty
        ? displayName.characters.first
        : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.secondaryContainer,
            child: Text(
              initial,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.secondary,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loggedIn ? displayName : '未登录',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  loggedIn ? '已连接枕边故事服务' : '登录后可同步故事与音色',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!loggedIn)
            FilledButton(
              onPressed: onLogin,
              child: const Text('登录'),
            )
          else ...[
            IconButton(
              tooltip: '刷新',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.onSurfaceMuted),
            ),
            TextButton(
              onPressed: onLogout,
              child: const Text('退出'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primarySoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceDim),
            ],
          ),
        ),
      ),
    );
  }
}
