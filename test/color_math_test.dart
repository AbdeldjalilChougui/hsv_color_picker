import 'dart:math' as math;
import 'dart:ui' show ColorSpace;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsv_color_picker/hsv_color_picker.dart';

const double _step = 1 / 255;

Color _randomColor(math.Random r) => Color.fromARGB(
    r.nextInt(256), r.nextInt(256), r.nextInt(256), r.nextInt(256));

void main() {
  group('ColorChannels', () {
    test('8-bit accessors read the float channels', () {
      const c = Color(0x80FF4020);
      expect(c.alpha8, 0x80);
      expect(c.red8, 0xFF);
      expect(c.green8, 0x40);
      expect(c.blue8, 0x20);
    });

    test('quantized snaps float channels to the 8-bit grid', () {
      const c = Color.from(alpha: 0.5, red: 0.1234, green: 0.9999, blue: 0);
      final q = c.quantized();
      expect(q.toARGB32(), c.toARGB32());
      expect(q.r * 255, closeTo((q.r * 255).roundToDouble(), 1e-9));
      expect(q.quantized(), q);
    });

    test('toSrgb converts a Display P3 color into sRGB, clamped', () {
      const p3 = Color.from(
          alpha: 1,
          red: 1,
          green: 0,
          blue: 0,
          colorSpace: ColorSpace.displayP3);
      final s = p3.toSrgb();
      expect(s.colorSpace, ColorSpace.sRGB);
      for (final v in [s.a, s.r, s.g, s.b]) {
        expect(v, inInclusiveRange(0, 1));
      }
      expect(s.red8, 255);
    });
  });

  group('HSV conversions', () {
    test('primary colors', () {
      final hsv = colorToHsv(const Color(0xFF0000FF));
      expect(hsv.hue, closeTo(240, 1e-9));
      expect(hsv.saturation, 1);
      expect(hsv.value, 1);
      expect(hsvToColor(const HSVColor.fromAHSV(1, 120, 1, 1)),
          const Color(0xFF00FF00));
    });

    test('property: random colors survive an HSV round-trip within 1/255', () {
      final r = math.Random(42);
      for (var i = 0; i < 20000; i++) {
        final c = _randomColor(r);
        final back = hsvToColor(colorToHsv(c));
        expect((back.a - c.a).abs(), lessThanOrEqualTo(_step));
        expect((back.r - c.r).abs(), lessThanOrEqualTo(_step));
        expect((back.g - c.g).abs(), lessThanOrEqualTo(_step));
        expect((back.b - c.b).abs(), lessThanOrEqualTo(_step));
      }
    });

    test('property: float colors survive an HSV round-trip within 1/255', () {
      final r = math.Random(7);
      for (var i = 0; i < 5000; i++) {
        final c = Color.from(
            alpha: r.nextDouble(),
            red: r.nextDouble(),
            green: r.nextDouble(),
            blue: r.nextDouble());
        final back = hsvToColor(colorToHsv(c));
        expect((back.r - c.r).abs(), lessThanOrEqualTo(_step));
        expect((back.g - c.g).abs(), lessThanOrEqualTo(_step));
        expect((back.b - c.b).abs(), lessThanOrEqualTo(_step));
        expect((back.a - c.a).abs(), lessThanOrEqualTo(_step));
      }
    });

    test('no precision drift after 1000 HSV/RGB round-trips', () {
      final r = math.Random(3);
      for (var i = 0; i < 200; i++) {
        final start = _randomColor(r);
        var c = start;
        var hsv = colorToHsv(c);
        for (var k = 0; k < 1000; k++) {
          c = hsvToColor(hsv);
          hsv = colorToHsv(c);
        }
        expect(c.toARGB32(), start.toARGB32());
      }
    });

    test('hsvToColor always returns 8-bit quantized sRGB colors', () {
      final c = hsvToColor(const HSVColor.fromAHSV(0.333, 17.3, 0.61, 0.77));
      expect(c, c.quantized());
      expect(c.colorSpace, ColorSpace.sRGB);
    });

    test('hsvFromColor keeps the previous hue for greys and black', () {
      const previous = HSVColor.fromAHSV(1, 200, 0.7, 0.8);
      final grey = hsvFromColor(const Color(0xFF808080), previous: previous);
      expect(grey.hue, 200);
      expect(grey.saturation, 0);
      final black = hsvFromColor(const Color(0xFF000000), previous: previous);
      expect(black.hue, 200);
      expect(black.saturation, 0.7);
      expect(black.value, 0);
      final red = hsvFromColor(const Color(0xFFFF0000), previous: previous);
      expect(red.hue, 0);
    });

    test('hsvFromColor returns previous unchanged when it maps to the color',
        () {
      const previous = HSVColor.fromAHSV(1, 200, 0.0, 0.5);
      final same = hsvFromColor(hsvToColor(previous), previous: previous);
      expect(same, previous);
    });
  });

  group('HSL conversions', () {
    test('known values', () {
      final hsl = hsvToHsl(const HSVColor.fromAHSV(1, 0, 1, 1));
      expect(hsl.lightness, closeTo(0.5, 1e-12));
      expect(hsl.saturation, closeTo(1, 1e-12));
      final white = hsvToHsl(const HSVColor.fromAHSV(1, 30, 0, 1));
      expect(white.lightness, 1);
      expect(white.saturation, 0);
      expect(white.hue, 30);
    });

    test('property: HSV -> HSL -> HSV round-trips and matches Flutter', () {
      final r = math.Random(11);
      for (var i = 0; i < 20000; i++) {
        final hsv = HSVColor.fromAHSV(r.nextDouble(), r.nextDouble() * 360,
            r.nextDouble(), r.nextDouble());
        final hsl = hsvToHsl(hsv);
        final back = hslToHsv(hsl);
        expect(back.hue, hsv.hue);
        expect(back.alpha, hsv.alpha);
        expect(back.value, closeTo(hsv.value, 1e-9));
        if (hsv.value > 1e-6 && hsl.lightness < 1 - 1e-6) {
          expect(back.saturation, closeTo(hsv.saturation, 1e-6));
        }
        final viaFlutter = HSLColor.fromColor(hsv.toColor());
        final ours = hsvToHsl(colorToHsv(hsv.toColor()));
        expect(ours.lightness, closeTo(viaFlutter.lightness, 1e-9));
      }
    });

    test('hslToColor and colorToHsl round-trip within 1/255', () {
      final r = math.Random(5);
      for (var i = 0; i < 5000; i++) {
        final c = _randomColor(r);
        final back = hslToColor(colorToHsl(c));
        expect((back.r - c.r).abs(), lessThanOrEqualTo(_step));
        expect((back.g - c.g).abs(), lessThanOrEqualTo(_step));
        expect((back.b - c.b).abs(), lessThanOrEqualTo(_step));
      }
    });
  });
}
