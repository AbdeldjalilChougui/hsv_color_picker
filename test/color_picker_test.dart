import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsv_color_picker/hsv_color_picker.dart';

import 'helpers.dart';

void main() {
  final hostKey = GlobalKey<EchoHostState>();

  Future<List<Color>> pumpEcho(
    WidgetTester tester, {
    Color initial = const Color(0xFF3366CC),
    PaletteType paletteType = PaletteType.hsvWithHue,
    bool enableAlpha = true,
    bool hexInputBar = true,
    TextDirection direction = TextDirection.ltr,
    Color? contrastReference,
    EyeDropperCallback? onEyeDropper,
    ValueChanged<Color>? onColorChangeEnd,
  }) async {
    final out = <Color>[];
    await pumpPicker(
      tester,
      EchoHost(
        key: hostKey,
        initial: initial,
        onChanged: out.add,
        builder: (color, onChanged) => ColorPicker(
          pickerColor: color,
          onColorChanged: onChanged,
          paletteType: paletteType,
          enableAlpha: enableAlpha,
          hexInputBar: hexInputBar,
          contrastReference: contrastReference,
          onEyeDropper: onEyeDropper,
          onColorChangeEnd: onColorChangeEnd,
        ),
      ),
      direction: direction,
    );
    return out;
  }

  group('dragging', () {
    testWidgets('the HSV palette sets saturation and value', (tester) async {
      final ends = <Color>[];
      final out = await pumpEcho(tester, onColorChangeEnd: ends.add);
      final area = tester.getRect(find.byType(ColorPickerArea));
      await tester.dragFrom(area.center, Offset(area.width, -area.height));
      final hsv = colorToHsv(out.last);
      expect(hsv.saturation, closeTo(1, 0.01));
      expect(hsv.value, closeTo(1, 0.01));
      expect(ends, isNotEmpty);
      await tester.tapAt(area.bottomLeft + const Offset(1, -1));
      expect(colorToHsv(out.last).value, closeTo(0, 0.01));
    });

    for (final type in PaletteType.values) {
      testWidgets('palette $type responds to taps', (tester) async {
        final out = await pumpEcho(tester,
            paletteType: type, initial: const Color(0xFF808040));
        final area = tester.getRect(find.byType(ColorPickerArea));
        await tester.tapAt(area.center + Offset(area.width / 5, 0));
        await tester.tapAt(area.topLeft + Offset(area.width / 4, 10));
        expect(out, isNotEmpty, reason: '$type');
        expect(out.toSet().length, greaterThan(1), reason: '$type');
      });
    }

    testWidgets('the hue slider changes the hue', (tester) async {
      final out = await pumpEcho(tester);
      final rect = tester.getRect(sliderNamed('Hue'));
      await tester.tapAt(rect.center);
      expect(colorToHsv(out.last).hue, closeTo(180, 3));
    });

    testWidgets('the alpha slider changes the alpha', (tester) async {
      final out = await pumpEcho(tester);
      final rect = tester.getRect(sliderNamed('Alpha'));
      await tester.dragFrom(rect.center, Offset(-rect.width, 0));
      expect(out.last.alpha8, 0);
      expect(out.last.withAlpha(255), const Color(0xFF3366CC));
    });

    testWidgets('no alpha slider when enableAlpha is false', (tester) async {
      await pumpEcho(tester, enableAlpha: false);
      expect(sliderNamed('Alpha'), findsNothing);
    });
  });

  group('external changes update the controls', () {
    testWidgets('alpha slider, hue slider, hex field and label follow',
        (tester) async {
      await pumpEcho(tester);
      hostKey.currentState!.set(const Color(0x40FF0000));
      await tester.pump();
      expect(sliderValue(tester, 'Alpha'), closeTo(0x40 / 255, 1e-9));
      expect(sliderValue(tester, 'Hue'), 0);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '#40FF0000');
    });

    testWidgets('echoing the output back does not reset the hue of greys',
        (tester) async {
      final out = await pumpEcho(tester, initial: const Color(0xFF808080));
      final hue = tester.getRect(sliderNamed('Hue'));
      await tester.tapAt(hue.center);
      await tester.pump();
      // The color is still grey (saturation 0), but the hue slider stays
      // where the user put it instead of snapping back to 0.
      expect(out.last, const Color(0xFF808080));
      expect(sliderValue(tester, 'Hue'), closeTo(180, 3));
      // Now raising saturation uses the chosen hue.
      final area = tester.getRect(find.byType(ColorPickerArea));
      await tester.tapAt(area.topRight + const Offset(-1, 1));
      expect(colorToHsv(out.last).hue, closeTo(180, 3));
    });

    testWidgets('no drift when the output is echoed many times',
        (tester) async {
      final out = await pumpEcho(tester);
      final area = tester.getRect(find.byType(ColorPickerArea));
      final start = area.center;
      await tester.tapAt(start);
      final first = out.last;
      for (var i = 0; i < 30; i++) {
        await tester.tapAt(start);
        await tester.pump();
      }
      expect(out.last, first);
    });

    testWidgets('pickerHsvColor wins over pickerColor', (tester) async {
      await pumpPicker(
          tester,
          ColorPicker(
            pickerColor: const Color(0xFF000000),
            pickerHsvColor: const HSVColor.fromAHSV(1, 120, 0.5, 0),
            onColorChanged: (_) {},
          ));
      expect(sliderValue(tester, 'Hue'), 120);
    });
  });

  group('hex input', () {
    testWidgets('typing a valid hex updates the color', (tester) async {
      final out = await pumpEcho(tester);
      await tester.enterText(find.byType(TextField), '#80AABBCC');
      await tester.pump();
      expect(out.last, const Color(0x80AABBCC));
      expect(sliderValue(tester, 'Alpha'), closeTo(0x80 / 255, 1e-9));
    });

    testWidgets('short, lowercase and 0x forms are accepted', (tester) async {
      final out = await pumpEcho(tester);
      await tester.enterText(find.byType(TextField), '#abc');
      await tester.pump();
      expect(out.last, const Color(0xFFAABBCC));
      // The user's text is kept, not rewritten while typing.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '#abc');
      await tester.enterText(find.byType(TextField), '0x80112233');
      await tester.pump();
      expect(out.last, const Color(0x80112233));
    });

    testWidgets('invalid or partial input does not emit', (tester) async {
      final out = await pumpEcho(tester);
      await tester.enterText(find.byType(TextField), '#12');
      await tester.enterText(find.byType(TextField), '#12345');
      await tester.pump();
      expect(out, isEmpty);
    });

    testWidgets('the cursor stays where the user typed', (tester) async {
      final out = await pumpEcho(tester, enableAlpha: false);
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '#3366CC',
        selection: TextSelection.collapsed(offset: 7),
      ));
      await tester.pump();
      // Type "9" at offset 3 (after "#33").
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '#33966CC',
        selection: TextSelection.collapsed(offset: 4),
      ));
      await tester.pump();
      // Replace the old digit (in lowercase) so the value is valid again.
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '#3396cc',
        selection: TextSelection.collapsed(offset: 4),
      ));
      await tester.pump();
      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller!;
      // Neither re-cased nor re-formatted while typing, cursor untouched.
      expect(controller.text, '#3396cc');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(out.last, const Color(0xFF3396CC));
    });

    testWidgets('invalid characters are filtered without moving the cursor',
        (tester) async {
      await pumpEcho(tester, enableAlpha: false);
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: '#33z66CC',
        selection: TextSelection.collapsed(offset: 4),
      ));
      await tester.pump();
      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, '#3366CC');
      expect(controller.selection, const TextSelection.collapsed(offset: 3));
    });

    testWidgets('alpha is written first, matching the parser', (tester) async {
      await pumpEcho(tester, initial: const Color(0x803366CC));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '#803366CC');
    });

    testWidgets('CSS style #RRGGBBAA with hexFormat.rrggbbaa', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          ColorPicker(
            pickerColor: const Color(0xFF3366CC),
            onColorChanged: out.add,
            hexInputBar: true,
            hexFormat: HexFormat.rrggbbaa,
          ));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '#3366CCFF');
      await tester.enterText(find.byType(TextField), '#11223380');
      expect(out.last, const Color(0x80112233));
    });

    testWidgets('dragging updates the hex text', (tester) async {
      final out = await pumpEcho(tester);
      final rect = tester.getRect(sliderNamed('Alpha'));
      await tester.dragFrom(rect.center, Offset(-rect.width, 0));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          colorToHex(out.last, format: HexFormat.aarrggbb));
    });

    testWidgets('an external hexInputController drives the picker',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final out = <Color>[];
      await pumpPicker(
          tester,
          ColorPicker(
            pickerColor: const Color(0xFF3366CC),
            onColorChanged: out.add,
            hexInputController: controller,
          ));
      expect(controller.text, '#FF3366CC');
      controller.text = '#00FF00';
      await tester.pump();
      expect(out.last, const Color(0xFF00FF00));
      expect(sliderValue(tester, 'Hue'), closeTo(120, 1e-9));
    });
  });

  group('extras', () {
    testWidgets('labels show the chosen color model', (tester) async {
      await pumpPicker(
          tester,
          ColorPicker(
            pickerColor: const Color(0xFF3366CC),
            onColorChanged: (_) {},
            labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
          ));
      expect(find.text('#FF3366CC'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<ColorLabelType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RGB').last);
      await tester.pumpAndSettle();
      expect(find.text('51'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);
      expect(find.text('204'), findsOneWidget);
    });

    testWidgets('contrast badge against a reference color', (tester) async {
      await pumpEcho(tester,
          initial: const Color(0xFF000000),
          contrastReference: const Color(0xFFFFFFFF));
      expect(find.text('21.00:1'), findsOneWidget);
      expect(find.text('AAA'), findsOneWidget);
      hostKey.currentState!.set(const Color(0xFF777777));
      await tester.pump();
      expect(find.text('4.48:1'), findsOneWidget);
      expect(find.text('AA Large'), findsOneWidget);
    });

    testWidgets('eyedropper callback sets the color', (tester) async {
      final out = await pumpEcho(tester,
          onEyeDropper: () async => const Color(0xFF00FF00));
      await tester.tap(find.byTooltip('Pick a color from the screen'));
      await tester.pump();
      expect(out.last, const Color(0xFF00FF00));
      expect(sliderValue(tester, 'Hue'), closeTo(120, 1e-9));
    });

    testWidgets('eyedropper cancel (null) changes nothing', (tester) async {
      final out = await pumpEcho(tester, onEyeDropper: () async => null);
      await tester.tap(find.byTooltip('Pick a color from the screen'));
      await tester.pump();
      expect(out, isEmpty);
    });

    testWidgets('color history adds and restores colors', (tester) async {
      var history = <Color>[const Color(0xFFFF0000)];
      final out = <Color>[];
      await pumpPicker(
          tester,
          StatefulBuilder(
              builder: (context, setState) => ColorPicker(
                    pickerColor: const Color(0xFF3366CC),
                    onColorChanged: out.add,
                    colorHistory: history,
                    onHistoryChanged: (h) => setState(() => history = h),
                  )));
      await tester.tap(find.byTooltip('Add to history'));
      await tester.pump();
      expect(history, [const Color(0xFFFF0000), const Color(0xFF3366CC)]);
      await tester.tap(find.bySemanticsLabel('History color #FFFF0000'));
      await tester.pump();
      expect(out.last, const Color(0xFFFF0000));
    });

    testWidgets('keyboard moves the palette pointer', (tester) async {
      final out = await pumpEcho(tester, initial: const Color(0xFF808080));
      final node = tester
          .widget<Focus>(find
              .descendant(
                  of: find.byType(ColorPickerArea),
                  matching: find.byType(Focus))
              .first)
          .focusNode!;
      node.requestFocus();
      await tester.pump();
      final before = colorToHsv(hostKey.currentState!.color);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      final after = colorToHsv(out.last);
      expect(after.saturation, greaterThan(before.saturation));
      expect(after.value, greaterThan(before.value));
    });

    testWidgets('renders in RTL without overflow', (tester) async {
      final out = await pumpEcho(tester,
          direction: TextDirection.rtl, hexInputBar: true);
      expect(tester.takeException(), isNull);
      // Sliders are mirrored: the right edge is the minimum.
      final rect = tester.getRect(sliderNamed('Alpha'));
      await tester.tapAt(rect.centerRight - const Offset(1, 0));
      expect(out.last.alpha8, lessThan(5));
    });

    testWidgets('dark Material 3 theme builds', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: const Color(0xFF3366CC),
              onColorChanged: (_) {},
              hexInputBar: true,
              contrastReference: Colors.white,
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
