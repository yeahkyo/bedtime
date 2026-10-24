import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'api/auth_storage.dart';
import 'api/client.dart';
import 'config.dart';
import 'local/local_store.dart';
import 'local/network_errors.dart';
import 'local/user_scope.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const BedtimeApp());
}

class BedtimeApp extends StatelessWidget {
  const BedtimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '呼呼 - 枕边故事',
      debugShowCheckedModeBanner: false,
      theme: buildBedtimeTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  bool needsAuth = false;
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
    WidgetsBinding.instance.removeObserver(this);
    _exitController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !loading &&
        !needsAuth &&
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
      setState(() {
        loading = false;
        needsAuth = true;
        offlineMode = false;
        error = null;
        localStore = null;
      });
      _reauthing = false;
    });
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
    if (needsAuth || _reauthing) return false;
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
          needsAuth = false;
          offlineMode = enteredOffline;
          error = null;
        });
        await _finishSplash(skipDwell: false);
        return;
      }

      setState(() {
        loading = false;
        needsAuth = true;
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
          needsAuth = false;
          offlineMode = true;
          error = null;
        });
        await _finishSplash(skipDwell: false);
        return;
      }

      final hint = apiBaseUrlLooksRemote
          ? '线上/内测请用 Cloudflare HTTPS 域名：\n'
              '--dart-define=API_BASE_URL=https://bedtime-api.<你的域名>\n'
              '并使用邀请码注册或手机号登录。'
          : '若卡在白屏或连不上：系统设置 → 隐私与安全性 → 本地网络 → 打开本 App；\n'
              '并确认用 --dart-define=API_BASE_URL=http://<电脑局域网IP>:8000 启动。';
      setState(() {
        error = '${friendlyNetworkError(e)}\n\nAPI: $apiBaseUrl\n\n$hint';
        loading = false;
        needsAuth = false;
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
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('无法连接', style: Theme.of(context).textTheme.headlineMedium),
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
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (needsAuth) {
      return AuthScreen(
        api: api,
        onSuccess: () {
          if (!mounted) return;
          unawaited(_ensureStoreFromMe());
          setState(() {
            needsAuth = false;
            offlineMode = false;
            error = null;
          });
        },
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
      onLoggedOut: () {
        if (!mounted) return;
        unawaited(_clearSession());
        setState(() {
          needsAuth = true;
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
