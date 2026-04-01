import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLORS  (standalone — splash has its own palette for the gradient screen)
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const Color bg      = Color(0xFF08111F);
  static const Color text    = Color(0xFFF5F7FF);
  static const Color muted   = Color(0xB8E6EBFF);
  static const Color accent  = Color(0xFF6B91FF);
  static const Color accent2 = Color(0xFF8D7DFF);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPLASH SCREEN
//  Premium animated entrance — staggered logo, subtitle shimmer, breathing
//  glow, and smooth auto-navigate after 2.5 s.
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  /// Optional callback invoked when the splash animation finishes.
  /// If null, the widget just stays on screen (useful when hosted inside a
  /// navigation flow that handles the transition externally).
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ────────────────────────────────────────────────

  /// Master stagger controller (0 → 1 over 1 200 ms).
  late final AnimationController _staggerCtrl;

  /// Breathing glow behind the logo (infinite loop, 3 s).
  late final AnimationController _glowCtrl;

  /// Shimmer sweep across the subtitle (infinite loop, 2.4 s).
  late final AnimationController _shimmerCtrl;

  // ── Derived animations ───────────────────────────────────────────────────

  // Logo: fade 0→1 + scale 0.82→1.0, interval 0–60 %
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Subtitle: fade 0→1 + slide up 12 px, interval 35–85 %
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;

  // Glow: scale 1.0↔1.12, opacity 0.22↔0.40
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;

  static const _entranceDuration = Duration(milliseconds: 1200);
  static const _glowDuration     = Duration(milliseconds: 3000);
  static const _shimmerDuration  = Duration(milliseconds: 2400);
  static const _autoNavDelay     = Duration(milliseconds: 2800);

  @override
  void initState() {
    super.initState();

    // ── Stagger ──────────────────────────────────────────────────────────
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _subFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _subSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // ── Glow ─────────────────────────────────────────────────────────────
    _glowCtrl = AnimationController(
      vsync: this,
      duration: _glowDuration,
    )..repeat(reverse: true);

    _glowScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _glowOpacity = Tween<double>(begin: 0.22, end: 0.40).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // ── Shimmer ──────────────────────────────────────────────────────────
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: _shimmerDuration,
    )..repeat();

    // ── Start sequence ───────────────────────────────────────────────────
    // Small delay so the very first frame renders the background first,
    // giving the GPU time to composite the gradient.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _staggerCtrl.forward();
    });

    // Auto-navigate after 2.8 s
    Future.delayed(_autoNavDelay, () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accent2,
                AppColors.accent,
                Color(0xFFF5F0FF),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                _buildBrandSection(),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Brand section (logo + subtitle) ────────────────────────────────────
  Widget _buildBrandSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_staggerCtrl, _glowCtrl, _shimmerCtrl]),
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Breathing glow ──
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow orb behind the text
                Transform.scale(
                  scale: _glowScale.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.text.withValues(
                            alpha: _glowOpacity.value * _logoFade.value,
                          ),
                          AppColors.text.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),

                // ── Logo text ──
                Opacity(
                  opacity: _logoFade.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Text(
                      'AHVI',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        shadows: [
                          Shadow(
                            color: AppColors.text.withValues(
                              alpha: 0.35 * _logoFade.value,
                            ),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Subtitle with shimmer ──
            SlideTransition(
              position: _subSlide,
              child: Opacity(
                opacity: _subFade.value,
                child: _buildShimmerSubtitle(),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Shimmer subtitle ───────────────────────────────────────────────────
  Widget _buildShimmerSubtitle() {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        // Shimmer sweep: a narrow highlight bar moves left → right
        final shimmerT = _shimmerCtrl.value;
        final center = -0.5 + shimmerT * 2.0; // sweeps from -0.5 to 1.5
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            AppColors.text,
            Color(0xFFFFFFFF),  // bright highlight
            AppColors.text,
          ],
          stops: [
            math.max(0.0, center - 0.15),
            center.clamp(0.0, 1.0),
            math.min(1.0, center + 0.15),
          ],
        ).createShader(bounds);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your Personal A',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
          const _AiIconInline(),
          Text(
            ' Stylist',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Inline AI icon  (sparkle on the "i")
// ─────────────────────────────────────────────────────────────────────────────
class _AiIconInline extends StatelessWidget {
  const _AiIconInline();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'i',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.text,
              size: 8,
            ),
          ),
        ],
      ),
    );
  }
}