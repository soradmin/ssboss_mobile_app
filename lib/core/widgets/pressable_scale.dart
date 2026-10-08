import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/app_motion.dart';

/// Press-in scale feedback for CTAs and chips (mobile has no hover).
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool haptics;
  final double scale;
  final Duration duration;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptics = true,
    this.scale = AppMotion.pressScale,
    this.duration = AppMotion.press,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
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
              if (widget.haptics) {
                HapticFeedback.selectionClick();
              }
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: AppMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}
