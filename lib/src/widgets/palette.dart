import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color_math.dart';
import 'color_slider.dart';
import 'common.dart';

/// The 2D color space shown by [ColorPickerArea]. The channel that is not
/// on the area is edited by the slider named by [sliderTrack].
enum PaletteType {
  /// Same as [hsvWithHue].
  hsv,

  /// Saturation across, value up; hue on the slider.
  hsvWithHue,

  /// Hue across, saturation up; value on the slider.
  hsvWithValue,

  /// Hue across, value up; saturation on the slider.
  hsvWithSaturation,

  /// Same as [hslWithHue].
  hsl,

  /// HSL saturation across, lightness up; hue on the slider.
  hslWithHue,

  /// Hue across, HSL saturation up; lightness on the slider.
  hslWithLightness,

  /// Hue across, lightness up; HSL saturation on the slider.
  hslWithSaturation,

  /// Same as [rgbWithBlue].
  rgb,

  /// Red across, green up; blue on the slider.
  rgbWithBlue,

  /// Blue across, red up; green on the slider.
  rgbWithGreen,

  /// Blue across, green up; red on the slider.
  rgbWithRed,

  /// A hue wheel (angle = hue, radius = saturation); value on the slider.
  hueWheel;

  /// The slider that edits the channel this palette does not show.
  TrackType get sliderTrack => switch (this) {
        hsv || hsvWithHue || hsl || hslWithHue => TrackType.hue,
        hsvWithValue || hueWheel => TrackType.value,
        hsvWithSaturation => TrackType.saturation,
        hslWithLightness => TrackType.lightness,
        hslWithSaturation => TrackType.saturationForHSL,
        rgb || rgbWithBlue => TrackType.blue,
        rgbWithGreen => TrackType.green,
        rgbWithRed => TrackType.red,
      };

  PaletteType get _canonical => switch (this) {
        hsv => hsvWithHue,
        hsl => hslWithHue,
        rgb => rgbWithBlue,
        _ => this,
      };

  /// Position of [hsv] on the area, as fractions of width and height
  /// (y grows downwards). For [hueWheel] this is relative to the square
  /// that holds the wheel.
  Offset positionOf(HSVColor hsv) {
    final hsl = hsvToHsl(hsv);
    final c = hsvToColor(hsv);
    switch (_canonical) {
      case hsvWithHue:
        return Offset(hsv.saturation, 1 - hsv.value);
      case hsvWithValue:
        return Offset(hsv.hue / 360, 1 - hsv.saturation);
      case hsvWithSaturation:
        return Offset(hsv.hue / 360, 1 - hsv.value);
      case hslWithHue:
        return Offset(hsl.saturation, 1 - hsl.lightness);
      case hslWithLightness:
        return Offset(hsl.hue / 360, 1 - hsl.saturation);
      case hslWithSaturation:
        return Offset(hsl.hue / 360, 1 - hsl.lightness);
      case rgbWithBlue:
        return Offset(c.r, 1 - c.g);
      case rgbWithGreen:
        return Offset(c.b, 1 - c.r);
      case rgbWithRed:
        return Offset(c.b, 1 - c.g);
      case hueWheel:
        final a = hsv.hue * math.pi / 180;
        return Offset(0.5 + math.cos(a) * hsv.saturation / 2,
            0.5 + math.sin(a) * hsv.saturation / 2);
      default:
        throw StateError('unreachable');
    }
  }

  /// The color at fractional position [p] (clamped), starting from [hsv]
  /// for the channels the area does not control.
  HSVColor colorAt(HSVColor hsv, Offset p) {
    final x = p.dx.clamp(0.0, 1.0);
    final y = p.dy.clamp(0.0, 1.0);
    HSVColor fromRgb(double r, double g, double b) =>
        hsvFromColor(Color.from(alpha: hsv.alpha, red: r, green: g, blue: b),
                previous: hsv)
            .withAlpha(hsv.alpha);
    final c = hsvToColor(hsv);
    switch (_canonical) {
      case hsvWithHue:
        return hsv.withSaturation(x).withValue(1 - y);
      case hsvWithValue:
        return hsv.withHue(x * 360).withSaturation(1 - y);
      case hsvWithSaturation:
        return hsv.withHue(x * 360).withValue(1 - y);
      case hslWithHue:
        return hslToHsv(hsvToHsl(hsv).withSaturation(x).withLightness(1 - y));
      case hslWithLightness:
        return hslToHsv(hsvToHsl(hsv).withHue(x * 360).withSaturation(1 - y));
      case hslWithSaturation:
        return hslToHsv(hsvToHsl(hsv).withHue(x * 360).withLightness(1 - y));
      case rgbWithBlue:
        return fromRgb(x, 1 - y, c.b);
      case rgbWithGreen:
        return fromRgb(1 - y, c.g, x);
      case rgbWithRed:
        return fromRgb(c.r, 1 - y, x);
      case hueWheel:
        final dx = p.dx - 0.5, dy = p.dy - 0.5;
        final s = (math.sqrt(dx * dx + dy * dy) * 2).clamp(0.0, 1.0);
        if (s == 0) return hsv.withSaturation(0);
        final h = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
        return hsv.withHue(h).withSaturation(s);
      default:
        throw StateError('unreachable');
    }
  }
}

/// The 2D palette of a color picker.
///
/// Drag or tap to pick. When focused, the arrow keys move the pointer
/// (Shift moves ten times further). The palette geometry is not mirrored in
/// right-to-left layouts, because it is a color space, not a reading order.
class ColorPickerArea extends StatefulWidget {
  /// Creates a palette area.
  const ColorPickerArea(
    this.hsvColor,
    this.onColorChanged,
    this.paletteType, {
    super.key,
    this.onChangeStart,
    this.onChangeEnd,
    this.borderRadius = BorderRadius.zero,
    this.semanticLabel = 'Color palette',
    this.focusNode,
  });

  /// The current color.
  final HSVColor hsvColor;

  /// Called with the new color while the user interacts.
  final ValueChanged<HSVColor> onColorChanged;

  /// Called when an interaction starts.
  final ValueChanged<HSVColor>? onChangeStart;

  /// Called when an interaction ends, with the final color.
  final ValueChanged<HSVColor>? onChangeEnd;

  /// Which color space the area shows.
  final PaletteType paletteType;

  /// Corner radius of the area (ignored by [PaletteType.hueWheel]).
  final BorderRadius borderRadius;

  /// Label read by screen readers.
  final String semanticLabel;

  /// Optional focus node.
  final FocusNode? focusNode;

  @override
  State<ColorPickerArea> createState() => _ColorPickerAreaState();
}

class _ColorPickerAreaState extends State<ColorPickerArea> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  /// Last color emitted that the parent has not rebuilt with yet.
  HSVColor? _last;
  HSVColor get _hsv => _last ?? widget.hsvColor;

  @override
  void didUpdateWidget(ColorPickerArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _last = null;
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  Rect _box(Size size) {
    if (widget.paletteType != PaletteType.hueWheel) return Offset.zero & size;
    final side = math.min(size.width, size.height);
    return Rect.fromCenter(
        center: size.center(Offset.zero), width: side, height: side);
  }

  void _emitAt(Offset local, Size size) {
    final box = _box(size);
    final p = Offset(
        (local.dx - box.left) / box.width, (local.dy - box.top) / box.height);
    final next = widget.paletteType.colorAt(_hsv, p);
    _last = next;
    widget.onColorChanged(next);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!isKeyDown(event)) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final big = HardwareKeyboard.instance.isShiftPressed;
    final d = big ? 0.1 : 0.01;
    var dx = 0.0, dy = 0.0;
    if (k == LogicalKeyboardKey.arrowLeft) dx = -d;
    if (k == LogicalKeyboardKey.arrowRight) dx = d;
    if (k == LogicalKeyboardKey.arrowUp) dy = -d;
    if (k == LogicalKeyboardKey.arrowDown) dy = d;
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    final hsv = _hsv;
    HSVColor next;
    if (widget.paletteType == PaletteType.hueWheel) {
      // Left/right turn the hue, up/down change the saturation.
      next = hsv
          .withHue((hsv.hue + dx * 360 + 360) % 360)
          .withSaturation((hsv.saturation - dy).clamp(0.0, 1.0));
    } else {
      final p = widget.paletteType.positionOf(hsv);
      next = widget.paletteType.colorAt(hsv, p + Offset(dx, dy));
    }
    widget.onChangeStart?.call(hsv);
    _last = next;
    widget.onColorChanged(next);
    widget.onChangeEnd?.call(next);
    return KeyEventResult.handled;
  }

  String _describe(HSVColor hsv) {
    String pct(double v) => '${(v * 100).round()}%';
    return 'Hue ${hsv.hue.round()}°, saturation ${pct(hsv.saturation)}, '
        'value ${pct(hsv.value)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: _describe(widget.hsvColor),
      child: Focus(
        focusNode: _node,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          return PanRegion(
            onStart: (p) {
              widget.onChangeStart?.call(_hsv);
              _emitAt(p, size);
            },
            onUpdate: (p) => _emitAt(p, size),
            onEnd: () => widget.onChangeEnd?.call(_hsv),
            child: CustomPaint(
              size: size,
              painter: _PalettePainter(
                type: widget.paletteType,
                hsv: widget.hsvColor,
                borderRadius: widget.borderRadius,
                focused: _focused,
                focusColor: scheme.primary,
                box: _box(size),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PalettePainter extends CustomPainter {
  _PalettePainter({
    required this.type,
    required this.hsv,
    required this.borderRadius,
    required this.focused,
    required this.focusColor,
    required this.box,
  });

  final PaletteType type;
  final HSVColor hsv;
  final BorderRadius borderRadius;
  final bool focused;
  final Color focusColor;
  final Rect box;

  static final List<Color> _hues = [
    for (var h = 0; h <= 360; h += 60)
      HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()
  ];

  void _fill(Canvas c, Rect r, Gradient g,
      [BlendMode mode = BlendMode.srcOver]) {
    c.drawRect(
        r,
        Paint()
          ..shader = g.createShader(r)
          ..blendMode = mode);
  }

  void _solid(Canvas c, Rect r, Color color) =>
      c.drawRect(r, Paint()..color = color);

  static const _down = [Alignment.topCenter, Alignment.bottomCenter];

  LinearGradient _vertical(List<Color> colors) =>
      LinearGradient(begin: _down[0], end: _down[1], colors: colors);

  @override
  void paint(Canvas canvas, Size size) {
    final r = box;
    final opaque = hsv.withAlpha(1);
    final hsl = hsvToHsl(opaque);
    const white = Color(0xFFFFFFFF), black = Color(0xFF000000);
    const clear = Color(0x00FFFFFF), clearBlack = Color(0x00000000);
    canvas.save();
    if (type == PaletteType.hueWheel) {
      canvas.clipPath(Path()..addOval(r));
    } else {
      canvas.clipRRect(borderRadius.toRRect(r));
    }
    switch (type._canonical) {
      case PaletteType.hsvWithHue:
        _fill(
            canvas,
            r,
            LinearGradient(colors: [
              white,
              opaque.withSaturation(1).withValue(1).toColor()
            ]));
        _fill(canvas, r, _vertical([clearBlack, black]));
      case PaletteType.hsvWithValue:
        _fill(canvas, r, LinearGradient(colors: _hues));
        _fill(canvas, r, _vertical([clear, white]));
        _solid(canvas, r, black.withValues(alpha: 1 - hsv.value));
      case PaletteType.hsvWithSaturation:
        _fill(canvas, r, LinearGradient(colors: _hues));
        _solid(canvas, r, white.withValues(alpha: 1 - hsv.saturation));
        _fill(canvas, r, _vertical([clearBlack, black]));
      case PaletteType.hslWithHue:
        _fill(
            canvas,
            r,
            LinearGradient(colors: [
              const Color(0xFF808080),
              hsl.withSaturation(1).withLightness(0.5).toColor()
            ]));
        _fill(canvas, r,
            _vertical([white, clear, clearBlack, black]).copyWithStops());
      case PaletteType.hslWithLightness:
        _fill(canvas, r, LinearGradient(colors: _hues));
        _fill(canvas, r,
            _vertical([const Color(0x00808080), const Color(0xFF808080)]));
        final l = hsl.lightness;
        if (l < 0.5) _solid(canvas, r, black.withValues(alpha: 1 - l * 2));
        if (l > 0.5) _solid(canvas, r, white.withValues(alpha: (l - 0.5) * 2));
      case PaletteType.hslWithSaturation:
        _fill(canvas, r, LinearGradient(colors: _hues));
        _solid(canvas, r,
            const Color(0xFF808080).withValues(alpha: 1 - hsl.saturation));
        _fill(canvas, r,
            _vertical([white, clear, clearBlack, black]).copyWithStops());
      case PaletteType.rgbWithBlue:
      case PaletteType.rgbWithGreen:
      case PaletteType.rgbWithRed:
        _paintRgb(canvas, r, hsvToColor(opaque));
      case PaletteType.hueWheel:
        _fill(canvas, r, SweepGradient(colors: _hues));
        _fill(canvas, r, const RadialGradient(colors: [white, clear]));
        _solid(canvas, r, black.withValues(alpha: 1 - hsv.value));
      default:
    }
    canvas.restore();
    final p = type.positionOf(hsv);
    final center = Offset(r.left + p.dx * r.width, r.top + p.dy * r.height);
    paintPointer(canvas, center, 8,
        fill: hsvToColor(opaque), focused: focused, focusColor: focusColor);
  }

  /// Additive RGB: the x channel is drawn as a horizontal ramp, the y
  /// channel is added on top with [BlendMode.plus], and the fixed channel
  /// is part of the base ramp.
  void _paintRgb(Canvas canvas, Rect r, Color c) {
    Color rgb(double red, double green, double blue) =>
        Color.from(alpha: 1, red: red, green: green, blue: blue);
    late Color x0, x1, y1;
    switch (type._canonical) {
      case PaletteType.rgbWithBlue: // x = red, y = green
        x0 = rgb(0, 0, c.b);
        x1 = rgb(1, 0, c.b);
        y1 = rgb(0, 1, 0);
      case PaletteType.rgbWithGreen: // x = blue, y = red
        x0 = rgb(0, c.g, 0);
        x1 = rgb(0, c.g, 1);
        y1 = rgb(1, 0, 0);
      default: // rgbWithRed: x = blue, y = green
        x0 = rgb(c.r, 0, 0);
        x1 = rgb(c.r, 0, 1);
        y1 = rgb(0, 1, 0);
    }
    canvas.saveLayer(r, Paint());
    _fill(canvas, r, LinearGradient(colors: [x0, x1]));
    _fill(canvas, r, _vertical([y1, const Color(0xFF000000)]), BlendMode.plus);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PalettePainter old) =>
      old.type != type ||
      old.hsv != hsv ||
      old.focused != focused ||
      old.box != box ||
      old.borderRadius != borderRadius ||
      old.focusColor != focusColor;
}

extension on LinearGradient {
  /// White at the top, the pure color in the middle, black at the bottom.
  LinearGradient copyWithStops() => LinearGradient(
      begin: begin, end: end, colors: colors, stops: const [0, 0.5, 0.5, 1]);
}

/// A hue ring: drag around it (or use the arrow keys) to change the hue.
///
/// It is a semantics slider labelled `Hue` with increase and decrease
/// actions.
class ColorPickerHueRing extends StatefulWidget {
  /// Creates a hue ring.
  const ColorPickerHueRing(
    this.hsvColor,
    this.onColorChanged, {
    super.key,
    this.displayThumbColor = true,
    this.strokeWidth = 20,
    this.onChangeStart,
    this.onChangeEnd,
    this.focusNode,
  });

  /// The current color.
  final HSVColor hsvColor;

  /// Called with the new color.
  final ValueChanged<HSVColor> onColorChanged;

  /// Called when an interaction starts.
  final ValueChanged<HSVColor>? onChangeStart;

  /// Called when an interaction ends.
  final ValueChanged<HSVColor>? onChangeEnd;

  /// Fill the thumb with the current hue.
  final bool displayThumbColor;

  /// Width of the ring.
  final double strokeWidth;

  /// Optional focus node.
  final FocusNode? focusNode;

  @override
  State<ColorPickerHueRing> createState() => _ColorPickerHueRingState();
}

class _ColorPickerHueRingState extends State<ColorPickerHueRing> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;
  bool _tracking = false;

  /// Last color emitted that the parent has not rebuilt with yet.
  HSVColor? _last;
  HSVColor get _hsv => _last ?? widget.hsvColor;

  @override
  void didUpdateWidget(ColorPickerHueRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _last = null;
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _setHue(double h) {
    final next = _hsv.withHue(((h % 360) + 360) % 360);
    _last = next;
    widget.onColorChanged(next);
  }

  void _discrete(double h) {
    widget.onChangeStart?.call(_hsv);
    _setHue(h);
    widget.onChangeEnd?.call(_last!);
  }

  double _angle(Offset local, Size size) {
    final d = local - size.center(Offset.zero);
    return math.atan2(d.dy, d.dx) * 180 / math.pi;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!isKeyDown(event)) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final h = _hsv.hue;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowRight) {
      _discrete(h + 1);
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft) {
      _discrete(h - 1);
    } else if (k == LogicalKeyboardKey.pageUp) {
      _discrete(h + 15);
    } else if (k == LogicalKeyboardKey.pageDown) {
      _discrete(h - 15);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hsvColor.hue;
    String fmt(double v) => '${(((v % 360) + 360) % 360).round()}°';
    return Semantics(
      container: true,
      slider: true,
      label: 'Hue',
      value: fmt(h),
      increasedValue: fmt(h + 1),
      decreasedValue: fmt(h - 1),
      textDirection: Directionality.of(context),
      onIncrease: () => _discrete(_hsv.hue + 1),
      onDecrease: () => _discrete(_hsv.hue - 1),
      child: Focus(
        focusNode: _node,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.biggest;
          final outer = math.min(size.width, size.height) / 2;
          return PanRegion(
            onStart: (p) {
              final dist = (p - size.center(Offset.zero)).distance;
              _tracking =
                  dist >= outer - widget.strokeWidth - 8 && dist <= outer + 8;
              if (!_tracking) return;
              widget.onChangeStart?.call(_hsv);
              _setHue(_angle(p, size));
            },
            onUpdate: (p) {
              if (_tracking) _setHue(_angle(p, size));
            },
            onEnd: () {
              if (_tracking) widget.onChangeEnd?.call(_hsv);
              _tracking = false;
            },
            child: CustomPaint(
              size: size,
              painter: _RingPainter(
                hue: h,
                strokeWidth: widget.strokeWidth,
                displayThumbColor: widget.displayThumbColor,
                focused: _focused,
                focusColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.hue,
    required this.strokeWidth,
    required this.displayThumbColor,
    required this.focused,
    required this.focusColor,
  });

  final double hue;
  final double strokeWidth;
  final bool displayThumbColor;
  final bool focused;
  final Color focusColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..shader = SweepGradient(colors: [
            for (var h = 0; h <= 360; h += 60)
              HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()
          ]).createShader(rect));
    final a = hue * math.pi / 180;
    final thumb = center + Offset(math.cos(a), math.sin(a)) * radius;
    paintPointer(canvas, thumb, strokeWidth / 2,
        fill: displayThumbColor
            ? HSVColor.fromAHSV(1, hue, 1, 1).toColor()
            : const Color(0xFFFFFFFF),
        focused: focused,
        focusColor: focusColor);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.hue != hue ||
      old.strokeWidth != strokeWidth ||
      old.displayThumbColor != displayThumbColor ||
      old.focused != focused ||
      old.focusColor != focusColor;
}
