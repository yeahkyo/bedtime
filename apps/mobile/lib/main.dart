import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/client.dart';
import 'config.dart';
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
      title: 'Lullvale Bedtime',
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

class _BootstrapGateState extends State<BootstrapGate> {
  late final ApiClient api = ApiClient(onUnauthorized: _handleUnauthorized);
  String? error;
  bool loading = true;
  int _bootEpoch = 0;
  bool _reauthing = false;

  @override
  void initState() {
    super.initState();
    // Paint first frame before any LAN/HTTP work — iOS Local Network permission
    // can otherwise leave users on a blank launch screen while Wi‑Fi is on.
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    api.token = null;
  }

  void _handleUnauthorized() {
    if (_reauthing || loading) return;
    _reauthing = true;
    _clearToken().then((_) {
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });
      _boot(forceRelogin: true).whenComplete(() => _reauthing = false);
    });
  }

  Future<void> _boot({bool forceRelogin = false}) async {
    final epoch = ++_bootEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = forceRelogin ? null : prefs.getString('token');
      if (token != null) {
        api.token = token;
        final prev = api.onUnauthorized;
        api.onUnauthorized = null;
        try {
          await api.quota();
        } on ApiException catch (e) {
          if (e.unauthorized) {
            await _clearToken();
            token = null;
          } else {
            rethrow;
          }
        } finally {
          api.onUnauthorized = prev;
        }
        if (token != null) {
          if (!mounted || epoch != _bootEpoch) return;
          setState(() {
            loading = false;
            error = null;
          });
          return;
        }
      }

      final login = await api.devLogin();
      token = login['access_token'] as String;
      await prefs.setString('token', token);
      api.token = token;
      if (!mounted || epoch != _bootEpoch) return;
      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || epoch != _bootEpoch) return;
      final hint = apiBaseUrlLooksRemote
          ? '线上/内测请用 Cloudflare HTTPS 域名：\n'
              '--dart-define=API_BASE_URL=https://bedtime-api.<你的域名>\n'
              '并确认服务端开启了 dev-login（内测）或已接入 Apple 登录。'
          : '若卡在白屏或连不上：系统设置 → 隐私与安全性 → 本地网络 → 打开本 App；\n'
              '并确认用 --dart-define=API_BASE_URL=http://<电脑局域网IP>:8000 启动。';
      setState(() {
        error = '$e\n\nAPI: $apiBaseUrl\n\n$hint';
        loading = false;
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
                  _boot(forceRelogin: true);
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    return HomeShell(api: api);
  }
}
