import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hsv_color_picker/hsv_color_picker.dart';

/// Pumps [child] in a Material 3 app with a tall surface.
Future<void> pumpPicker(
  WidgetTester tester,
  Widget child, {
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: Directionality(
        textDirection: direction,
        child: Center(child: SingleChildScrollView(child: child)),
      ),
    ),
  ));
}

/// Finds the [ColorSlider] with the given semantic label.
Finder sliderNamed(String label) =>
    find.byWidgetPredicate((w) => w is ColorSlider && w.semanticLabel == label,
        description: 'ColorSlider "$label"');

/// The current value of the [ColorSlider] named [label].
double sliderValue(WidgetTester tester, String label) =>
    tester.widget<ColorSlider>(sliderNamed(label)).value;

/// A parent that feeds the picker's output back into it, like a typical
/// `setState` app does.
class EchoHost extends StatefulWidget {
  const EchoHost({
    super.key,
    required this.initial,
    required this.builder,
    this.onChanged,
  });

  final Color initial;
  final Widget Function(Color color, ValueChanged<Color> onChanged) builder;
  final ValueChanged<Color>? onChanged;

  @override
  State<EchoHost> createState() => EchoHostState();
}

/// State of [EchoHost]; tests call [set] to change the color externally.
class EchoHostState extends State<EchoHost> {
  late Color color = widget.initial;

  /// Changes the color from outside the picker.
  void set(Color c) => setState(() => color = c);

  @override
  Widget build(BuildContext context) => widget.builder(color, (c) {
        widget.onChanged?.call(c);
        setState(() => color = c);
      });
}
