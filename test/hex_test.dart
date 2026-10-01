import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chroma_picker/chroma_picker.dart';

void main() {
  group('colorFromHex', () {
    test('parses #RGB, #RRGGBB and #AARRGGBB (default)', () {
      expect(colorFromHex('#abc'), const Color(0xFFAABBCC));
      expect(colorFromHex('ABC'), const Color(0xFFAABBCC));
      expect(colorFromHex('#AABBCC'), const Color(0xFFAABBCC));
      expect(colorFromHex('80aabbcc'), const Color(0x80AABBCC));
      expect(colorFromHex('#8abc'), const Color(0x88AABBCC));
    });

    test('parses #RRGGBBAA and #RGBA with trailing alpha', () {
      const t = HexAlphaPosition.trailing;
      expect(
          colorFromHex('#AABBCC80', alphaPosition: t), const Color(0x80AABBCC));
      expect(colorFromHex('#abc8', alphaPosition: t), const Color(0x88AABBCC));
      expect(
          colorFromHex('#AABBCC', alphaPosition: t), const Color(0xFFAABBCC));
    });

    test('tolerates whitespace, 0x prefix and mixed case', () {
      expect(colorFromHex('  #aAbBcC \n'), const Color(0xFFAABBCC));
      expect(colorFromHex('0xFF112233'), const Color(0xFF112233));
      expect(colorFromHex('0X112233'), const Color(0xFF112233));
    });

    test('rejects invalid input', () {
      for (final s in [
        '',
        '#',
        'bc',
        'aabbc',
        '#ffaabbccd',
        'aabbcx',
        '#aabbвв',
        '##abc',
        'a b c',
      ]) {
        expect(colorFromHex(s), isNull, reason: s);
      }
    });

    test('enableAlpha: false forces opaque', () {
      expect(colorFromHex('#00AABBCC', enableAlpha: false),
          const Color(0xFFAABBCC));
    });
  });

  group('colorToHex', () {
    const c = Color(0x80AABBCC);
    test('formats in every HexFormat', () {
      expect(colorToHex(c), '#AABBCC');
      expect(colorToHex(c, format: HexFormat.aarrggbb), '#80AABBCC');
      expect(colorToHex(c, format: HexFormat.rrggbbaa), '#AABBCC80');
      expect(colorToHex(c, format: HexFormat.rgb), '#ABC');
      expect(colorToHex(const Color(0xFFABCDEF), format: HexFormat.rgb),
          '#ABCDEF');
      expect(colorToHex(c, includeHash: false, upperCase: false), 'aabbcc');
    });

    test('extensions mirror the functions', () {
      expect(c.toHexString(format: HexFormat.aarrggbb), '#80AABBCC');
      expect('#80aabbcc'.toColor(), c);
      expect('nope'.toColor(), isNull);
    });

    test('property: hex parse and format round-trip exactly', () {
      final r = math.Random(1234);
      for (var i = 0; i < 20000; i++) {
        final c = Color(r.nextInt(1 << 32));
        final lead = colorToHex(c, format: HexFormat.aarrggbb);
        expect(colorFromHex(lead)!.toARGB32(), c.toARGB32());
        final trail = colorToHex(c, format: HexFormat.rrggbbaa);
        expect(
            colorFromHex(trail, alphaPosition: HexAlphaPosition.trailing)!
                .toARGB32(),
            c.toARGB32());
        final opaque = c.withAlpha(255);
        expect(colorFromHex(colorToHex(opaque))!.toARGB32(), opaque.toARGB32());
        expect(
            colorFromHex(colorToHex(opaque, format: HexFormat.rgb))!.toARGB32(),
            opaque.toARGB32());
        final lower = colorToHex(c,
            format: HexFormat.aarrggbb, upperCase: false, includeHash: false);
        expect(
            colorToHex(colorFromHex(lower)!, format: HexFormat.aarrggbb), lead);
      }
    });

    test('HexFormat.alphaPosition matches its layout', () {
      expect(HexFormat.aarrggbb.alphaPosition, HexAlphaPosition.leading);
      expect(HexFormat.rrggbbaa.alphaPosition, HexAlphaPosition.trailing);
      expect(HexFormat.aarrggbb.hasAlpha, isTrue);
      expect(HexFormat.rrggbb.hasAlpha, isFalse);
    });
  });
}
