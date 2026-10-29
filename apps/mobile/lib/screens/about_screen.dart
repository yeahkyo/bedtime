import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/legal_urls.dart';
import '../l10n/app_localizations.dart';
import '../splash/splash_theme.dart';
import '../theme/app_theme.dart';
import '../utils/legal_launcher.dart';

const _websiteLabel = 'www.lullvale.com';

/// About — Bandage-style structure (brand → info → legal), Huhu Warm Dial UI.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '—';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      // Include build so TestFlight / QA can match builds (e.g. 1.0.0+4).
      final build = info.buildNumber.trim();
      setState(() {
        _version = build.isEmpty ? info.version : '${info.version}+$build';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        backgroundColor: AppColors.background,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _AboutBrandLogo(),
                  const SizedBox(height: 18),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: tt.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.aboutTagline,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  _AboutInfoCard(
                    children: [
                      _AboutInfoRow(
                        label: l10n.aboutVersionLabel,
                        value: _version,
                      ),
                      _AboutInfoRow(
                        label: l10n.aboutDeveloperLabel,
                        value: l10n.aboutDeveloperName,
                      ),
                      _AboutInfoRow(
                        label: l10n.aboutSupportLabel,
                        value: LegalConfig.supportEmail,
                        onTap: () => _openSupport(context),
                      ),
                      _AboutInfoRow(
                        label: l10n.aboutWebsiteLabel,
                        value: _websiteLabel,
                        onTap: () => _openWebsite(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _AboutLegalFooter(
                    termsLabel: l10n.aboutTermsLink,
                    privacyLabel: l10n.aboutPrivacyLink,
                    onTerms: () =>
                        openLegalDocument(context, LegalDocument.terms),
                    onPrivacy: () =>
                        openLegalDocument(context, LegalDocument.privacy),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.aboutCopyright(DateTime.now().year),
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.onSurfaceDim,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://www.lullvale.com'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).legalOpenFailed)),
      );
    }
  }

  Future<void> _openSupport(BuildContext context) async {
    final opened = await openSupportEmail(subject: 'Huhu · Pillow Tales');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).legalOpenFailed)),
      );
    }
  }
}

/// Framed app icon + splash-style amber radial glow (static “lit” charge).
class _AboutBrandLogo extends StatefulWidget {
  const _AboutBrandLogo();

  @override
  State<_AboutBrandLogo> createState() => _AboutBrandLogoState();
}

class _AboutBrandLogoState extends State<_AboutBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowBreatheScale;
  late final Animation<double> _glowBreatheOpacity;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: SplashMotion.glowBreatheDuration,
    )..repeat(reverse: true);
    _glowBreatheScale = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowBreatheOpacity = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final framed = SplashLayout.framedLogoSize;
    final canvas = framed + SplashColors.glowPad * 2;
    const charge = 1.0;
    const frameTop = 0.04 + 0.44 * charge;
    const frameBottom = frameTop * 0.5;

    return SizedBox(
      width: canvas,
      height: canvas,
      child: AnimatedBuilder(
        animation: Listenable.merge([_glowBreatheScale, _glowBreatheOpacity]),
        builder: (context, _) {
          final breathe = _glowBreatheOpacity.value.clamp(0.0, 1.0);
          final glowOp = (charge * breathe).clamp(0.0, 1.0);
          final scale = 1 + (_glowBreatheScale.value - 1) * charge;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: glowOp,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      width: framed + 48,
                      height: framed + 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            SplashColors.amberGlow.withValues(alpha: 0.22),
                            SplashColors.amberGlow.withValues(alpha: 0.11),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: framed,
                height: framed,
                padding: const EdgeInsets.all(SplashColors.logoFramePad),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(SplashColors.logoRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      SplashColors.amberGlow.withValues(alpha: frameTop),
                      SplashColors.amberSoft.withValues(alpha: frameBottom),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: SplashColors.amberGlow.withValues(alpha: 0.2),
                      blurRadius: 22,
                    ),
                    BoxShadow(
                      color: SplashColors.amberSoft.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(SplashColors.logoInnerRadius),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AboutLegalFooter extends StatelessWidget {
  const _AboutLegalFooter({
    required this.termsLabel,
    required this.privacyLabel,
    required this.onTerms,
    required this.onPrivacy,
  });

  final String termsLabel;
  final String privacyLabel;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.onSurfaceMuted,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTerms,
          child: Text(termsLabel, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('·', style: style),
        ),
        GestureDetector(
          onTap: onPrivacy,
          child: Text(privacyLabel, style: style),
        ),
      ],
    );
  }
}

class _AboutInfoCard extends StatelessWidget {
  const _AboutInfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
                indent: 16,
                endIndent: 16,
                color: AppColors.outlineSubtle,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.label,
    this.value,
    this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: tt.titleMedium),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: tt.bodySmall?.copyWith(
                        color: onTap != null
                            ? AppColors.primarySoft
                            : AppColors.onSurfaceDim,
                        fontWeight:
                            onTap != null ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: content),
      );
    }
    return content;
  }
}
