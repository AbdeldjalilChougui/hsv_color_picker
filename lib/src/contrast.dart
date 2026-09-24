import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'color_math.dart';

/// Relative luminance of [color] as defined by WCAG 2.x, in `0..1`.
///
/// Uses the sRGB transfer function with the 0.04045 threshold and the
/// 0.2126 / 0.7152 / 0.0722 channel weights. Alpha is ignored.
double relativeLuminance(Color color) {
  final c = color.toSrgb();
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// WCAG 2.x contrast ratio between two colors, from `1` to `21`.
///
/// The order of the arguments does not matter. If [foreground] is
/// translucent it is composited over [background] first; the background's
/// own alpha is ignored.
double contrastRatio(Color foreground, Color background) {
  final bg = background.toSrgb().withValues(alpha: 1);
  final fg = Color.alphaBlend(foreground.toSrgb(), bg);
  final l1 = relativeLuminance(fg);
  final l2 = relativeLuminance(bg);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// The WCAG 2.x conformance a contrast ratio reaches for text.
enum WcagRating {
  /// Below 3:1.
  fail,

  /// At least 3:1: AA for large text only.
  aaLarge,

  /// At least 4.5:1: AA for normal text, AAA for large text.
  aa,

  /// At least 7:1: AAA for normal text.
  aaa;

  /// A short human-readable label, for example `AA Large`.
  String get label => switch (this) {
        fail => 'Fail',
        aaLarge => 'AA Large',
        aa => 'AA',
        aaa => 'AAA',
      };
}

/// Classifies a contrast [ratio] against the WCAG 2.x thresholds.
WcagRating wcagRating(double ratio) {
  if (ratio >= 7) return WcagRating.aaa;
  if (ratio >= 4.5) return WcagRating.aa;
  if (ratio >= 3) return WcagRating.aaLarge;
  return WcagRating.fail;
}

/// Whether white text has more contrast on [background] than black text.
bool useWhiteForeground(Color background) =>
    contrastRatio(const Color(0xFFFFFFFF), background) >
    contrastRatio(const Color(0xFF000000), background);
