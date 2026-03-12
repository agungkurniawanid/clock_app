import 'package:flutter/material.dart';

/// Shows a dialog with a scale (pop-in) animation instead of the default fade.
Future<T?> showScaleDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return builder(ctx);
    },
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );
}

/// Shows a bottom sheet whose content plays a scale animation on entrance.
Future<T?> showScaleBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool isDismissible = true,
  bool enableDrag = true,
  RouteSettings? routeSettings,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: shape,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: false,
    routeSettings: routeSettings,
    builder: (ctx) => _ScaleSheetWrapper(child: builder(ctx)),
  );
}

/// Internal wrapper that applies a scale+fade entrance animation to its child.
class _ScaleSheetWrapper extends StatefulWidget {
  final Widget child;

  const _ScaleSheetWrapper({required this.child});

  @override
  _ScaleSheetWrapperState createState() => _ScaleSheetWrapperState();
}

class _ScaleSheetWrapperState extends State<_ScaleSheetWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(opacity: _fade, child: widget.child),
    );
  }
}
