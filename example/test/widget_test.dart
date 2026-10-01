import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chroma_picker/chroma_picker.dart';
import 'package:chroma_picker_example/main.dart';

void main() {
  testWidgets('every demo tab builds', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DemoApp());
    expect(find.byType(ColorPicker), findsOneWidget);
    for (final tab in [
      'Palettes',
      'SlidePicker',
      'HueRing',
      'Material',
      'Blocks'
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(find.byType(BlockPicker), findsNWidgets(2));
    expect(find.byType(MultipleChoiceBlockPicker), findsOneWidget);
  });
}
