import 'package:flutter/material.dart';

import 'api/auth_storage.dart';
import 'api/client.dart';
import 'config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const BootstrapGate(),
    );
  }
}

class BootstrapGate extends StatefulWidget {
  const BootstrapGate({super.key});

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> with WidgetsBindingObserver {
  late final ApiClient api = ApiClient(onUnauthorized: _handleUnauthorized);
  String? error;
  bool loading = true;
  bool needsAuth = false;
  int _bootEpoch = 0;
  bool _reauthing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Paint first frame before any LAN/HTTP work — iOS Local Network permission
    // can otherwise leave users on a blank launch screen while Wi‑Fi is on.
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading && !needsAuth && api.refreshToken != null) {
      api.tryRefresh();
    }
  }

  Future<void> _clearSession() async {
    api.token = null;
    api.refreshToken = null;
    await AuthStorage.clear();
  }

  void _handleUnauthorized() {
    if (_reauthing || loading) return;
    _reauthing = true;
    _clearSession().then((_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        needsAuth = true;
        error = null;
      });
      _reauthing = false;
    });
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

      if (api.refreshToken != null && api.refreshToken!.isNotEmpty) {
        final prev = api.onUnauthorized;
        api.onUnauthorized = null;
        try {
          final refreshed = await api.tryRefresh();
          if (!refreshed && (api.token == null || api.token!.isEmpty)) {
            await _clearSession();
          } else if (api.token != null && api.token!.isNotEmpty) {
            await api.quota();
          }
        } on ApiException catch (e) {
          if (e.unauthorized) {
            await _clearSession();
          } else {
            rethrow;
          }
        } finally {
          api.onUnauthorized = prev;
        }
      }

      if (api.token != null && api.token!.isNotEmpty) {
        if (!mounted || epoch != _bootEpoch) return;
        setState(() {
          loading = false;
          needsAuth = false;
          error = null;
        });
        return;
      }

      if (!mounted || epoch != _bootEpoch) return;
      setState(() {
        loading = false;
        needsAuth = true;
        error = null;
      });
    } catch (e) {
      if (!mounted || epoch != _bootEpoch) return;
      final hint = apiBaseUrlLooksRemote
          ? '线上/内测请用 Cloudflare HTTPS 域名：\n'
              '--dart-define=API_BASE_URL=https://bedtime-api.<你的域名>\n'
              '并使用邀请码注册或手机号登录。'
          : '若卡在白屏或连不上：系统设置 → 隐私与安全性 → 本地网络 → 打开本 App；\n'
              '并确认用 --dart-define=API_BASE_URL=http://<电脑局域网IP>:8000 启动。';
      setState(() {
        error = '$e\n\nAPI: $apiBaseUrl\n\n$hint';
        loading = false;
        needsAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '枕边灯亮起…\n$apiBaseUrl',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
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
                  _boot();
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
          setState(() {
            needsAuth = false;
            error = null;
          });
        },
      );
    }
    return HomeShell(
      api: api,
      onLoggedOut: () {
        if (!mounted) return;
        setState(() {
          needsAuth = true;
          error = null;
          loading = false;
        });
      },
    );
  }
}
