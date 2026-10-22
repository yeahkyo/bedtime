import 'package:flutter/material.dart';

import '../api/auth_storage.dart';
import '../api/client.dart';
import '../theme/app_theme.dart';

/// Login / register (invite + phone + password).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, this.onSuccess});

  final ApiClient api;
  final VoidCallback? onSuccess;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _invite = TextEditingController();
  final _name = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _invite.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (_registerMode) {
      if (password.length < 8) {
        setState(() => _error = '密码至少 8 位');
        return;
      }
      if (password != _passwordConfirm.text) {
        setState(() => _error = '两次输入的密码不一致');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> tokens;
      if (_registerMode) {
        tokens = await widget.api.register(
          inviteCode: _invite.text.trim(),
          phone: _phone.text.trim(),
          password: password,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
      } else {
        tokens = await widget.api.login(
          phone: _phone.text.trim(),
          password: password,
        );
      }
      final access = tokens['access_token'] as String?;
      final refresh = tokens['refresh_token'] as String?;
      if (access == null || refresh == null) {
        throw ApiException('登录响应无效');
      }
      await AuthStorage.save(access: access, refresh: refresh);
      widget.api.token = access;
      widget.api.refreshToken = refresh;
      if (!mounted) return;
      widget.onSuccess?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          tooltip: obscure ? '显示密码' : '隐藏密码',
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text('呼呼', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              _registerMode ? '使用邀请码创建账号' : '登录后继续枕边故事',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
            const SizedBox(height: 28),
            if (_registerMode) ...[
              TextField(
                controller: _invite,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '邀请码',
                  hintText: 'LULL-XXXXXXXX',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '昵称（可选）',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号',
                hintText: '11 位手机号',
              ),
            ),
            const SizedBox(height: 12),
            _passwordField(
              controller: _password,
              label: '密码',
              hint: '至少 8 位',
              obscure: _obscurePassword,
              onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
              textInputAction:
                  _registerMode ? TextInputAction.next : TextInputAction.done,
            ),
            if (_registerMode) ...[
              const SizedBox(height: 12),
              _passwordField(
                controller: _passwordConfirm,
                label: '确认密码',
                hint: '再输入一次',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                textInputAction: TextInputAction.done,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_registerMode ? '注册并登录' : '登录'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _registerMode = !_registerMode;
                        _error = null;
                        _passwordConfirm.clear();
                      }),
              child: Text(_registerMode ? '已有账号？去登录' : '有邀请码？注册'),
            ),
          ],
        ),
      ),
    );
  }
}
