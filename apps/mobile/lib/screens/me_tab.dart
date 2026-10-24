import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/client.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../local/local_store.dart';
import '../local/network_errors.dart';
import '../local/user_scope.dart';
import '../constants/legal_urls.dart';
import '../theme/app_theme.dart';
import '../theme/widgets.dart';
import '../utils/legal_launcher.dart';
import 'about_screen.dart';
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
  int? _storyUsed;
  int? _storyLimit;
  int? _cloneUsed;
  int? _cloneLimit;
  String? error;
  String _versionLabel = '';

  LocalStore? get _store => widget.localStore;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versionLabel = info.version);
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = '1.0.0');
    }
  }

  void _applySnapshot(Map<String, dynamic> snap, AppLocalizations l10n) {
    final name = (snap['display_name'] as String?)?.trim();
    final q = snap['quota'] as Map<String, dynamic>?;
    loggedIn = true;
    displayName =
        (name != null && name.isNotEmpty) ? name : l10n.profileDefaultName;
    if (q != null) {
      _storyUsed = q['story_used'] as int?;
      _storyLimit = q['story_limit'] as int?;
      _cloneUsed = q['clone_used'] as int?;
      _cloneLimit = q['clone_limit'] as int?;
    }
  }

  String? _quotaLine(AppLocalizations l10n) {
    if (_storyUsed == null || _storyLimit == null) return null;
    final story = l10n.quotaStories(_storyUsed!, _storyLimit!);
    if (kFeatureVoiceClone && _cloneUsed != null && _cloneLimit != null) {
      return '$story${l10n.quotaCloneSuffix(_cloneUsed!, _cloneLimit!)}';
    }
    return story;
  }

  String _languageLabel(AppLocalizations l10n) {
    switch (LocaleController.codeOf(LocaleController.instance.locale)) {
      case 'en':
        return l10n.languageEn;
      case 'zh_TW':
        return l10n.languageZhHant;
      case 'zh_CN':
      default:
        return l10n.languageZhHans;
    }
  }

  Future<LocalStore?> _ensureStore(Map<String, dynamic> me) async {
    final id = me['id'];
    final userId = id is int ? id : int.tryParse('$id');
    if (userId == null || userId <= 0) return _store;
    if (_store != null && _store!.userId == userId) return _store;
    await UserScope.save(userId);
    final store =
        await LocalStore.openOrBootstrap(api: widget.api, userId: userId);
    widget.onLocalStoreReady?.call(store);
    return store;
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
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
        _storyUsed = null;
        _storyLimit = null;
        _cloneUsed = null;
        _cloneLimit = null;
        loading = false;
      });
      return;
    }

    final store = _store;
    if (store != null) {
      final cached = await store.account.loadCached();
      if (cached != null && mounted) {
        setState(() {
          _applySnapshot(cached, l10n);
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
              _applySnapshot(cached, AppLocalizations.of(context));
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
            _applySnapshot(snap, AppLocalizations.of(context));
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
      final loc = AppLocalizations.of(context);
      setState(() {
        loggedIn = true;
        displayName = (me['display_name'] as String?)?.trim().isNotEmpty == true
            ? me['display_name'] as String
            : loc.profileDefaultName;
        _storyUsed = q['story_used'] as int?;
        _storyLimit = q['story_limit'] as int?;
        _cloneUsed = q['clone_used'] as int?;
        _cloneLimit = q['clone_limit'] as int?;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.unauthorized) {
        setState(() {
          loggedIn = false;
          displayName = '';
          _storyUsed = null;
          _storyLimit = null;
          _cloneUsed = null;
          _cloneLimit = null;
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

  Future<void> _pickLanguage(AppLocalizations l10n) async {
    final current = LocaleController.codeOf(LocaleController.instance.locale);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        Widget option(String code, String label) {
          final selected = code == current;
          return ListTile(
            title: Text(label),
            trailing: selected
                ? const Icon(Icons.check, color: AppColors.primarySoft)
                : null,
            onTap: () => Navigator.pop(ctx, code),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  l10n.languagePickerTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              option('zh_CN', l10n.languageZhHans),
              option('zh_TW', l10n.languageZhHant),
              option('en', l10n.languageEn),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen == null || !mounted) return;
    await LocaleController.instance.setLocale(LocaleController.parse(chosen));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (loading && displayName.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      children: [
        BrandHeader(
          title: l10n.meTitle,
          subtitle: _quotaLine(l10n),
        ),
        const SizedBox(height: 18),
        _ProfileCard(
          loggedIn: loggedIn,
          displayName: displayName,
          guestLabel: l10n.profileGuest,
          guestHint: l10n.profileGuestHint,
          connectedHint: l10n.profileConnected,
          loginLabel: l10n.profileLogin,
          refreshTooltip: l10n.profileRefresh,
          onLogin: () => widget.onLoggedOut?.call(),
          onRefresh: _load,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 18),
        _SettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.mic_none,
              title: l10n.meVoicesTitle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VoicesManageScreen(api: widget.api),
                  ),
                );
              },
            ),
            _SettingsRow(
              icon: Icons.child_care_outlined,
              title: l10n.meCharactersTitle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChildrenManageScreen(api: widget.api),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.language_outlined,
              title: l10n.meLanguageTitle,
              trailingText: _languageLabel(l10n),
              onTap: () => _pickLanguage(l10n),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.info_outline,
              title: l10n.meAboutTitle,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
            _SettingsRow(
              icon: Icons.description_outlined,
              title: l10n.meTermsTitle,
              onTap: () => openLegalDocument(context, LegalDocument.terms),
            ),
            _SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: l10n.mePrivacyTitle,
              onTap: () => openLegalDocument(context, LegalDocument.privacy),
            ),
          ],
        ),
        if (loggedIn) ...[
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loading ? null : _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurfaceMuted,
                side: const BorderSide(color: AppColors.outline),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
              child: Text(l10n.meLogoutAccount),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_versionLabel.isNotEmpty)
          Center(
            child: Text(
              l10n.meBrandFooter(_versionLabel),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceDim,
                  ),
            ),
          ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.loggedIn,
    required this.displayName,
    required this.guestLabel,
    required this.guestHint,
    required this.connectedHint,
    required this.loginLabel,
    required this.refreshTooltip,
    required this.onLogin,
    required this.onRefresh,
  });

  final bool loggedIn;
  final String displayName;
  final String guestLabel;
  final String guestHint;
  final String connectedHint;
  final String loginLabel;
  final String refreshTooltip;
  final VoidCallback onLogin;
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
                  loggedIn ? displayName : guestLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  loggedIn ? connectedHint : guestHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!loggedIn)
            FilledButton(
              onPressed: onLogin,
              child: Text(loginLabel),
            )
          else
            IconButton(
              tooltip: refreshTooltip,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.onSurfaceMuted),
            ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<_SettingsRow> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: AppColors.outlineSubtle,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primarySoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceDim,
                      ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right, color: AppColors.onSurfaceDim),
            ],
          ),
        ),
      ),
    );
  }
}
