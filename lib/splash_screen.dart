import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COLORS  (fixed palette)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const Color bg          = Color(0xFF06091A);
  static const Color bgMid       = Color(0xFF0E1535);
  static const Color bgEnd       = Color(0xFF1A1060);
  static const Color text        = Color(0xFFF0F4FF);
  static const Color muted       = Color(0xFFAAB8E0);
  static const Color accent      = Color(0xFF7B9FFF);
  static const Color accent2     = Color(0xFFB07DFF);
  static const Color shimmerBase = Color(0xCCE8EEFF);
  static const Color shimmerHi   = Color(0xFFFFFFFF);
  static const Color orbInner    = Color(0x557B9FFF);
}

// ─────────────────────────────────────────────────────────────────────────────
//  PARTICLE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _Particle {
  final double x, y, size, speed, phase, drift, opacity;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.phase,
    required this.drift, required this.opacity,
  });
}

List<_Particle> _buildParticles(int count, math.Random rng) =>
    List.generate(count, (_) => _Particle(
      x:       rng.nextDouble(),
      y:       rng.nextDouble(),
      size:    1.5 + rng.nextDouble() * 2.5,
      speed:   0.06 + rng.nextDouble() * 0.10,
      phase:   rng.nextDouble() * math.pi * 2,
      drift:   0.02 + rng.nextDouble() * 0.04,
      opacity: 0.2 + rng.nextDouble() * 0.5,
    ));

// ─────────────────────────────────────────────────────────────────────────────
//  PAINTERS
// ─────────────────────────────────────────────────────────────────────────────
class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t, fadeIn;
  _ParticlesPainter({required this.particles, required this.t, required this.fadeIn});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final rawY     = p.y - p.speed * t;
      final yNorm    = rawY - rawY.floor();
      final xNorm    = p.x + p.drift * math.sin(t * math.pi * 2 + p.phase);
      final edgeFade = yNorm < 0.1 ? yNorm / 0.1 : 1.0;
      canvas.drawCircle(
        Offset(xNorm * size.width, yNorm * size.height),
        p.size,
        Paint()..color = _C.accent.withValues(alpha: p.opacity * fadeIn * edgeFade),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => true;
}

class _GridPainter extends CustomPainter {
  final double opacity;
  const _GridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _C.accent.withValues(alpha: opacity)
      ..strokeWidth = 0.4;
    for (int c = 1; c < 6; c++) {
      final x = size.width * c / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int r = 1; r < 10; r++) {
      final y = size.height * r / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.opacity != opacity;
}

class _RingPainter extends CustomPainter {
  final double pulse, fadeIn;
  const _RingPainter({required this.pulse, required this.fadeIn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final radius = (80.0 + i * 38.0) + pulse * 10.0 * (i + 1);
      final alpha  = (0.20 - i * 0.05) * fadeIn * (1.0 - pulse * 0.3);
      canvas.drawCircle(center, radius,
        Paint()
          ..color = _C.accent.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 - i * 0.2,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPLASH SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _staggerCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _letterCtrl;

  late final Animation<double> _bgReveal;
  late final Animation<double> _gridFade;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _subFade;
  late final Animation<Offset>  _subSlide;
  late final Animation<double> _tagFade;
  late final Animation<Offset>  _tagSlide;
  late final Animation<double> _dotsFade;
  late final Animation<double> _letterSpacing;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;
  late final List<Animation<double>> _letterFades;
  late final List<Animation<double>> _letterOffsets;
  late final List<_Particle> _particles;

  static const _kLetters         = 4;
  static const _entranceDuration = Duration(milliseconds: 1800);
  static const _glowDuration     = Duration(milliseconds: 3200);
  static const _shimmerDuration  = Duration(milliseconds: 2600);
  static const _particleDuration = Duration(milliseconds: 8000);
  static const _ringDuration     = Duration(milliseconds: 2800);
  static const _letterDuration   = Duration(milliseconds: 1000);
  static const _autoNavDelay     = Duration(milliseconds: 5500);

  @override
  void initState() {
    super.initState();

    _particles = _buildParticles(45, math.Random(42));

    _staggerCtrl = AnimationController(vsync: this, duration: _entranceDuration);

    _bgReveal = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic)));
    _gridFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.05, 0.40, curve: Curves.easeOut)));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.10, 0.55, curve: Curves.easeOutCubic)));
    _logoScale = Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.10, 0.55, curve: Curves.easeOutBack)));
    _letterSpacing = Tween<double>(begin: 18.0, end: 8.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.10, 0.65, curve: Curves.easeOutCubic)));
    _subFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic)));
    _subSlide = Tween<Offset>(begin: const Offset(0, 0.40), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic)));
    _tagFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.65, 0.95, curve: Curves.easeOut)));
    _tagSlide = Tween<Offset>(begin: const Offset(0, 0.60), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerCtrl,
            curve: const Interval(0.65, 0.95, curve: Curves.easeOutCubic)));
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _staggerCtrl, curve: const Interval(0.80, 1.00, curve: Curves.easeOut)));

    _glowCtrl = AnimationController(vsync: this, duration: _glowDuration)..repeat(reverse: true);
    _glowScale = Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(begin: 0.18, end: 0.42).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(vsync: this, duration: _shimmerDuration)..repeat();
    _particleCtrl = AnimationController(vsync: this, duration: _particleDuration)..repeat();
    _ringCtrl = AnimationController(vsync: this, duration: _ringDuration)..repeat(reverse: true);
    _letterCtrl = AnimationController(vsync: this, duration: _letterDuration);

    _letterFades = List.generate(_kLetters, (i) {
      final s = i * 0.18, e = math.min(1.0, s + 0.50);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: _letterCtrl, curve: Interval(s, e, curve: Curves.easeOutCubic)));
    });
    _letterOffsets = List.generate(_kLetters, (i) {
      final s = i * 0.18, e = math.min(1.0, s + 0.50);
      return Tween<double>(begin: 22.0, end: 0.0).animate(
          CurvedAnimation(parent: _letterCtrl, curve: Interval(s, e, curve: Curves.easeOutBack)));
    });

    Future.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      _staggerCtrl.forward();
      _letterCtrl.forward();
    });
    Future.delayed(_autoNavDelay, () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    _glowCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    _ringCtrl.dispose();
    _letterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: Listenable.merge([
            _staggerCtrl, _glowCtrl, _shimmerCtrl,
            _particleCtrl, _ringCtrl, _letterCtrl,
          ]),
          builder: (context, _) => Transform.scale(
            scale: _bgReveal.value,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.bg, _C.bgMid, _C.bgEnd],
                  stops: [0.0, 0.50, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(
                      painter: _GridPainter(opacity: 0.06 * _gridFade.value))),
                  Positioned.fill(child: CustomPaint(
                      painter: _ParticlesPainter(
                          particles: _particles, t: _particleCtrl.value,
                          fadeIn: _logoFade.value))),
                  Positioned.fill(child: CustomPaint(
                      painter: _RingPainter(
                          pulse: _ringCtrl.value, fadeIn: _logoFade.value))),
                  SafeArea(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(child: _buildBrandSection()),
                        Positioned(
                          bottom: 48,
                          left: 0,
                          right: 0,
                          child: Center(child: _buildBottomSection()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _glowScale.value,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _C.orbInner.withValues(
                        alpha: _glowOpacity.value * _logoFade.value),
                    const Color(0x00000000),
                  ]),
                ),
              ),
            ),
            Opacity(
              opacity: _logoFade.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: _buildLogoLetters(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 0),
        SlideTransition(
          position: _subSlide,
          child: Opacity(
            opacity: _subFade.value,
            child: _buildShimmerSubtitle(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoLetters() {
    const letters = ['A', 'H', 'V', 'I'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < letters.length; i++) ...[
          Transform.translate(
            offset: Offset(0, _letterOffsets[i].value),
            child: Opacity(
              opacity: _letterFades[i].value,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_C.text, Color(0xCC7B9FFF)],
                ).createShader(bounds),
                child: Text(
                  letters[i],
                  style: TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w900,
                    letterSpacing: _letterSpacing.value,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          if (i == 3)
            Transform.translate(
              offset: Offset(0, _letterOffsets[i].value - 20),
              child: Opacity(
                opacity: _letterFades[i].value,
                child: Transform.scale(
                  scale: 0.7 + _glowCtrl.value * 0.6,
                  child: const Icon(
                      Icons.auto_awesome_rounded, color: _C.accent2, size: 13),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildShimmerSubtitle() {
    final center = -0.4 + _shimmerCtrl.value * 1.8;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [_C.shimmerBase, _C.shimmerHi, _C.shimmerBase],
        stops: [
          math.max(0.0, center - 0.18),
          center.clamp(0.0, 1.0),
          math.min(1.0, center + 0.18),
        ],
      ).createShader(bounds),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your Personal ',
              style: TextStyle(color: _C.text, fontSize: 16,
                  fontWeight: FontWeight.w400, letterSpacing: 0.6)),
          _AiIconInline(),
          Text(' Stylist',
              style: TextStyle(color: _C.text, fontSize: 16,
                  fontWeight: FontWeight.w400, letterSpacing: 0.6)),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return SlideTransition(
      position: _tagSlide,
      child: Opacity(
        opacity: _tagFade.value,
        child: Column(
          children: [
            const Text(
              'Style that understands you',
              style: TextStyle(
                color: _C.muted, fontSize: 12,
                fontWeight: FontWeight.w300, letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 28),
            Opacity(opacity: _dotsFade.value, child: _buildShimmerBar()),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBar() {
    // AI pulse dots — 5 nodes that light up sequentially
    final t = _shimmerCtrl.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final phase = (t * 5 - i) % 1.0;
        final glow  = phase < 0.3 ? (phase / 0.3) : phase < 0.6 ? 1.0 - ((phase - 0.3) / 0.3) : 0.0;
        final size  = 4.0 + glow * 4.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(_C.accent.withValues(alpha: 0.25),
                  _C.accent2, glow),
              boxShadow: glow > 0.1 ? [
                BoxShadow(
                  color: _C.accent.withValues(alpha: glow * 0.7),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Inline AI icon
// ─────────────────────────────────────────────────────────────────────────────
class _AiIconInline extends StatelessWidget {
  const _AiIconInline();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 30,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('AI',
              style: TextStyle(color: _C.text, fontSize: 16,
                  fontWeight: FontWeight.w400, letterSpacing: 0.6)),
          Positioned(
            top: 1, right: 0,
            child: Icon(Icons.auto_awesome_rounded, color: _C.accent2, size: 8),
          ),
        ],
      ),
    );
  }
}