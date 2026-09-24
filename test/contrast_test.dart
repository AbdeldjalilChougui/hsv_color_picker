import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsv_color_picker/hsv_color_picker.dart';

void main() {
  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  group('relativeLuminance (WCAG 2.x)', () {
    test('endpoints and primaries use the 0.2126/0.7152/0.0722 weights', () {
      expect(relativeLuminance(white), closeTo(1, 1e-12));
      expect(relativeLuminance(black), 0);
      expect(relativeLuminance(const Color(0xFFFF0000)), closeTo(0.2126, 1e-9));
      expect(relativeLuminance(const Color(0xFF00FF00)), closeTo(0.7152, 1e-9));
      expect(relativeLuminance(const Color(0xFF0000FF)), closeTo(0.0722, 1e-9));
    });

    test('linear segment below the sRGB threshold', () {
      // 10/255 = 0.0392 is below 0.04045, so it is divided by 12.92.
      expect(relativeLuminance(const Color(0xFF0A0A0A)),
          closeTo(10 / 255 / 12.92, 1e-12));
    });

    test('Flutter agrees', () {
      const c = Color(0xFF3366CC);
      expect(relativeLuminance(c), closeTo(c.computeLuminance(), 1e-6));
    });
  });

  group('contrastRatio', () {
    test('known examples', () {
      expect(contrastRatio(black, white), closeTo(21, 1e-9));
      expect(contrastRatio(white, black), closeTo(21, 1e-9));
      expect(contrastRatio(white, white), 1);
      // #767676 is the lightest grey that passes AA (4.5:1) on white.
      expect(
          contrastRatio(const Color(0xFF767676), white), closeTo(4.54, 0.005));
      expect(
          contrastRatio(const Color(0xFF777777), white), closeTo(4.48, 0.005));
      expect(
          contrastRatio(const Color(0xFFFF0000), white), closeTo(4.0, 0.005));
      expect(
          contrastRatio(const Color(0xFF0000FF), white), closeTo(8.59, 0.005));
    });

    test('translucent colors are composited over the other color', () {
      final half = contrastRatio(const Color(0x80000000), white);
      expect(
          half, closeTo(contrastRatio(const Color(0xFF7F7F7F), white), 0.05));
    });

    test('ratings follow the WCAG thresholds', () {
      expect(wcagRating(21), WcagRating.aaa);
      expect(wcagRating(7), WcagRating.aaa);
      expect(wcagRating(6.99), WcagRating.aa);
      expect(wcagRating(4.5), WcagRating.aa);
      expect(wcagRating(4.49), WcagRating.aaLarge);
      expect(wcagRating(3), WcagRating.aaLarge);
      expect(wcagRating(2.99), WcagRating.fail);
    });

    test('useWhiteForeground picks the higher-contrast text color', () {
      expect(useWhiteForeground(black), isTrue);
      expect(useWhiteForeground(white), isFalse);
      expect(useWhiteForeground(const Color(0xFF0000FF)), isTrue);
      expect(useWhiteForeground(const Color(0xFFFFFF00)), isFalse);
    });
  });
}
