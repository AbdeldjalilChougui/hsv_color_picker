import 'package:flutter/painting.dart';

import 'color_math.dart';

/// Where the alpha pair sits in an 8-digit (or 4-digit) hex string.
enum HexAlphaPosition {
  /// `#AARRGGBB` / `#ARGB`, as used by Flutter's `Color(0xAARRGGBB)` and
  /// Android.
  leading,

  /// `#RRGGBBAA` / `#RGBA`, as used by CSS.
  trailing,
}

/// Output layout for [colorToHex].
enum HexFormat {
  /// `#RGB` when every channel is a doubled digit (`#AABBCC` -> `#ABC`),
  /// otherwise `#RRGGBB`. Alpha is dropped.
  rgb,

  /// `#RRGGBB`. Alpha is dropped.
  rrggbb,

  /// `#AARRGGBB` (alpha first).
  aarrggbb,

  /// `#RRGGBBAA` (alpha last, CSS style).
  rrggbbaa;

  /// Whether this format writes the alpha channel.
  bool get hasAlpha => this == aarrggbb || this == rrggbbaa;

  /// The alpha position a parser needs to read this format back.
  HexAlphaPosition get alphaPosition =>
      this == rrggbbaa ? HexAlphaPosition.trailing : HexAlphaPosition.leading;
}

final RegExp _hexBody = RegExp(r'^[0-9a-fA-F]+$');

/// Parses a hex color string, or returns `null` if it is not valid.
///
/// Accepts 3, 4, 6 or 8 hex digits, an optional `#` or `0x` prefix, any
/// letter case, and surrounding whitespace. 4- and 8-digit strings carry
/// alpha at [alphaPosition]. When [enableAlpha] is `false` the result is
/// always opaque.
Color? colorFromHex(
  String input, {
  bool enableAlpha = true,
  HexAlphaPosition alphaPosition = HexAlphaPosition.leading,
}) {
  var s = input.trim();
  if (s.startsWith('#')) {
    s = s.substring(1);
  } else if (s.startsWith('0x') || s.startsWith('0X')) {
    s = s.substring(2);
  }
  if (!_hexBody.hasMatch(s)) return null;
  if (s.length == 3 || s.length == 4) {
    s = s.split('').map((c) => '$c$c').join();
  }
  int argb;
  if (s.length == 6) {
    argb = 0xFF000000 | int.parse(s, radix: 16);
  } else if (s.length == 8) {
    final v = int.parse(s, radix: 16);
    argb = alphaPosition == HexAlphaPosition.leading
        ? v
        : ((v & 0xFF) << 24) | (v >> 8);
  } else {
    return null;
  }
  if (!enableAlpha) argb |= 0xFF000000;
  return Color(argb);
}

/// Formats [color] as a hex string in [format].
///
/// The color is converted to 8-bit sRGB first, so wide-gamut and float
/// colors format predictably.
String colorToHex(
  Color color, {
  HexFormat format = HexFormat.rrggbb,
  bool includeHash = true,
  bool upperCase = true,
}) {
  final c = color.quantized();
  String two(int v) => v.toRadixString(16).padLeft(2, '0');
  final rgb = two(c.red8) + two(c.green8) + two(c.blue8);
  String body;
  switch (format) {
    case HexFormat.rgb:
      final short = rgb[0] == rgb[1] && rgb[2] == rgb[3] && rgb[4] == rgb[5];
      body = short ? '${rgb[0]}${rgb[2]}${rgb[4]}' : rgb;
    case HexFormat.rrggbb:
      body = rgb;
    case HexFormat.aarrggbb:
      body = two(c.alpha8) + rgb;
    case HexFormat.rrggbbaa:
      body = rgb + two(c.alpha8);
  }
  if (upperCase) body = body.toUpperCase();
  return includeHash ? '#$body' : body;
}

/// Hex formatting on [Color].
extension ColorToHex on Color {
  /// Same as [colorToHex] applied to this color.
  String toHexString({
    HexFormat format = HexFormat.rrggbb,
    bool includeHash = true,
    bool upperCase = true,
  }) =>
      colorToHex(this,
          format: format, includeHash: includeHash, upperCase: upperCase);
}

/// Hex parsing on [String].
extension HexToColor on String {
  /// Same as [colorFromHex] applied to this string.
  Color? toColor({
    bool enableAlpha = true,
    HexAlphaPosition alphaPosition = HexAlphaPosition.leading,
  }) =>
      colorFromHex(this,
          enableAlpha: enableAlpha, alphaPosition: alphaPosition);
}
