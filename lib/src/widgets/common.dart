import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A pan recognizer that claims the pointer as soon as it goes down, so a
/// palette or slider inside a `TabBarView`, `PageView` or scroll view gets
/// the drag instead of the parent.
class _EagerPanGestureRecognizer extends PanGestureRecognizer {
  _EagerPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Reports pointer positions of a press-and-drag gesture in local
/// coordinates. Internal to the package.
class PanRegion extends StatelessWidget {
  /// Creates a pan region.
  const PanRegion({
    super.key,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.child,
  });

  /// Pointer went down at a local position.
  final ValueChanged<Offset> onStart;

  /// Pointer moved to a local position.
  final ValueChanged<Offset> onUpdate;

  /// Pointer was released or the gesture was cancelled.
  final VoidCallback onEnd;

  /// The painted content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _EagerPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerPanGestureRecognizer>(
          () => _EagerPanGestureRecognizer(debugOwner: this),
          (r) => r
            ..dragStartBehavior = DragStartBehavior.down
            ..onStart = ((d) => onStart(d.localPosition))
            ..onUpdate = ((d) => onUpdate(d.localPosition))
            ..onEnd = ((_) => onEnd())
            ..onCancel = onEnd,
        ),
      },
      child: MouseRegion(cursor: SystemMouseCursors.precise, child: child),
    );
  }
}

/// Paints a light/dark checkerboard, used behind translucent colors.
class CheckerboardPainter extends CustomPainter {
  /// Creates a checkerboard painter with square cells of [cell] pixels.
  const CheckerboardPainter({this.cell = 6});

  /// Cell size in logical pixels.
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final dark = Paint()..color = const Color(0xFFCCCCCC);
    for (var y = 0; y * cell < size.height; y++) {
      for (var x = 0; x * cell < size.width; x++) {
        if ((x + y).isEven) continue;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
      }
    }
  }

  @override
  bool shouldRepaint(CheckerboardPainter oldDelegate) =>
      oldDelegate.cell != cell;
}

/// Draws the round pointer used by palettes and sliders.
void paintPointer(
  Canvas canvas,
  Offset center,
  double radius, {
  required Color fill,
  required bool focused,
  required Color focusColor,
}) {
  canvas.drawCircle(center, radius, Paint()..color = fill);
  canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFFFFF));
  canvas.drawCircle(
      center,
      radius + 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66000000));
  if (focused) {
    canvas.drawCircle(
        center,
        radius + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusColor);
  }
}

/// Whether [event] is a key press or auto-repeat.
bool isKeyDown(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;
