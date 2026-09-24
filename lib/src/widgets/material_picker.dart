import 'package:flutter/material.dart';

import '../color_math.dart';
import '../contrast.dart';
import '../hex.dart';

class _Swatch {
  const _Swatch(this.name, this.shades, this.primary);
  final String name;
  final List<(String, Color)> shades;
  final Color primary;
}

_Swatch _material(String name, MaterialColor c) => _Swatch(
    name,
    [
      for (final s in const [50, 100, 200, 300, 400, 500, 600, 700, 800, 900])
        ('$s', c[s]!),
    ],
    c);

final List<_Swatch> _swatches = [
  _material('Red', Colors.red),
  _material('Pink', Colors.pink),
  _material('Purple', Colors.purple),
  _material('Deep Purple', Colors.deepPurple),
  _material('Indigo', Colors.indigo),
  _material('Blue', Colors.blue),
  _material('Light Blue', Colors.lightBlue),
  _material('Cyan', Colors.cyan),
  _material('Teal', Colors.teal),
  _material('Green', Colors.green),
  _material('Light Green', Colors.lightGreen),
  _material('Lime', Colors.lime),
  _material('Yellow', Colors.yellow),
  _material('Amber', Colors.amber),
  _material('Orange', Colors.orange),
  _material('Deep Orange', Colors.deepOrange),
  _material('Brown', Colors.brown),
  _material('Grey', Colors.grey),
  _material('Blue Grey', Colors.blueGrey),
  const _Swatch(
      'Black and White',
      [('Black', Color(0xFF000000)), ('White', Color(0xFFFFFFFF))],
      Color(0xFF000000)),
];

/// Picks a Material Design color: first a swatch, then one of its shades.
class MaterialPicker extends StatefulWidget {
  /// Creates a Material picker.
  const MaterialPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.onPrimaryChanged,
    this.enableLabel = false,
  });

  /// The selected color. The swatch containing it is preselected.
  final Color pickerColor;

  /// Called when the user picks a shade.
  final ValueChanged<Color> onColorChanged;

  /// Called when a swatch is chosen, with its [MaterialColor] (black for
  /// the black-and-white group).
  final ValueChanged<Color>? onPrimaryChanged;

  /// Show the shade name and hex value next to each shade.
  final bool enableLabel;

  @override
  State<MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends State<MaterialPicker> {
  late int _swatch = _find(widget.pickerColor);

  int _find(Color c) {
    final q = c.quantized();
    final i =
        _swatches.indexWhere((s) => s.shades.any((e) => e.$2.quantized() == q));
    return i < 0 ? 0 : i;
  }

  @override
  void didUpdateWidget(MaterialPicker old) {
    super.didUpdateWidget(old);
    if (old.pickerColor != widget.pickerColor) {
      final i = _swatches.indexWhere((s) => s.shades
          .any((e) => e.$2.quantized() == widget.pickerColor.quantized()));
      if (i >= 0) _swatch = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = widget.pickerColor.quantized();
    final swatch = _swatches[_swatch];
    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _swatches.length; i++)
                Semantics(
                  button: true,
                  selected: i == _swatch,
                  label: _swatches[i].name,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: _swatches[i].name,
                    child: Material(
                      color: _swatches[i].primary,
                      shape: CircleBorder(
                        side: BorderSide(
                          color: i == _swatch
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: i == _swatch ? 3 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          setState(() => _swatch = i);
                          widget.onPrimaryChanged?.call(_swatches[i].primary);
                        },
                        child: const SizedBox(width: 32, height: 32),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (name, color) in swatch.shades)
            Semantics(
              button: true,
              selected: color.quantized() == selected,
              label: '${swatch.name} $name ${colorToHex(color)}',
              excludeSemantics: true,
              child: Material(
                color: color,
                child: InkWell(
                  onTap: () => widget.onColorChanged(color),
                  child: SizedBox(
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        if (widget.enableLabel) ...[
                          Text(name,
                              style: text.bodyMedium?.copyWith(
                                  color: useWhiteForeground(color)
                                      ? Colors.white
                                      : Colors.black)),
                          const Spacer(),
                          Text(colorToHex(color),
                              style: text.bodyMedium?.copyWith(
                                  color: useWhiteForeground(color)
                                      ? Colors.white
                                      : Colors.black)),
                        ] else
                          const Spacer(),
                        if (color.quantized() == selected)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: Icon(Icons.check,
                                size: 18,
                                color: useWhiteForeground(color)
                                    ? Colors.white
                                    : Colors.black),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
