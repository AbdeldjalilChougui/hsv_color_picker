import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chroma_picker/chroma_picker.dart';

import 'helpers.dart';

void main() {
  group('BlockPicker', () {
    testWidgets('selecting a block reports its color', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          BlockPicker(
            pickerColor: const Color(0xFFFF0000),
            availableColors: const [
              Color(0xFFFF0000),
              Color(0xFF00FF00),
              Color(0xFF0000FF)
            ],
            onColorChanged: out.add,
          ));
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.bySemanticsLabel('#FFFF0000')),
          containsSemantics(isSelected: true, isButton: true));
      await tester.tap(find.bySemanticsLabel('#FF00FF00'));
      await tester.pump();
      expect(out, [const Color(0xFF00FF00)]);
      expect(tester.getSemantics(find.bySemanticsLabel('#FF00FF00')),
          containsSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel('#FFFF0000')),
          containsSemantics(isSelected: false));
      handle.dispose();
    });

    testWidgets('blocks are keyboard operable', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          BlockPicker(
            pickerColor: const Color(0xFFFF0000),
            availableColors: const [Color(0xFFFF0000), Color(0xFF00FF00)],
            onColorChanged: out.add,
          ));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(out, [const Color(0xFF00FF00)]);
    });

    testWidgets('custom layout and item builders', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          BlockPicker(
            pickerColor: const Color(0xFFFF0000),
            availableColors: const [Color(0xFFFF0000), Color(0xFF0000FF)],
            onColorChanged: out.add,
            layoutBuilder: (context, colors, child) =>
                Row(children: [for (final c in colors) child(c)]),
            itemBuilder: (color, selected, changeColor) => TextButton(
              onPressed: changeColor,
              child: Text('${color.blue8}${selected ? '*' : ''}'),
            ),
          ));
      expect(find.text('0*'), findsOneWidget);
      await tester.tap(find.text('255'));
      await tester.pump();
      expect(out, [const Color(0xFF0000FF)]);
      expect(find.text('255*'), findsOneWidget);
    });

    testWidgets('follows external pickerColor changes', (tester) async {
      final key = GlobalKey<EchoHostState>();
      await pumpPicker(
          tester,
          EchoHost(
            key: key,
            initial: const Color(0xFFFF0000),
            builder: (c, on) => BlockPicker(
              pickerColor: c,
              availableColors: const [Color(0xFFFF0000), Color(0xFF00FF00)],
              onColorChanged: on,
            ),
          ));
      final handle = tester.ensureSemantics();
      key.currentState!.set(const Color(0xFF00FF00));
      await tester.pump();
      expect(tester.getSemantics(find.bySemanticsLabel('#FF00FF00')),
          containsSemantics(isSelected: true));
      handle.dispose();
    });
  });

  group('MultipleChoiceBlockPicker', () {
    testWidgets('toggles colors on and off', (tester) async {
      final out = <List<Color>>[];
      await pumpPicker(
          tester,
          MultipleChoiceBlockPicker(
            pickerColors: const [Color(0xFFFF0000)],
            availableColors: const [
              Color(0xFFFF0000),
              Color(0xFF00FF00),
              Color(0xFF0000FF)
            ],
            onColorsChanged: out.add,
          ));
      await tester.tap(find.bySemanticsLabel('#FF0000FF'));
      await tester.pump();
      expect(out.last, [const Color(0xFFFF0000), const Color(0xFF0000FF)]);
      await tester.tap(find.bySemanticsLabel('#FFFF0000'));
      await tester.pump();
      expect(out.last, [const Color(0xFF0000FF)]);
    });
  });

  group('MaterialPicker', () {
    testWidgets('choosing a swatch then a shade', (tester) async {
      final out = <Color>[];
      final primaries = <Color>[];
      await pumpPicker(
          tester,
          MaterialPicker(
            pickerColor: Colors.red,
            onColorChanged: out.add,
            onPrimaryChanged: primaries.add,
            enableLabel: true,
          ));
      await tester.tap(find.bySemanticsLabel('Blue'));
      await tester.pump();
      expect(primaries.last, Colors.blue);
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Blue 700')));
      await tester.pump();
      expect(out.last, Colors.blue.shade700);
      expect(find.text('700'), findsOneWidget);
    });

    testWidgets('preselects the swatch containing pickerColor', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPicker(
          tester,
          MaterialPicker(
              pickerColor: Colors.teal.shade200, onColorChanged: (_) {}));
      expect(tester.getSemantics(find.bySemanticsLabel('Teal')),
          containsSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Teal 200'))),
          containsSemantics(isSelected: true));
      handle.dispose();
    });
  });

  group('SlidePicker', () {
    testWidgets('RGB sliders edit channels and show params', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          SlidePicker(
            pickerColor: const Color(0xFF3366CC),
            onColorChanged: out.add,
          ));
      expect(find.text('51'), findsOneWidget);
      final red = tester.getRect(sliderNamed('Red'));
      await tester.tapAt(red.centerRight - const Offset(1, 0));
      expect(out.last.red8, 255);
      expect(out.last.green8, 0x66);
      expect(out.last.blue8, 0xCC);
    });

    testWidgets('HSV and HSL models', (tester) async {
      for (final (model, labels) in [
        (ColorModel.hsv, ['Hue', 'Saturation', 'Value']),
        (ColorModel.hsl, ['Hue', 'Saturation', 'Lightness']),
      ]) {
        await pumpPicker(
            tester,
            SlidePicker(
              pickerColor: const Color(0xFF3366CC),
              onColorChanged: (_) {},
              colorModel: model,
              enableAlpha: false,
            ));
        for (final l in labels) {
          expect(sliderNamed(l), findsOneWidget, reason: '$model $l');
        }
        expect(sliderNamed('Alpha'), findsNothing);
      }
    });

    testWidgets('external change moves the alpha slider', (tester) async {
      final key = GlobalKey<EchoHostState>();
      await pumpPicker(
          tester,
          EchoHost(
            key: key,
            initial: const Color(0xFF3366CC),
            builder: (c, on) => SlidePicker(pickerColor: c, onColorChanged: on),
          ));
      key.currentState!.set(const Color(0x333366CC));
      await tester.pump();
      expect(sliderValue(tester, 'Alpha'), closeTo(0x33 / 255, 1e-9));
    });
  });

  group('HueRingPicker', () {
    testWidgets('ring is a hue slider with semantics actions', (tester) async {
      final handle = tester.ensureSemantics();
      final out = <Color>[];
      await pumpPicker(
          tester,
          HueRingPicker(
            pickerColor: const Color(0xFFFF0000),
            onColorChanged: out.add,
          ));
      expect(
          tester.getSemantics(find.byType(ColorPickerHueRing)),
          containsSemantics(
              label: 'Hue',
              value: '0°',
              isSlider: true,
              hasIncreaseAction: true,
              hasDecreaseAction: true));
      tester.semantics.increase(find.semantics.byLabel('Hue'));
      await tester.pump();
      expect(colorToHsv(out.last).hue, closeTo(1, 0.6));
      handle.dispose();
    });

    testWidgets('dragging the ring and the square', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          EchoHost(
            initial: const Color(0xFFFF0000),
            onChanged: out.add,
            builder: (c, on) =>
                HueRingPicker(pickerColor: c, onColorChanged: on),
          ));
      final ring = tester.getRect(find.byType(ColorPickerHueRing));
      const stroke = 20.0;
      // Bottom of the ring = 90 degrees (angles grow clockwise).
      await tester.tapAt(ring.bottomCenter - const Offset(0, stroke / 2));
      await tester.pump();
      expect(colorToHsv(out.last).hue, closeTo(90, 2));
      final area = tester.getRect(find.byType(ColorPickerArea));
      await tester.tapAt(area.bottomLeft + const Offset(1, -1));
      expect(colorToHsv(out.last).value, closeTo(0, 0.02));
      // The hue is kept even though the color is now black.
      await tester.pump();
      expect(
          tester
              .widget<ColorPickerHueRing>(find.byType(ColorPickerHueRing))
              .hsvColor
              .hue,
          closeTo(90, 2));
    });

    testWidgets('keyboard adjusts the ring', (tester) async {
      final out = <Color>[];
      await pumpPicker(
          tester,
          HueRingPicker(
              pickerColor: const Color(0xFFFF0000), onColorChanged: out.add));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(colorToHsv(out.last).hue, closeTo(1, 0.6));
    });

    testWidgets('optional alpha slider and hex bar', (tester) async {
      await pumpPicker(
          tester,
          HueRingPicker(
            pickerColor: const Color(0xFFFF0000),
            onColorChanged: (_) {},
            enableAlpha: true,
            hexInputBar: true,
          ));
      expect(sliderNamed('Alpha'), findsOneWidget);
      expect(find.byType(ColorPickerInput), findsOneWidget);
    });
  });
}
