import 'dart:math' as math;
import 'dart:ui' show ColorSpace;

import 'package:flutter/painting.dart';

/// 8-bit channel accessors and helpers built on the Flutter 3.27+ `Color`
/// API (`a`, `r`, `g`, `b`, `toARGB32()`), with no deprecated getters.
extension ColorChannels on Color {
  /// Alpha channel as an integer in `0..255`.
  int get alpha8 => _to8(a);

  /// Red channel as an integer in `0..255`.
  int get red8 => _to8(r);

  /// Green channel as an integer in `0..255`.
  int get green8 => _to8(g);

  /// Blue channel as an integer in `0..255`.
  int get blue8 => _to8(b);

  /// This color converted to the sRGB color space with every channel
  /// clamped to `0..1`.
  ///
  /// Wide-gamut colors (for example Display P3) are converted first, so the
  /// HSV, HSL and hex helpers always work in sRGB.
  Color toSrgb() {
    final c = colorSpace == ColorSpace.sRGB
        ? this
        : withValues(colorSpace: ColorSpace.sRGB);
    return Color.from(
      alpha: _clamp01(c.a),
      red: _clamp01(c.r),
      green: _clamp01(c.g),
      blue: _clamp01(c.b),
    );
  }

  /// This color in sRGB with each channel snapped to the nearest 8-bit
  /// value. Quantizing twice gives the same result as quantizing once.
  Color quantized() => Color(toSrgb().toARGB32());
}

int _to8(double v) => (_clamp01(v) * 255).round();

double _clamp01(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

/// Converts [color] (any color space) to an [HSVColor] in sRGB.
HSVColor colorToHsv(Color color) => HSVColor.fromColor(color.toSrgb());

/// Converts [hsv] to an 8-bit quantized sRGB [Color].
///
/// Quantizing on every conversion is what keeps repeated HSV/RGB round-trips
/// from drifting.
Color hsvToColor(HSVColor hsv) => hsv.toColor().quantized();

/// Converts [color] (any color space) to an [HSLColor] in sRGB.
HSLColor colorToHsl(Color color) => HSLColor.fromColor(color.toSrgb());

/// Converts [hsl] to an 8-bit quantized sRGB [Color].
Color hslToColor(HSLColor hsl) => hsl.toColor().quantized();

/// Converts [color] to HSV while keeping as much of [previous] as the color
/// allows.
///
/// A grey has no hue and black has neither hue nor saturation, so a plain
/// conversion would snap the hue (and saturation) to zero. When [previous]
/// is given, its hue is kept for greys and its hue and saturation are kept
/// for black. If [previous] already produces [color], it is returned as is.
HSVColor hsvFromColor(Color color, {HSVColor? previous}) {
  final target = color.quantized();
  if (previous != null && hsvToColor(previous) == target) return previous;
  final hsv = colorToHsv(target);
  if (previous == null) return hsv;
  if (hsv.value == 0) {
    return HSVColor.fromAHSV(hsv.alpha, previous.hue, previous.saturation, 0);
  }
  if (hsv.saturation == 0) {
    return HSVColor.fromAHSV(hsv.alpha, previous.hue, 0, hsv.value);
  }
  return hsv;
}

/// Converts an [HSVColor] to an [HSLColor] exactly (no RGB step), keeping
/// the hue even for greys.
HSLColor hsvToHsl(HSVColor hsv) {
  final v = hsv.value;
  final l = v * (1 - hsv.saturation / 2);
  final m = math.min(l, 1 - l);
  final s = m <= 0 ? 0.0 : ((v - l) / m).clamp(0.0, 1.0);
  return HSLColor.fromAHSL(hsv.alpha, hsv.hue, s, l.clamp(0.0, 1.0));
}

/// Converts an [HSLColor] to an [HSVColor] exactly (no RGB step), keeping
/// the hue even for greys.
HSVColor hslToHsv(HSLColor hsl) {
  final l = hsl.lightness;
  final v = (l + hsl.saturation * math.min(l, 1 - l)).clamp(0.0, 1.0);
  final s = v <= 0 ? 0.0 : (2 * (1 - l / v)).clamp(0.0, 1.0);
  return HSVColor.fromAHSV(hsl.alpha, hsl.hue, s, v);
}
