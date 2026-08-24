import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wireframe-стиль для экранов auth + брендовый градиент SSBOSS.
abstract final class AuthWireframe {
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F172A);
  static const slate = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const borderAlt = Color(0xFFE5E7EB);
  static const placeholder = Color(0xFFCBD5E1);
  static const softBg = Color(0xFFF8FAFC);
  static const gridLine = Color(0xFFF1F5F9);
  static const brand = Color(0xFF8813BA);
  static const brandMid = Color(0xFFB02FE0);
  static const brandLight = Color(0xFFE040FB);

  static const curve = Cubic(0.4, 0, 0.2, 1);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, brandMid, brandLight],
  );

  static TextStyle display({double size = 36, Color? color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.8,
        color: color ?? ink,
      );

  static TextStyle body({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: 1.4,
        color: color ?? slate,
      );

  static TextStyle label() => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ink,
      );
}

/// Фон с точечной/линейной сеткой (blueprint).
class AuthGridBackground extends StatelessWidget {
  final Widget child;
  final bool dotted;

  const AuthGridBackground({
    super.key,
    required this.child,
    this.dotted = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: dotted ? _DotGridPainter() : _LineGridPainter(),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.fill;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 40.0;
    final paint = Paint()
      ..color = AuthWireframe.gridLine
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthStepIndicator extends StatelessWidget {
  final int step;
  final int total;
  final String? label;

  const AuthStepIndicator({
    super.key,
    required this.step,
    this.total = 3,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AuthWireframe.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuthWireframe.borderAlt),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 1; i <= total; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= step ? AuthWireframe.brand : AuthWireframe.borderAlt,
              ),
            ),
          ],
          const SizedBox(width: 10),
          Text(
            label ?? 'Step $step of $total',
            style: AuthWireframe.body(
              size: 12,
              weight: FontWeight.w500,
              color: AuthWireframe.slate,
            ),
          ),
        ],
      ),
    );
  }
}

/// Поле ввода 56px с focus-glow в брендовом цвете.
class AuthField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final double radius;
  final double focusGlow;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
    this.radius = 12,
    this.focusGlow = 2,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late final FocusNode _focusNode;
  bool _focused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final next = _focusNode.hasFocus;
    if (next != _focused) setState(() => _focused = next);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _errorText != null && _errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AuthWireframe.label()),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: 56,
          decoration: BoxDecoration(
            color: AuthWireframe.white,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFDC2626)
                  : _focused
                      ? AuthWireframe.brand
                      : AuthWireframe.border,
              width: (_focused || hasError) ? 1.5 : 1,
            ),
            boxShadow: _focused && !hasError
                ? [
                    BoxShadow(
                      color: AuthWireframe.brand.withValues(alpha: 0.12),
                      blurRadius: widget.focusGlow * 2,
                      spreadRadius: widget.focusGlow,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            style: AuthWireframe.body(size: 16, color: AuthWireframe.ink),
            validator: (value) {
              final error = widget.validator?.call(value);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_errorText != error) setState(() => _errorText = error);
              });
              return error;
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: AuthWireframe.body(
                size: 16,
                color: AuthWireframe.placeholder,
              ),
              prefixIcon: Icon(
                widget.icon,
                size: 20,
                color: hasError
                    ? const Color(0xFFDC2626)
                    : _focused
                        ? AuthWireframe.brand
                        : AuthWireframe.slate,
              ),
              suffixIcon: widget.onToggleObscure == null
                  ? null
                  : IconButton(
                      onPressed: widget.onToggleObscure,
                      icon: Icon(
                        widget.obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AuthWireframe.slate,
                      ),
                    ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            _errorText!,
            style: AuthWireframe.body(
              size: 12,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthGradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;
  final double radius;

  const AuthGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.showArrow = false,
    this.radius = 12,
  });

  @override
  State<AuthGradientButton> createState() => _AuthGradientButtonState();
}

class _AuthGradientButtonState extends State<AuthGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        curve: AuthWireframe.curve,
        child: Container(
          height: 56,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: enabled ? AuthWireframe.brandGradient : null,
            color: enabled ? null : AuthWireframe.border,
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AuthWireframe.brand.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: AuthWireframe.body(
                        size: 18,
                        weight: FontWeight.w500,
                        color: AuthWireframe.white,
                      ),
                    ),
                    if (widget.showArrow) ...[
                      const SizedBox(width: 8),
                      AnimatedSlide(
                        offset: _pressed ? const Offset(0.25, 0) : Offset.zero,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class AuthBlurredHint extends StatelessWidget {
  final String text;

  const AuthBlurredHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.4,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthWireframe.borderAlt),
              color: AuthWireframe.softBg,
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AuthWireframe.slate, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 12,
                    color: AuthWireframe.slate,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: AuthWireframe.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AuthWireframe.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wireframe logo box с пунктирной рамкой (экран входа).
class AuthLogoBox extends StatelessWidget {
  final Widget child;

  const AuthLogoBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: AuthWireframe.placeholder,
        radius: 16,
        strokeWidth: 2,
      ),
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AuthWireframe.softBg,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      const dash = 5.0;
      const gap = 4.0;
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}

class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AuthWireframe.body(
                size: 13,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
