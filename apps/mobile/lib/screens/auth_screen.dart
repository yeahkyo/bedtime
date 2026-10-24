import 'package:flutter/gestures.dart';
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
  late final TapGestureRecognizer _toggleModeTap;
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;
  bool _registerMode = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _toggleModeTap = TapGestureRecognizer()..onTap = _toggleMode;
    _termsTap = TapGestureRecognizer()..onTap = () => _comingSoon('用户协议');
    _privacyTap = TapGestureRecognizer()..onTap = () => _comingSoon('隐私政策');
  }

  @override
  void dispose() {
    _toggleModeTap.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _invite.dispose();
    _name.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _comingSoon(String feature) {
    _toast('$feature暂未开放，敬请期待');
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (_registerMode) {
      if (_invite.text.trim().isEmpty) {
        setState(() => _error = '请填写邀请码');
        return;
      }
      if (_phone.text.trim().isEmpty) {
        setState(() => _error = '请填写手机号');
        return;
      }
      if (password.length < 8) {
        setState(() => _error = '密码至少 8 位');
        return;
      }
      if (password != _passwordConfirm.text) {
        setState(() => _error = '两次输入的密码不一致');
        return;
      }
    } else {
      if (_phone.text.trim().isEmpty) {
        setState(() => _error = '请填写手机号');
        return;
      }
      if (password.isEmpty) {
        setState(() => _error = '请填写密码');
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

  void _toggleMode() {
    if (_busy) return;
    setState(() {
      _registerMode = !_registerMode;
      _error = null;
      _passwordConfirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthAtmosphere()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
                    children: [
                      _buildHeader(tt),
                      const SizedBox(height: 32),
                      if (_registerMode) ...[
                        _authField(
                          controller: _invite,
                          hint: '邀请码',
                          textCapitalization: TextCapitalization.characters,
                          suffix: const Icon(
                            Icons.vpn_key_outlined,
                            size: 20,
                            color: AppColors.onSurfaceDim,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _authField(
                          controller: _name,
                          hint: '昵称（可选）',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _authField(
                        controller: _phone,
                        hint: '手机号',
                        keyboardType: TextInputType.phone,
                        prefix: const Icon(
                          Icons.phone_iphone,
                          size: 20,
                          color: AppColors.onSurfaceDim,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      _authField(
                        controller: _password,
                        hint: '密码',
                        obscure: _obscurePassword,
                        prefix: const Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: AppColors.onSurfaceDim,
                        ),
                        suffix: IconButton(
                          tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.onSurfaceMuted,
                            size: 20,
                          ),
                        ),
                        textInputAction: _registerMode
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: _registerMode ? null : (_) => _submit(),
                      ),
                      if (_registerMode) ...[
                        const SizedBox(height: 12),
                        _authField(
                          controller: _passwordConfirm,
                          hint: '确认密码',
                          obscure: _obscureConfirm,
                          prefix: const Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: AppColors.onSurfaceDim,
                          ),
                          suffix: IconButton(
                            tooltip: _obscureConfirm ? '显示密码' : '隐藏密码',
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.onSurfaceMuted,
                              size: 20,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                      if (!_registerMode) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _comingSoon('验证码登录'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.onSurfaceMuted,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('验证码登录'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _comingSoon('找回密码'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.onSurfaceMuted,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('忘记密码？'),
                            ),
                          ],
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFB4AB)),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _AuthPrimaryButton(
                        label: _registerMode ? '注册并登录' : '登录',
                        busy: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: tt.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceMuted,
                            ),
                            children: [
                              TextSpan(
                                text: _registerMode ? '已有账号？ ' : '有邀请码？ ',
                              ),
                              TextSpan(
                                text: _registerMode ? '去登录' : '去注册',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                                recognizer: _toggleModeTap,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.nightlight_round,
                            size: 14,
                            color: AppColors.onSurfaceDim,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '夜间低蓝光护眼设计 · 愿你今晚有好梦',
                            style: tt.labelSmall?.copyWith(
                              color: AppColors.onSurfaceDim,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          style: tt.labelSmall?.copyWith(
                            color: AppColors.onSurfaceDim,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: _registerMode
                                  ? '注册即代表同意 '
                                  : '登录即代表您已同意 ',
                            ),
                            TextSpan(
                              text: '用户协议',
                              style: const TextStyle(
                                color: AppColors.onSurfaceMuted,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: _termsTap,
                            ),
                            const TextSpan(text: ' 与 '),
                            TextSpan(
                              text: _registerMode ? '隐私保护政策' : '隐私政策',
                              style: const TextStyle(
                                color: AppColors.onSurfaceMuted,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: _privacyTap,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '呼呼',
              style: tt.headlineMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.65),
                ),
              ),
              child: const Text(
                '枕边故事',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _registerMode ? '使用邀请码创建账号' : '登录后继续枕边故事',
          style: tt.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction? textInputAction,
    bool obscure = false,
    Widget? prefix,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: prefix,
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.inputWell,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.outlineSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.outlineSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _AuthPrimaryButton extends StatelessWidget {
  const _AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFE8A87C), Color(0xFFF4B251)],
              ),
        color: onPressed == null ? AppColors.surfaceHighest : null,
        boxShadow: onPressed == null
            ? null
            : const [
                BoxShadow(
                  color: AppColors.lanternGlow,
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                else ...[
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppColors.onPrimary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft night dots + amber glow behind the form.
class _AuthAtmosphere extends StatelessWidget {
  const _AuthAtmosphere();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AuthAtmospherePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _AuthAtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.14),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.42),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final dot = Paint()..color = AppColors.onSurface.withValues(alpha: 0.045);
    const step = 22.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
