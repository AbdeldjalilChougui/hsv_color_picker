import 'package:flutter/material.dart';

import '../color_math.dart';
import '../contrast.dart';
import '../hex.dart';

/// Builds one block for [color].
typedef PickerItem = Widget Function(Color color);

/// Lays out the blocks; call `child(color)` for each color.
typedef PickerLayoutBuilder = Widget Function(
    BuildContext context, List<Color> colors, PickerItem child);

/// Builds a block. Call `changeColor` when it is activated.
typedef PickerItemBuilder = Widget Function(
    Color color, bool isCurrentColor, void Function() changeColor);

/// The Material 500 shades plus grey and black: the default block palette.
const List<Color> kDefaultBlockColors = [
  Color(0xFFF44336), // red
  Color(0xFFE91E63), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFF673AB7), // deep purple
  Color(0xFF3F51B5), // indigo
  Color(0xFF2196F3), // blue
  Color(0xFF03A9F4), // light blue
  Color(0xFF00BCD4), // cyan
  Color(0xFF009688), // teal
  Color(0xFF4CAF50), // green
  Color(0xFF8BC34A), // light green
  Color(0xFFCDDC39), // lime
  Color(0xFFFFEB3B), // yellow
  Color(0xFFFFC107), // amber
  Color(0xFFFF9800), // orange
  Color(0xFFFF5722), // deep orange
  Color(0xFF795548), // brown
  Color(0xFF9E9E9E), // grey
  Color(0xFF607D8B), // blue grey
  Color(0xFF000000), // black
];

/// The default layout: a wrapping grid of blocks.
Widget defaultBlockLayoutBuilder(
    BuildContext context, List<Color> colors, PickerItem child) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [for (final c in colors) child(c)],
  );
}

/// The default block: a focusable circle with a check mark when selected.
/// Screen readers announce it as a button named by its hex value.
Widget defaultBlockItemBuilder(
    Color color, bool isCurrentColor, void Function() changeColor) {
  return _Block(color: color, selected: isCurrentColor, onTap: changeColor);
}

class _Block extends StatelessWidget {
  const _Block(
      {required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = useWhiteForeground(color) ? Colors.white : Colors.black;
    return Semantics(
      button: true,
      selected: selected,
      label: colorToHex(color, format: HexFormat.aarrggbb),
      excludeSemantics: true,
      child: Material(
        color: color,
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Icon(Icons.check, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

bool _same(Color a, Color b) => a.quantized() == b.quantized();

/// Picks one color from a fixed palette.
class BlockPicker extends StatefulWidget {
  /// Creates a block picker.
  const BlockPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.availableColors = kDefaultBlockColors,
    this.useInShowDialog = true,
    this.layoutBuilder = defaultBlockLayoutBuilder,
    this.itemBuilder = defaultBlockItemBuilder,
  });

  /// The selected color, or `null` for none.
  final Color? pickerColor;

  /// Called when the user picks a block.
  final ValueChanged<Color> onColorChanged;

  /// The palette.
  final List<Color> availableColors;

  /// Kept for source compatibility with `flutter_colorpicker`; has no
  /// effect because blocks no longer steal focus.
  final bool useInShowDialog;

  /// Lays out the blocks.
  final PickerLayoutBuilder layoutBuilder;

  /// Builds each block.
  final PickerItemBuilder itemBuilder;

  @override
  State<BlockPicker> createState() => _BlockPickerState();
}

class _BlockPickerState extends State<BlockPicker> {
  late Color? _current = widget.pickerColor;

  @override
  void didUpdateWidget(BlockPicker old) {
    super.didUpdateWidget(old);
    if (old.pickerColor != widget.pickerColor) _current = widget.pickerColor;
  }

  @override
  Widget build(BuildContext context) {
    return widget.layoutBuilder(
      context,
      widget.availableColors,
      (color) => widget.itemBuilder(
        color,
        _current != null && _same(_current!, color),
        () {
          setState(() => _current = color);
          widget.onColorChanged(color);
        },
      ),
    );
  }
}

/// Picks any number of colors from a fixed palette.
class MultipleChoiceBlockPicker extends StatefulWidget {
  /// Creates a multiple-choice block picker.
  const MultipleChoiceBlockPicker({
    super.key,
    required this.pickerColors,
    required this.onColorsChanged,
    this.availableColors = kDefaultBlockColors,
    this.useInShowDialog = true,
    this.layoutBuilder = defaultBlockLayoutBuilder,
    this.itemBuilder = defaultBlockItemBuilder,
  });

  /// The selected colors.
  final List<Color>? pickerColors;

  /// Called with the new selection, in the order colors were chosen.
  final ValueChanged<List<Color>> onColorsChanged;

  /// The palette.
  final List<Color> availableColors;

  /// Kept for source compatibility with `flutter_colorpicker`; no effect.
  final bool useInShowDialog;

  /// Lays out the blocks.
  final PickerLayoutBuilder layoutBuilder;

  /// Builds each block.
  final PickerItemBuilder itemBuilder;

  @override
  State<MultipleChoiceBlockPicker> createState() =>
      _MultipleChoiceBlockPickerState();
}

class _MultipleChoiceBlockPickerState extends State<MultipleChoiceBlockPicker> {
  late List<Color> _current = [...?widget.pickerColors];

  @override
  void didUpdateWidget(MultipleChoiceBlockPicker old) {
    super.didUpdateWidget(old);
    if (old.pickerColors != widget.pickerColors) {
      _current = [...?widget.pickerColors];
    }
  }

  void _toggle(Color color) {
    setState(() {
      final i = _current.indexWhere((c) => _same(c, color));
      if (i >= 0) {
        _current.removeAt(i);
      } else {
        _current.add(color);
      }
    });
    widget.onColorsChanged(List.unmodifiable(_current));
  }

  @override
  Widget build(BuildContext context) {
    return widget.layoutBuilder(
      context,
      widget.availableColors,
      (color) => widget.itemBuilder(
        color,
        _current.any((c) => _same(c, color)),
        () => _toggle(color),
      ),
    );
  }
}
