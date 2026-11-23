import 'dart:math' as math;
import 'package:flutter/material.dart';

// 1. Focus Mode Animated Zen Lock (White Glowing Breathing Circle)
class AnimatedZenLock extends StatefulWidget {
  final double size;
  const AnimatedZenLock({super.key, this.size = 140});

  @override
  State<AnimatedZenLock> createState() => _AnimatedZenLockState();
}

class _AnimatedZenLockState extends State<AnimatedZenLock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathScale;
  late final Animation<double> _glowIntensity;

  static const Color _accent = Colors.white;
  static const Color _cardBg = Color(0xFF212328);

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Main circle breathes: scale 0.96 → 1.05
    _breathScale = Tween<double>(begin: 0.96, end: 1.05)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_breathController);

    // Glow intensity pulses with breath
    _glowIntensity = Tween<double>(begin: 0.35, end: 0.80)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_breathController);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, _) {
        final scale = _breathScale.value;
        final glow = _glowIntensity.value;
        final circleSize = widget.size;

        return SizedBox(
          width: circleSize * 1.2,
          height: circleSize * 1.2,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cardBg,
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.85),
                    width: 2.5,
                  ),
                  boxShadow: [
                    // Inner subtle glow
                    BoxShadow(
                      color: _accent.withValues(alpha: glow * 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                    // Outer glow
                    BoxShadow(
                      color: _accent.withValues(alpha: glow * 0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_rounded,
                    color: _accent,
                    size: circleSize * 0.36,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// 2. Login Screen Animated Chat Bubble (Clean White Minimalist Theme)
class AnimatedLoginChatGraphic extends StatefulWidget {
  final double size;
  const AnimatedLoginChatGraphic({super.key, this.size = 110});

  @override
  State<AnimatedLoginChatGraphic> createState() => _AnimatedLoginChatGraphicState();
}

class _AnimatedLoginChatGraphicState extends State<AnimatedLoginChatGraphic>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _typingController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _typingController]),
      builder: (context, _) {
        final float = _floatController.value;
        final typing = _typingController.value;

        return SizedBox(
          width: widget.size * 1.3,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Main Floating Chat Bubble with White Border and White Accent
              Transform.translate(
                offset: Offset(0, -6 * float),
                child: Container(
                  width: widget.size,
                  height: widget.size * 0.78,
                  decoration: BoxDecoration(
                    color: const Color(0xFF212328),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.08 + (float * 0.08)),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTypingDot(0, typing),
                      const SizedBox(width: 6),
                      _buildTypingDot(1, typing),
                      const SizedBox(width: 6),
                      _buildTypingDot(2, typing),
                    ],
                  ),
                ),
              ),

              // Small satellite bubble (top right) in clean white monochrome
              Positioned(
                top: 4 - (8 * (1.0 - float)),
                right: 8,
                child: Container(
                  width: widget.size * 0.28,
                  height: widget.size * 0.28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF25292E),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingDot(int index, double progress) {
    // Offset wave calculation for staggered jumping dots
    final phase = (progress * 3.0 - index).clamp(0.0, 1.0);
    final jump = math.sin(phase * math.pi);

    return Transform.translate(
      offset: Offset(0, -5 * jump),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.45 + (0.55 * jump)),
        ),
      ),
    );
  }
}

