import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'splash_theme.dart';

export 'splash_theme.dart' show SplashColors, SplashMotion;

/// Branded launch screen — layout from `design/launch` adapted to phone.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _igniteController;
  late final AnimationController _glowController;

  late final Animation<double> _litOpacity;
  late final Animation<double> _glowCharge;
  late final Animation<double> _footerOpacity;
  late final Animation<double> _glowBreatheScale;
  late final Animation<double> _glowBreatheOpacity;

  @override
  void initState() {
    super.initState();

    _igniteController = AnimationController(
      vsync: this,
      duration: SplashMotion.igniteDuration,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: SplashMotion.glowBreatheDuration,
    );

    final igniteCurve = CurvedAnimation(
      parent: _igniteController,
      curve: SplashMotion.igniteCurve,
    );
    // Logo, glow, and footer share one easeOut timeline.
    _litOpacity = igniteCurve;
    _glowCharge = igniteCurve;
    _footerOpacity = igniteCurve;

    _glowBreatheScale = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowBreatheOpacity = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _igniteController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _glowController.repeat(reverse: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runIntro());
    });
  }

  Future<void> _runIntro() async {
    await Future<void>.delayed(SplashMotion.logoOnlyBeat);
    if (!mounted) return;
    unawaited(_igniteController.forward());
  }

  @override
  void dispose() {
    _igniteController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoTop = SplashLayout.logoTopForHeight(size.height);
    final framed = SplashLayout.framedLogoSize;

    return ColoredBox(
      color: SplashColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _glowCharge,
            builder: (context, _) {
              return Opacity(
                opacity: 0.35 + 0.65 * _glowCharge.value,
                child: const _AmbientBackdrop(),
              );
            },
          ),
          const _PaperTexture(),
          // Logo anchored like native splash (full-screen Y fraction — not SafeArea).
          Positioned(
            top: logoTop - SplashColors.glowPad,
            left: 0,
            right: 0,
            height: framed + SplashColors.glowPad * 2,
            child: Center(
              child: _LogoWithGlow(
                litOpacity: _litOpacity,
                glowCharge: _glowCharge,
                glowBreatheScale: _glowBreatheScale,
                glowBreatheOpacity: _glowBreatheOpacity,
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedBuilder(
                  animation: _footerOpacity,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _footerOpacity.value * 0.9,
                      child: child,
                    );
                  },
                  child: const _SplashFooter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.95,
          colors: [
            Color(0x29F5C76C),
            Color(0x0DDEB366),
            Colors.transparent,
          ],
          stops: [0.0, 0.35, 0.7],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, 1.1),
            radius: 0.85,
            colors: [
              Color(0x991B233A),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft parchment grain — `paper-texture` from the design HTML.
class _PaperTexture extends StatelessWidget {
  const _PaperTexture();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGrainPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DotGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x0AF5F0E6);
    const step = 16.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LogoWithGlow extends StatelessWidget {
  const _LogoWithGlow({
    required this.litOpacity,
    required this.glowCharge,
    required this.glowBreatheScale,
    required this.glowBreatheOpacity,
  });

  final Animation<double> litOpacity;
  final Animation<double> glowCharge;
  final Animation<double> glowBreatheScale;
  final Animation<double> glowBreatheOpacity;

  @override
  Widget build(BuildContext context) {
    final framed = SplashLayout.framedLogoSize;
    final canvas = framed + SplashColors.glowPad * 2;
    return SizedBox(
      width: canvas,
      height: canvas,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          litOpacity,
          glowCharge,
          glowBreatheScale,
          glowBreatheOpacity,
        ]),
        builder: (context, _) {
          final charge = glowCharge.value.clamp(0.0, 1.0);
          final breathe = glowBreatheOpacity.value.clamp(0.0, 1.0);
          final glowOp = (charge * breathe).clamp(0.0, 1.0);
          final scale = 1 + (glowBreatheScale.value - 1) * charge;
          final lit = litOpacity.value.clamp(0.0, 1.0);
          final frameTop = 0.04 + 0.44 * charge;
          final frameBottom = frameTop * 0.5;

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
                          stops: const [0.0, 1.0],
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
                  borderRadius: BorderRadius.circular(SplashColors.logoRadius),
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
                      color: SplashColors.amberGlow.withValues(alpha: 0.2 * charge),
                      blurRadius: 22,
                    ),
                    BoxShadow(
                      color: SplashColors.amberSoft.withValues(alpha: 0.12 * charge),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SplashColors.logoInnerRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: SplashColors.night950),
                      Image.asset(
                        SplashColors.logoDarkAsset,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                      Opacity(
                        opacity: lit,
                        child: Image.asset(
                          SplashColors.logoAsset,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      if (lit < 0.98)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: IgnorePointer(
                            child: Container(
                              height: SplashColors.logoSize * 0.1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    SplashColors.night950.withValues(
                                      alpha: 0.55 * (1 - lit),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: SplashColors.amberSoft.withValues(
                              alpha: 0.1 + 0.18 * charge,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(
                            SplashColors.logoInnerRadius,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              SplashColors.amberGlow.withValues(
                                alpha: 0.06 * charge,
                              ),
                              Colors.transparent,
                              SplashColors.amberGlow.withValues(
                                alpha: 0.1 * charge,
                              ),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ],
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

class _SplashFooter extends StatelessWidget {
  const _SplashFooter();

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode.startsWith('zh');
    final studio = isZh ? SplashColors.studioNameZh : SplashColors.studioNameEn;

    return Column(
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: SplashColors.amberSoft.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 12),
        Text(
          studio,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: isZh ? 1.2 : 1.6,
            color: SplashColors.parchmentDim.withValues(alpha: 0.75),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
