import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../color_math.dart';
import 'color_slider.dart';
import 'hex_input.dart';
import 'palette.dart';

/// A hue ring around a saturation/value square, with optional alpha slider
/// and hex field.
class HueRingPicker extends StatefulWidget {
  /// Creates a hue ring picker.
  const HueRingPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.onColorChangeEnd,
    this.colorPickerHeight = 250,
    this.hueRingStrokeWidth = 20,
    this.enableAlpha = false,
    this.displayThumbColor = true,
    this.pickerAreaBorderRadius = BorderRadius.zero,
    this.hexInputBar = false,
  });

  /// The color to show. Changing it from outside updates the controls.
  final Color pickerColor;

  /// Called with every new color.
  final ValueChanged<Color> onColorChanged;

  /// Called when an interaction ends, with the final color.
  final ValueChanged<Color>? onColorChangeEnd;

  /// Diameter of the ring.
  final double colorPickerHeight;

  /// Width of the ring.
  final double hueRingStrokeWidth;

  /// Show an alpha slider.
  final bool enableAlpha;

  /// Fill the ring thumb with the current hue.
  final bool displayThumbColor;

  /// Corner radius of the inner square.
  final BorderRadius pickerAreaBorderRadius;

  /// Show a hex text field.
  final bool hexInputBar;

  @override
  State<HueRingPicker> createState() => _HueRingPickerState();
}

class _HueRingPickerState extends State<HueRingPicker> {
  late HSVColor _hsv = colorToHsv(widget.pickerColor);

  @override
  void didUpdateWidget(HueRingPicker old) {
    super.didUpdateWidget(old);
    _hsv = hsvFromColor(widget.pickerColor, previous: _hsv);
  }

  void _set(HSVColor hsv) {
    if (!widget.enableAlpha) hsv = hsv.withAlpha(1);
    setState(() => _hsv = hsv);
    widget.onColorChanged(hsvToColor(hsv));
  }

  void _end(HSVColor hsv) => widget.onColorChangeEnd?.call(hsvToColor(hsv));

  @override
  Widget build(BuildContext context) {
    final d = widget.colorPickerHeight;
    final inner = (d - 2 * widget.hueRingStrokeWidth) / math.sqrt2 - 12;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: d,
          height: d,
          child: Stack(alignment: Alignment.center, children: [
            Positioned.fill(
              child: ColorPickerHueRing(
                _hsv,
                _set,
                strokeWidth: widget.hueRingStrokeWidth,
                displayThumbColor: widget.displayThumbColor,
                onChangeEnd: _end,
              ),
            ),
            SizedBox(
              width: inner,
              height: inner,
              child: ColorPickerArea(
                _hsv,
                _set,
                PaletteType.hsvWithHue,
                borderRadius: widget.pickerAreaBorderRadius,
                onChangeEnd: _end,
              ),
            ),
          ]),
        ),
        if (widget.enableAlpha)
          SizedBox(
            width: d,
            child: ColorPickerSlider(TrackType.alpha, _hsv, _set,
                displayThumbColor: widget.displayThumbColor, onChangeEnd: _end),
          ),
        if (widget.hexInputBar)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ColorPickerInput(
              hsvToColor(_hsv),
              (c) => _set(hsvFromColor(c, previous: _hsv)),
              enableAlpha: widget.enableAlpha,
            ),
          ),
      ],
    );
  }
}
