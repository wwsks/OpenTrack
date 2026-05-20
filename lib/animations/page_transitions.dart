import 'package:flutter/material.dart';

class SlideFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideFadeTransitionType type;

  SlideFadeRoute({
    required this.page,
    this.type = SlideFadeTransitionType.fromRight,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _buildTransition(
              context: context,
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
              type: type,
            );
          },
        );

  static Widget _buildTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    required SlideFadeTransitionType type,
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    Offset begin;
    switch (type) {
      case SlideFadeTransitionType.fromRight:
        begin = const Offset(0.15, 0.0);
        break;
      case SlideFadeTransitionType.fromBottom:
        begin = const Offset(0.0, 0.08);
        break;
      case SlideFadeTransitionType.fade:
        begin = Offset.zero;
        break;
    }

    return Stack(
      children: [
        // Parallax on previous page (Telegram-style)
        if (secondaryAnimation.status != AnimationStatus.dismissed)
          AnimatedBuilder(
            animation: secondaryCurved,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-40 * secondaryCurved.value, 0),
                child: Opacity(
                  opacity: (1 - secondaryCurved.value * 0.3).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: child,
          ),
        // New page slide + fade in
        AnimatedBuilder(
          animation: curved,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                begin.dx * (1 - curved.value) * MediaQuery.of(context).size.width,
                begin.dy * (1 - curved.value) * MediaQuery.of(context).size.height,
              ),
              child: Opacity(
                opacity: curved.value,
                child: child,
              ),
            );
          },
          child: child,
        ),
      ],
    );
  }
}

enum SlideFadeTransitionType { fromRight, fromBottom, fade }

// Scale + Fade for modals/bottom sheets
class ScaleFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ScaleFadeRoute({
    required this.page,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInBack,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}
