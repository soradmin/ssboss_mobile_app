import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soft pastel auth UI с брендовыми цветами SSBOSS.
abstract final class AuthSoft {
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1523);
  static const muted = Color(0xFF8B8395);
  static const fieldBorder = Color(0xFFE8E0EF);
  static const fieldFill = Color(0xFFFAF7FC);
  static const brand = Color(0xFF8813BA);
  static const brandMid = Color(0xFFB02FE0);
  static const brandLight = Color(0xFFE040FB);
  static const brandSoftTop = Color(0xFFC56BEC);
  static const brandSoftMid = Color(0xFFD28AF5);
  static const brandSoftBottom = Color(0xFFF0D4FA);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF9B2BC8),
      brandMid,
      Color(0xFFE8A0F8),
    ],
  );

  static const ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brand, brandMid, brandLight],
  );

  /// Душанбе, UTC+05:00. 05–11 утро, 12–16 день, 17–22 вечер, 23–04 ночь.
  static String greetingTrKey() {
    final hour = DateTime.now().toUtc().add(const Duration(hours: 5)).hour;
    if (hour >= 5 && hour < 12) return 'auth.greeting_morning';
    if (hour >= 12 && hour < 17) return 'auth.greeting_afternoon';
    if (hour >= 17 && hour < 23) return 'auth.greeting_evening';
    return 'auth.greeting_night';
  }

  static TextStyle title({double size = 28}) => GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.6,
        color: ink,
      );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: 1.45,
        color: color ?? muted,
      );
}

/// Общий каркас: градиентный хедер с волнами + белая карточка снизу.
class AuthSoftScaffold extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;
  final String backLabel;
  final double headerFlex;

  const AuthSoftScaffold({
    super.key,
    required this.child,
    this.onBack,
    this.backLabel = 'Back',
    this.headerFlex = 0.32,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final size = MediaQuery.sizeOf(context);
    final headerH = size.height * headerFlex;

    return Scaffold(
      backgroundColor: AuthSoft.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerH + 40,
            child: Container(
              decoration: const BoxDecoration(gradient: AuthSoft.headerGradient),
            ),
          ),
          Positioned(
            top: top + 4,
            left: 8,
            child: TextButton.icon(
              onPressed: onBack,
              style: TextButton.styleFrom(
                foregroundColor: AuthSoft.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
              label: Text(
                backLabel,
                style: AuthSoft.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: AuthSoft.white,
                ),
              ),
            ),
          ),
          Positioned(
            top: headerH - 28,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AuthSoft.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AuthSoft.brand.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Мягкое поле ввода (placeholder-стиль как на макете).
class AuthSoftField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? prefix;

  const AuthSoftField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.inputFormatters,
    this.maxLength,
    this.prefix,
  });

  @override
  State<AuthSoftField> createState() => _AuthSoftFieldState();
}

class _AuthSoftFieldState extends State<AuthSoftField> {
  late final FocusNode _focus;
  bool _focused = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(() {
      final next = _focus.hasFocus;
      if (next != _focused) setState(() => _focused = next);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null && _error!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          clipBehavior: Clip.none,
          decoration: BoxDecoration(
            color: AuthSoft.fieldFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFDC2626)
                  : AuthSoft.fieldBorder,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            cursorColor: AuthSoft.brand,
            onChanged: (_) {
              final err = widget.validator?.call(widget.controller.text);
              if (err != _error) setState(() => _error = err);
            },
            style: AuthSoft.body(
              size: 15,
              weight: FontWeight.w500,
              color: AuthSoft.ink,
            ),
            validator: (v) {
              final err = widget.validator?.call(v);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_error != err) setState(() => _error = err);
              });
              return err;
            },
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              counterText: '',
              hintText: widget.hint,
              hintStyle: AuthSoft.body(size: 15, color: AuthSoft.muted),
              prefixIcon: widget.prefix != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      child: widget.prefix,
                    )
                  : (widget.prefixIcon == null
                      ? null
                      : Icon(
                          widget.prefixIcon,
                          size: 20,
                          color: _focused ? AuthSoft.brand : AuthSoft.muted,
                        )),
              prefixIconConstraints: widget.prefix != null
                  ? const BoxConstraints(minWidth: 0, minHeight: 0)
                  : null,
              suffixIcon: widget.onToggleObscure == null
                  ? null
                  : IconButton(
                      onPressed: widget.onToggleObscure,
                      icon: Icon(
                        widget.obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AuthSoft.muted,
                      ),
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
            ),
          ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: AuthSoft.body(size: 12, color: const Color(0xFFDC2626)),
          ),
        ],
      ],
    );
  }
}

class AuthSoftButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthSoftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  State<AuthSoftButton> createState() => _AuthSoftButtonState();
}

class _AuthSoftButtonState extends State<AuthSoftButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return GestureDetector(
      onTap: enabled ? widget.onPressed : null,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 56,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: enabled ? AuthSoft.ctaGradient : null,
            color: enabled ? null : AuthSoft.fieldBorder,
            borderRadius: BorderRadius.circular(28),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AuthSoft.brand.withValues(alpha: 0.32),
                      blurRadius: 18,
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
              : Text(
                  widget.label,
                  style: AuthSoft.body(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AuthSoft.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class AuthSoftErrorBanner extends StatelessWidget {
  final String message;

  const AuthSoftErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AuthSoft.body(size: 13, color: const Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthSoftFooterLink extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback onTap;

  const AuthSoftFooterLink({
    super.key,
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix, style: AuthSoft.body(size: 14)),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: AuthSoft.body(
              size: 14,
              weight: FontWeight.w700,
              color: AuthSoft.brand,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthSoftPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const AuthSoftPhoneField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return AuthSoftField(
      controller: controller,
      hint: hint,
      keyboardType: TextInputType.phone,
      prefix: Align(
        widthFactor: 1,
        alignment: Alignment.center,
        child: Text(
          '+992',
          style: AuthSoft.body(
            size: 15,
            weight: FontWeight.w800,
            color: AuthSoft.brand,
          ),
        ),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _TjLocalPhoneFormatter(),
      ],
      validator: validator,
    );
  }
}

class _TjLocalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('992') && d.length >= 12) {
      d = d.substring(3, 12);
    } else if (d.startsWith('992')) {
      d = d.substring(3);
    }
    if (d.length > 9) d = d.substring(0, 9);
    return TextEditingValue(
      text: d,
      selection: TextSelection.collapsed(offset: d.length),
    );
  }
}
