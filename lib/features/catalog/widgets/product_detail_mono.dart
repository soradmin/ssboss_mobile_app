import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/motion/app_motion.dart';

/// Монохромная система для экрана товара (Hero + Sticky Action).
abstract final class ProductDetailMono {
  static const white = Color(0xFFFFFFFF);
  static const ghost = Color(0xFFF9FAFB);
  static const platinum = Color(0xFFE5E7EB);
  static const slate = Color(0xFF71717A);
  static const onyx = Color(0xFF111827);
  /// Брендовый фиолетовый SSBOSS
  static const brand = Color(0xFF8813BA);
  static const heroBg = Color(0xFFF3F4F6);
  static const star = Color(0xFFEAB308);

  /// Strong ease-out (Emil) — not Material's weak ease-in-out.
  static const curve = AppMotion.easeOut;

  static TextStyle tag([Color? color]) => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        color: color ?? slate,
        height: 1.2,
      );

  static TextStyle h1([Color? color]) => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: color ?? onyx,
        height: 1.15,
      );

  static TextStyle price([Color? color]) => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: color ?? onyx,
        height: 1.1,
      );

  static TextStyle body([Color? color]) => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color ?? slate,
        height: 1.45,
      );

  static TextStyle label([Color? color]) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color ?? slate,
      );

  static TextStyle cta() => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: white,
        letterSpacing: -0.2,
      );
}

/// Кнопка с лёгким scale при нажатии.
class HapticScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const HapticScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<HapticScale> createState() => _HapticScaleState();
}

class _HapticScaleState extends State<HapticScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressScale : 1,
        duration: AppMotion.press,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Круглая стеклянная кнопка (нав / избранное).
class GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color iconColor;
  final double size;

  const GlassCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor = ProductDetailMono.onyx,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return HapticScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.80),
              shape: BoxShape.circle,
              border: Border.all(color: ProductDetailMono.platinum),
            ),
            child: Icon(icon, size: size * 0.45, color: iconColor),
          ),
        ),
      ),
    );
  }
}
