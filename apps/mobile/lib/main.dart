import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'analytics/analytics_tracker.dart';
import 'analytics/umeng_apm.dart';
import 'api/auth_storage.dart';
import 'api/client.dart';
import 'config.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'local/local_store.dart';
import 'local/network_errors.dart';
import 'local/user_scope.dart';
import 'screens/home_shell.dart';
import 'splash/splash_screen.dart';
import 'theme/app_theme.dart';
import 'utils/require_login.dart';

Future<void> main() async {
  // APM binding first so we can load assets, then optionally enable Umeng.
  final widgetsBinding = BedtimeApmWidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await AppConfig.load();
  await LocaleController.instance.load();

  await runAppWithOptionalUmengApm((observer) {
    return BedtimeApp(navigatorObserver: observer);
  });
}

class BedtimeApp extends StatefulWidget {
  const BedtimeApp({super.key, this.navigatorObserver});

  final NavigatorObserver? navigatorObserver;

  @override
  State<BedtimeApp> createState() => _BedtimeAppState();
}

class _BedtimeAppState extends State<BedtimeApp> {
  @override
  void initState() {
    super.initState();
    LocaleController.instance.addListener(_onLocale);
  }

  @override
  void dispose() {
    LocaleController.instance.removeListener(_onLocale);
    super.dispose();
  }

  void _onLocale() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleController.instance.locale;
    final observers = <NavigatorObserver>[
      if (widget.navigatorObserver != null) widget.navigatorObserver!,
    ];
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildBedtimeTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: observers,
      home: const BootstrapGate(),
    );
  }
}

class BootstrapGate extends StatefulWidget {
  const BootstrapGate({super.key});

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ApiClient api = ApiClient(onUnauthorized: _handleUnauthorized);
  String? error;
  bool loading = true;
  bool offlineMode = false;
  LocalStore? localStore;
  int _bootEpoch = 0;
  /// Bumped on session clear so in-flight [_ensureStoreFromMe] cannot repopulate
  /// [localStore] / [UserScope] after logout or 401.
  int _storeEnsureGen = 0;
  bool _reauthing = false;

  bool _splashRemoved = false;
  late final AnimationController _exitController;
  late final Animation<double> _splashOpacity;
  DateTime? _splashStartedAt;

  @override
  void initState() {
    super.initState();
    AnalyticsTracker.instance.bind(api);
    WidgetsBinding.instance.addObserver(this);
    _exitController = AnimationController(
      vsync: this,
      duration: SplashMotion.exitFadeDuration,
    );
    _splashOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: SplashMotion.exitFadeCurve,
      ),
    );
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _splashRemoved = true);
      }
    });
    // Paint first frame before any LAN/HTTP work — iOS Local Network permission
    // can otherwise leave users on a blank launch screen while Wi‑Fi is on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _splashStartedAt = DateTime.now();
      unawaited(_boot());
    });
  }

  @override
  void dispose() {
    AnalyticsTracker.instance.unbind(api);
    WidgetsBinding.instance.removeObserver(this);
    _exitController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !loading &&
        api.refreshToken != null) {
      // Soft renew only — network failures must not clear the session.
      unawaited(() async {
        final outcome = await api.tryRefresh();
        if (outcome == RefreshOutcome.unauthorized && mounted) {
          _handleUnauthorized();
        }
      }());
    }
  }

  Future<void> _clearSession({bool clearLocal = true}) async {
    _storeEnsureGen++;
    AnalyticsTracker.instance.clearQueue();
    if (clearLocal) {
      try {
        await LocalStore.clearActiveUserCache(api);
      } catch (_) {}
    }
    api.token = null;
    api.refreshToken = null;
    await AuthStorage.clear();
    localStore = null;
  }

  void _handleUnauthorized() {
    if (_reauthing || loading) return;
    _reauthing = true;
    _clearSession().then((_) {
      if (!mounted) return;
      // Stay in the app as guest; gated actions will prompt login.
      setState(() {
        loading = false;
        offlineMode = false;
        error = null;
        localStore = null;
      });
      _reauthing = false;
    });
  }

  Future<bool> _requestLogin() async {
    if (!mounted) return false;
    if (apiHasAccessToken(api)) return true;
    final ok = await pushLoginScreen(context, api);
    if (!ok || !mounted) return false;
    offlineMode = false;
    error = null;
    await _ensureStoreFromMe();
    if (!mounted) return false;
    setState(() {});
    return apiHasAccessToken(api);
  }

  Future<LocalStore?> _resolveStore() async {
    final existing = await LocalStore.open(api: api);
    if (existing != null) return existing;
    return null;
  }

  bool _storeEnsureStillValid(int bootEpoch, int ensureGen) {
    if (!mounted || bootEpoch != _bootEpoch || ensureGen != _storeEnsureGen) {
      return false;
    }
    if (_reauthing) return false;
    final hasAccess = api.token != null && api.token!.isNotEmpty;
    final hasRefresh = api.refreshToken != null && api.refreshToken!.isNotEmpty;
    return hasAccess || hasRefresh;
  }

  Future<void> _ensureStoreFromMe() async {
    final bootEpoch = _bootEpoch;
    final ensureGen = _storeEnsureGen;
    try {
      final me = await api.me();
      if (!_storeEnsureStillValid(bootEpoch, ensureGen)) return;
      final id = me['id'];
      final userId = id is int ? id : int.tryParse('$id');
      if (userId == null || userId <= 0) return;
      await UserScope.save(userId);
      if (!_storeEnsureStillValid(bootEpoch, ensureGen)) return;
      final store = await LocalStore.openOrBootstrap(api: api, userId: userId);
      if (!_storeEnsureStillValid(bootEpoch, ensureGen)) return;
      try {
        final q = await api.quota();
        if (!_storeEnsureStillValid(bootEpoch, ensureGen)) return;
        await store.account.saveSnapshot(me: me, quota: q);
      } catch (_) {}
      if (!_storeEnsureStillValid(bootEpoch, ensureGen)) return;
      setState(() => localStore = store);
    } catch (_) {}
  }

  Future<void> _boot({bool forceRelogin = false}) async {
    final epoch = ++_bootEpoch;
    try {
      if (forceRelogin) {
        await _clearSession();
      } else {
        final stored = await AuthStorage.load();
        api.token = stored.access;
        api.refreshToken = stored.refresh;
      }

      var enteredOffline = false;

      if (api.refreshToken != null && api.refreshToken!.isNotEmpty) {
        final prev = api.onUnauthorized;
        api.onUnauthorized = null;
        try {
          final outcome = await api.tryRefresh();
          switch (outcome) {
            case RefreshOutcome.success:
              try {
                await api.quota();
              } catch (e) {
                if (e is ApiException && e.unauthorized) {
                  await _clearSession();
                } else {
                  enteredOffline = true;
                }
              }
            case RefreshOutcome.unauthorized:
            case RefreshOutcome.missing:
              await _clearSession(clearLocal: false);
            case RefreshOutcome.network:
              // Keep tokens; allow home with cache while access may be stale.
              enteredOffline = true;
          }
        } on ApiException catch (e) {
          if (e.unauthorized) {
            await _clearSession();
          } else {
            enteredOffline = true;
          }
        } catch (_) {
          enteredOffline = true;
        } finally {
          api.onUnauthorized = prev;
        }
      }

      if (!mounted || epoch != _bootEpoch) return;

      final hasAccess = api.token != null && api.token!.isNotEmpty;
      final hasRefresh = api.refreshToken != null && api.refreshToken!.isNotEmpty;

      if (hasAccess || (enteredOffline && hasRefresh)) {
        localStore = await _resolveStore();
        if (hasAccess && !enteredOffline) {
          unawaited(_ensureStoreFromMe());
        }
        setState(() {
          loading = false;
          offlineMode = enteredOffline;
          error = null;
        });
        await _finishSplash(skipDwell: false);
        return;
      }

      // No session → guest home (login deferred until gated actions).
      setState(() {
        loading = false;
        offlineMode = false;
        error = null;
        localStore = null;
      });
      await _finishSplash(skipDwell: false);
    } catch (e) {
      if (!mounted || epoch != _bootEpoch) return;
      // Last resort: if we still have credentials + prior user, enter offline.
      final hasCreds = (api.token != null && api.token!.isNotEmpty) ||
          (api.refreshToken != null && api.refreshToken!.isNotEmpty);
      final scope = await UserScope.load();
      if (hasCreds && scope != null) {
        localStore = await _resolveStore();
        setState(() {
          loading = false;
          offlineMode = true;
          error = null;
        });
        await _finishSplash(skipDwell: false);
        return;
      }

      final l10n = lookupAppLocalizations(LocaleController.instance.locale);
      final hint =
          apiBaseUrlLooksRemote ? l10n.bootHintRemote : l10n.bootHintLocal;
      setState(() {
        error = '${friendlyNetworkError(e)}\n\nAPI: $apiBaseUrl\n\n$hint';
        loading = false;
        offlineMode = false;
      });
      await _finishSplash(skipDwell: true);
    }
  }

  Future<void> _finishSplash({required bool skipDwell}) async {
    if (!mounted || _splashRemoved || _exitController.isAnimating) return;
    if (!skipDwell) {
      final started = _splashStartedAt ?? DateTime.now();
      final remaining = SplashMotion.minimumVisible - DateTime.now().difference(started);
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
    if (!mounted || _splashRemoved || _exitController.isAnimating) return;
    _scheduleExitFade();
  }

  /// Let the underlay paint a couple of frames before revealing it.
  void _scheduleExitFade() {
    var framesWaited = 0;
    void waitForPaint(Duration _) {
      if (!mounted || _exitController.isAnimating || _splashRemoved) return;
      framesWaited += 1;
      if (framesWaited >= 2) {
        _exitController.forward();
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback(waitForPaint);
    }

    SchedulerBinding.instance.addPostFrameCallback(waitForPaint);
  }

  Widget _underlay(BuildContext context) {
    if (loading) {
      return const ColoredBox(color: SplashColors.background);
    }
    if (error != null) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.bootCannotConnect,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  unawaited(_boot());
                },
                child: Text(l10n.bootRetry),
              ),
            ],
          ),
        ),
      );
    }
    return HomeShell(
      api: api,
      localStore: localStore,
      offlineMode: offlineMode,
      onLocalStoreReady: (store) {
        if (!mounted) return;
        setState(() => localStore = store);
      },
      onRequestLogin: _requestLogin,
      onLoggedOut: () {
        if (!mounted) return;
        unawaited(_clearSession());
        setState(() {
          offlineMode = false;
          error = null;
          loading = false;
          localStore = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_splashRemoved,
            child: _underlay(context),
          ),
        ),
        if (!_splashRemoved)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _splashOpacity,
                child: const SplashScreen(),
              ),
            ),
          ),
      ],
    );
  }
}
