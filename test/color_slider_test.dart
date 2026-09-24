import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsv_color_picker/hsv_color_picker.dart';

import 'helpers.dart';

void main() {
  Widget slider(ValueChanged<double> onChanged,
          {double value = 0.5, FocusNode? focusNode}) =>
      SizedBox(
        width: 300,
        child: StatefulBuilder(builder: (context, setState) {
          return ColorSlider(
            value: value,
            semanticLabel: 'Level',
            trackColors: const [Colors.black, Colors.white],
            focusNode: focusNode,
            onChanged: (v) {
              onChanged(v);
              setState(() => value = v);
            },
          );
        }),
      );

  testWidgets('tap and drag change the value', (tester) async {
    final values = <double>[];
    await pumpPicker(tester, slider(values.add));
    final rect = tester.getRect(find.byType(ColorSlider));
    await tester.tapAt(rect.centerLeft + const Offset(1, 0));
    expect(values.last, closeTo(0, 0.01));
    await tester.dragFrom(rect.center, Offset(rect.width, 0));
    expect(values.last, 1);
  });

  testWidgets('drag is mirrored in RTL', (tester) async {
    final values = <double>[];
    await pumpPicker(tester, slider(values.add), direction: TextDirection.rtl);
    final rect = tester.getRect(find.byType(ColorSlider));
    await tester.tapAt(rect.centerLeft + const Offset(1, 0));
    expect(values.last, closeTo(1, 0.01));
    await tester.tapAt(rect.centerRight - const Offset(1, 0));
    expect(values.last, closeTo(0, 0.01));
  });

  testWidgets('is a semantics slider with increase/decrease actions',
      (tester) async {
    final handle = tester.ensureSemantics();
    final values = <double>[];
    await pumpPicker(tester, slider(values.add));
    expect(
      tester.getSemantics(find.byType(ColorSlider)),
      containsSemantics(
        label: 'Level',
        value: '50%',
        increasedValue: '51%',
        decreasedValue: '49%',
        isSlider: true,
        isFocusable: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    tester.semantics.increase(find.semantics.byLabel('Level'));
    await tester.pump();
    expect(values.last, closeTo(0.51, 1e-9));
    tester.semantics.decrease(find.semantics.byLabel('Level'));
    tester.semantics.decrease(find.semantics.byLabel('Level'));
    await tester.pump();
    expect(values.last, closeTo(0.49, 1e-9));
    handle.dispose();
  });

  testWidgets('arrow, page, home and end keys adjust the value',
      (tester) async {
    final values = <double>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpPicker(tester, slider(values.add, focusNode: node));
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(values.last, closeTo(0.51, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(values.last, closeTo(0.52, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(values.last, closeTo(0.50, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    expect(values.last, closeTo(0.60, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    expect(values.last, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    expect(values.last, 0);
  });

  testWidgets('left/right keys are mirrored in RTL', (tester) async {
    final values = <double>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await pumpPicker(tester, slider(values.add, focusNode: node),
        direction: TextDirection.rtl);
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(values.last, closeTo(0.49, 1e-9));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(values.last, closeTo(0.51, 1e-9));
  });

  testWidgets('is reachable with Tab', (tester) async {
    await pumpPicker(tester, slider((_) {}));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus!;
    expect(
        find.descendant(
            of: find.byType(ColorSlider),
            matching: find
                .byWidgetPredicate((w) => w is Focus && w.focusNode == focus)),
        findsOneWidget);
  });

  group('ColorPickerSlider', () {
    testWidgets('each track edits its channel', (tester) async {
      var hsv = const HSVColor.fromAHSV(1, 0, 1, 1);
      for (final (track, label) in [
        (TrackType.hue, 'Hue'),
        (TrackType.alpha, 'Alpha'),
        (TrackType.value, 'Value'),
        (TrackType.green, 'Green'),
        (TrackType.lightness, 'Lightness'),
      ]) {
        HSVColor? out;
        await pumpPicker(
            tester,
            SizedBox(
                width: 300,
                child: ColorPickerSlider(track, hsv, (c) => out = c)));
        final rect = tester.getRect(sliderNamed(label));
        await tester.tapAt(rect.centerLeft + const Offset(1, 0));
        expect(out, isNotNull, reason: label);
        switch (track) {
          case TrackType.hue:
            expect(out!.hue, closeTo(0, 2));
          case TrackType.alpha:
            expect(out!.alpha, closeTo(0, 0.01));
          case TrackType.value:
            expect(out!.value, closeTo(0, 0.01));
          case TrackType.green:
            expect(hsvToColor(out!).green8, lessThan(4));
          case TrackType.lightness:
            expect(hsvToHsl(out!).lightness, closeTo(0, 0.01));
          default:
        }
        hsv = const HSVColor.fromAHSV(1, 0, 1, 1);
      }
    });

    testWidgets('value text is human readable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPicker(
          tester,
          SizedBox(
              width: 300,
              child: Column(children: [
                ColorPickerSlider(TrackType.hue,
                    const HSVColor.fromAHSV(0.5, 210, 1, 1), (_) {}),
                ColorPickerSlider(TrackType.red,
                    const HSVColor.fromAHSV(0.5, 0, 1, 1), (_) {}),
                ColorPickerSlider(TrackType.alpha,
                    const HSVColor.fromAHSV(0.5, 0, 1, 1), (_) {}),
              ])));
      expect(tester.getSemantics(sliderNamed('Hue')),
          containsSemantics(value: '210°', increasedValue: '211°'));
      expect(tester.getSemantics(sliderNamed('Red')),
          containsSemantics(value: '255'));
      expect(tester.getSemantics(sliderNamed('Alpha')),
          containsSemantics(value: '50%'));
      handle.dispose();
    });
  });
}
