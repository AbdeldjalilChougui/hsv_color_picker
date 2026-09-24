import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color_math.dart';
import 'common.dart';

/// Formats a slider value for display and for screen readers.
typedef SliderValueFormatter = String Function(double value);

/// A horizontal slider with a gradient track, built for color channels.
///
/// It is a real semantics slider (label, value, increase and decrease
/// actions), it is focusable, and the arrow, Page Up/Down, Home and End keys
/// adjust it. The track is mirrored in right-to-left layouts.
class ColorSlider extends StatefulWidget {
  /// Creates a color slider.
  const ColorSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.trackColors,
    required this.semanticLabel,
    this.min = 0,
    this.max = 1,
    this.step,
    this.largeStep,
    this.valueFormatter,
    this.onChangeStart,
    this.onChangeEnd,
    this.checkerboard = false,
    this.thumbColor,
    this.height = 32,
    this.focusNode,
    this.autofocus = false,
  }) : assert(max > min);

  /// Current value, between [min] and [max].
  final double value;

  /// Called with the new value while the user drags, taps, uses the
  /// keyboard or a screen reader action.
  final ValueChanged<double> onChanged;

  /// Called when an interaction starts.
  final ValueChanged<double>? onChangeStart;

  /// Called when an interaction ends, with the final value.
  final ValueChanged<double>? onChangeEnd;

  /// Colors of the track gradient, from [min] to [max].
  final List<Color> trackColors;

  /// Label read by screen readers, for example `Hue`.
  final String semanticLabel;

  /// Lowest value.
  final double min;

  /// Highest value.
  final double max;

  /// Amount one arrow key or screen reader action changes the value.
  /// Defaults to 1% of the range.
  final double? step;

  /// Amount Page Up / Page Down change the value. Defaults to 10 steps.
  final double? largeStep;

  /// Formats the value for screen readers. Defaults to a percentage.
  final SliderValueFormatter? valueFormatter;

  /// Paint a checkerboard under the track, for alpha tracks.
  final bool checkerboard;

  /// Fill of the thumb. Defaults to the track color at the current value.
  final Color? thumbColor;

  /// Total height of the slider.
  final double height;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Whether to request focus when first built.
  final bool autofocus;

  @override
  State<ColorSlider> createState() => _ColorSliderState();
}

class _ColorSliderState extends State<ColorSlider> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  /// The last value sent to [ColorSlider.onChanged] that the parent has not
  /// rebuilt with yet, so several key presses in one frame add up.
  double? _pending;
  double get _value => _pending ?? widget.value;

  @override
  void didUpdateWidget(ColorSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pending = null;
  }

  void _emit(double value) {
    _pending = value;
    widget.onChanged(value);
  }

  double get _step => widget.step ?? (widget.max - widget.min) / 100;
  double get _largeStep => widget.largeStep ?? _step * 10;
  double get _radius => widget.height * 0.4;

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(widget.min, widget.max).toDouble();

  String _format(double v) =>
      widget.valueFormatter?.call(v) ??
      '${((v - widget.min) / (widget.max - widget.min) * 100).round()}%';

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double _valueAt(Offset local, double width) {
    final usable = width - 2 * _radius;
    var t = usable <= 0 ? 0.0 : ((local.dx - _radius) / usable).clamp(0.0, 1.0);
    if (_rtl) t = 1 - t;
    return widget.min + t * (widget.max - widget.min);
  }

  void _discrete(double v) {
    final value = _clamp(v);
    widget.onChangeStart?.call(_value);
    _emit(value);
    widget.onChangeEnd?.call(value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!isKeyDown(event)) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final dir = _rtl ? -1 : 1;
    double? next;
    if (k == LogicalKeyboardKey.arrowRight) {
      next = _value + _step * dir;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      next = _value - _step * dir;
    } else if (k == LogicalKeyboardKey.arrowUp) {
      next = _value + _step;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      next = _value - _step;
    } else if (k == LogicalKeyboardKey.pageUp) {
      next = _value + _largeStep;
    } else if (k == LogicalKeyboardKey.pageDown) {
      next = _value - _largeStep;
    } else if (k == LogicalKeyboardKey.home) {
      next = widget.min;
    } else if (k == LogicalKeyboardKey.end) {
      next = widget.max;
    }
    if (next == null) return KeyEventResult.ignored;
    _discrete(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = _clamp(widget.value);
    return Semantics(
      container: true,
      slider: true,
      label: widget.semanticLabel,
      value: _format(v),
      increasedValue: _format(_clamp(v + _step)),
      decreasedValue: _format(_clamp(v - _step)),
      textDirection: Directionality.of(context),
      onIncrease: () => _discrete(_value + _step),
      onDecrease: () => _discrete(_value - _step),
      child: Focus(
        focusNode: _node,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            return PanRegion(
              onStart: (p) {
                final value = _valueAt(p, width);
                widget.onChangeStart?.call(value);
                _emit(value);
              },
              onUpdate: (p) => _emit(_valueAt(p, width)),
              onEnd: () => widget.onChangeEnd?.call(_value),
              child: CustomPaint(
                size: Size(width, widget.height),
                painter: _SliderPainter(
                  t: (v - widget.min) / (widget.max - widget.min),
                  colors: widget.trackColors,
                  checkerboard: widget.checkerboard,
                  thumbColor: widget.thumbColor,
                  radius: _radius,
                  rtl: _rtl,
                  focused: _focused,
                  focusColor: scheme.primary,
                  outline: scheme.outlineVariant,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.t,
    required this.colors,
    required this.checkerboard,
    required this.thumbColor,
    required this.radius,
    required this.rtl,
    required this.focused,
    required this.focusColor,
    required this.outline,
  });

  final double t;
  final List<Color> colors;
  final bool checkerboard;
  final Color? thumbColor;
  final double radius;
  final bool rtl;
  final bool focused;
  final Color focusColor;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = size.height * 0.45;
    final track = Rect.fromLTWH(radius, (size.height - trackHeight) / 2,
        size.width - 2 * radius, trackHeight);
    final rrect =
        RRect.fromRectAndRadius(track, Radius.circular(trackHeight / 2));
    final ordered = rtl ? colors.reversed.toList() : colors;
    canvas.save();
    canvas.clipRRect(rrect);
    if (checkerboard) {
      canvas.translate(track.left, track.top);
      const CheckerboardPainter().paint(canvas, track.size);
      canvas.translate(-track.left, -track.top);
    }
    canvas.drawRect(track,
        Paint()..shader = LinearGradient(colors: ordered).createShader(track));
    canvas.restore();
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = outline);
    final x = track.left + (rtl ? 1 - t : t) * track.width;
    paintPointer(canvas, Offset(x, size.height / 2), radius - 2,
        fill: thumbColor ?? _sample(t),
        focused: focused,
        focusColor: focusColor);
  }

  Color _sample(double t) {
    if (colors.length == 1) return colors.first;
    final pos = t.clamp(0.0, 1.0) * (colors.length - 1);
    final i = pos.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[i], colors[i + 1], pos - i)!.withValues(alpha: 1);
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.t != t ||
      old.rtl != rtl ||
      old.focused != focused ||
      old.thumbColor != thumbColor ||
      old.checkerboard != checkerboard ||
      old.focusColor != focusColor ||
      old.outline != outline ||
      !_sameColors(old.colors, colors);
}

bool _sameColors(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Which channel a [ColorPickerSlider] edits.
enum TrackType {
  /// HSV/HSL hue, 0-360 degrees.
  hue,

  /// HSV saturation.
  saturation,

  /// HSL saturation.
  saturationForHSL,

  /// HSV value (brightness).
  value,

  /// HSL lightness.
  lightness,

  /// RGB red, 0-255.
  red,

  /// RGB green, 0-255.
  green,

  /// RGB blue, 0-255.
  blue,

  /// Alpha (opacity).
  alpha;

  /// Default screen reader label for this track.
  String get label => switch (this) {
        hue => 'Hue',
        saturation || saturationForHSL => 'Saturation',
        value => 'Value',
        lightness => 'Lightness',
        red => 'Red',
        green => 'Green',
        blue => 'Blue',
        alpha => 'Alpha',
      };

  /// Short label (`H`, `S`, `V`, `L`, `R`, `G`, `B`, `A`).
  String get shortLabel => this == alpha ? 'A' : label.substring(0, 1);

  bool get _isRgb => this == red || this == green || this == blue;

  /// Lowest value of this track.
  double get min => 0;

  /// Highest value of this track.
  double get max => this == hue ? 360 : (_isRgb ? 255 : 1);

  /// Reads this track's value from [hsv].
  double read(HSVColor hsv) {
    switch (this) {
      case hue:
        return hsv.hue;
      case saturation:
        return hsv.saturation;
      case saturationForHSL:
        return hsvToHsl(hsv).saturation;
      case value:
        return hsv.value;
      case lightness:
        return hsvToHsl(hsv).lightness;
      case red:
        return hsvToColor(hsv).red8.toDouble();
      case green:
        return hsvToColor(hsv).green8.toDouble();
      case blue:
        return hsvToColor(hsv).blue8.toDouble();
      case alpha:
        return hsv.alpha;
    }
  }

  /// Returns [hsv] with this track set to [v].
  HSVColor write(HSVColor hsv, double v) {
    switch (this) {
      case hue:
        return hsv.withHue(v.clamp(0.0, 360.0));
      case saturation:
        return hsv.withSaturation(v.clamp(0.0, 1.0));
      case saturationForHSL:
        return hslToHsv(hsvToHsl(hsv).withSaturation(v.clamp(0.0, 1.0)));
      case value:
        return hsv.withValue(v.clamp(0.0, 1.0));
      case lightness:
        return hslToHsv(hsvToHsl(hsv).withLightness(v.clamp(0.0, 1.0)));
      case alpha:
        return hsv.withAlpha(v.clamp(0.0, 1.0));
      case red:
      case green:
      case blue:
        final c = hsvToColor(hsv);
        final n = v.round().clamp(0, 255);
        final next = Color.fromARGB(c.alpha8, this == red ? n : c.red8,
            this == green ? n : c.green8, this == blue ? n : c.blue8);
        return hsvFromColor(next, previous: hsv).withAlpha(hsv.alpha);
    }
  }

  /// Formats a value of this track for display.
  String format(double v) {
    if (this == hue) return '${v.round()}°';
    if (_isRgb) return '${v.round()}';
    return '${(v * 100).round()}%';
  }

  /// Gradient colors of this track for the current color.
  List<Color> trackColors(HSVColor hsv) {
    final opaque = hsv.withAlpha(1);
    switch (this) {
      case hue:
        return [
          for (var h = 0; h <= 360; h += 60)
            HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor()
        ];
      case saturation:
        return [
          opaque.withSaturation(0).toColor(),
          opaque.withSaturation(1).toColor()
        ];
      case saturationForHSL:
        final hsl = hsvToHsl(opaque);
        return [
          hsl.withSaturation(0).toColor(),
          hsl.withSaturation(1).toColor()
        ];
      case value:
        return [const Color(0xFF000000), opaque.withValue(1).toColor()];
      case lightness:
        final hsl = hsvToHsl(opaque);
        return [
          const Color(0xFF000000),
          hsl.withLightness(0.5).toColor(),
          const Color(0xFFFFFFFF)
        ];
      case red:
      case green:
      case blue:
        final c = hsvToColor(opaque);
        Color at(int n) => Color.fromARGB(255, this == red ? n : c.red8,
            this == green ? n : c.green8, this == blue ? n : c.blue8);
        return [at(0), at(255)];
      case alpha:
        final c = opaque.toColor();
        return [c.withValues(alpha: 0), c];
    }
  }
}

/// A [ColorSlider] bound to one channel ([trackType]) of an [HSVColor].
///
/// Hue and saturation survive even when the color is grey or black, so the
/// slider never appears stuck.
class ColorPickerSlider extends StatelessWidget {
  /// Creates a channel slider.
  const ColorPickerSlider(
    this.trackType,
    this.hsvColor,
    this.onColorChanged, {
    super.key,
    this.displayThumbColor = true,
    this.onChangeStart,
    this.onChangeEnd,
    this.semanticLabel,
    this.focusNode,
    this.height = 32,
  });

  /// The channel to edit.
  final TrackType trackType;

  /// The current color.
  final HSVColor hsvColor;

  /// Called with the updated color.
  final ValueChanged<HSVColor> onColorChanged;

  /// Called when an interaction starts, with the color at that moment.
  final ValueChanged<HSVColor>? onChangeStart;

  /// Called when an interaction ends, with the final color.
  final ValueChanged<HSVColor>? onChangeEnd;

  /// Fill the thumb with the color under it. When `false` the thumb is
  /// white.
  final bool displayThumbColor;

  /// Screen reader label. Defaults to [TrackType.label].
  final String? semanticLabel;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Height of the slider.
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColorSlider(
      value: trackType.read(hsvColor),
      min: trackType.min,
      max: trackType.max,
      step: trackType == TrackType.hue || trackType._isRgb ? 1 : 0.01,
      largeStep:
          trackType == TrackType.hue ? 15 : (trackType._isRgb ? 16 : 0.1),
      semanticLabel: semanticLabel ?? trackType.label,
      valueFormatter: trackType.format,
      trackColors: trackType.trackColors(hsvColor),
      checkerboard: trackType == TrackType.alpha,
      thumbColor: displayThumbColor ? null : const Color(0xFFFFFFFF),
      focusNode: focusNode,
      height: height,
      onChanged: (v) => onColorChanged(trackType.write(hsvColor, v)),
      onChangeStart:
          onChangeStart == null ? null : (_) => onChangeStart!(hsvColor),
      onChangeEnd: onChangeEnd == null
          ? null
          : (v) => onChangeEnd!(trackType.write(hsvColor, v)),
    );
  }
}
