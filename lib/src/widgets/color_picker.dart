import 'package:flutter/material.dart';

import '../color_math.dart';
import '../hex.dart';
import 'color_slider.dart';
import 'hex_input.dart';
import 'labels.dart';
import 'palette.dart';

/// Asks the host app for a color picked from the screen (an eyedropper).
///
/// This package has no platform code: the app implements the callback (for
/// example with a screenshot and a magnifier, or a platform API) and returns
/// the color, or `null` if the user cancelled.
typedef EyeDropperCallback = Future<Color?> Function();

/// A full color picker: a 2D palette, a channel slider, an optional alpha
/// slider, color history, numeric labels, a hex field, a WCAG contrast badge
/// and an eyedropper button.
///
/// The picker keeps its own [HSVColor], so hue and saturation are not lost
/// when the color becomes grey or black, and feeding [onColorChanged] back
/// into [pickerColor] does not make the pointer jump.
class ColorPicker extends StatefulWidget {
  /// Creates a color picker.
  const ColorPicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.pickerHsvColor,
    this.onHsvColorChanged,
    this.onColorChangeStart,
    this.onColorChangeEnd,
    this.paletteType = PaletteType.hsvWithHue,
    this.enableAlpha = true,
    this.labelTypes = const [
      ColorLabelType.rgb,
      ColorLabelType.hsv,
      ColorLabelType.hsl
    ],
    this.labelTextStyle,
    this.displayThumbColor = false,
    this.colorPickerWidth = 300,
    this.pickerAreaHeightPercent = 1,
    this.pickerAreaBorderRadius = BorderRadius.zero,
    this.hexInputBar = false,
    this.hexInputController,
    this.hexFormat,
    this.colorHistory,
    this.onHistoryChanged,
    this.contrastReference,
    this.onEyeDropper,
  });

  /// The color to show. Changing it from outside updates every control.
  final Color pickerColor;

  /// Called with every new color (8-bit sRGB).
  final ValueChanged<Color> onColorChanged;

  /// Optional exact HSV value; takes precedence over [pickerColor].
  final HSVColor? pickerHsvColor;

  /// Called with the new HSV value, alongside [onColorChanged].
  final ValueChanged<HSVColor>? onHsvColorChanged;

  /// Called when a drag, tap or key press starts changing the color.
  final ValueChanged<Color>? onColorChangeStart;

  /// Called when that interaction ends, with the final color.
  final ValueChanged<Color>? onColorChangeEnd;

  /// The palette shown in the area.
  final PaletteType paletteType;

  /// Show an alpha slider and allow alpha in the hex field.
  final bool enableAlpha;

  /// Label types to show under the sliders. Empty hides the label.
  final List<ColorLabelType> labelTypes;

  /// Text style of the label values.
  final TextStyle? labelTextStyle;

  /// Fill slider thumbs with the color under them.
  final bool displayThumbColor;

  /// Width of the picker.
  final double colorPickerWidth;

  /// Height of the palette as a fraction of [colorPickerWidth].
  final double pickerAreaHeightPercent;

  /// Corner radius of the palette.
  final BorderRadius pickerAreaBorderRadius;

  /// Show the hex text field.
  final bool hexInputBar;

  /// Controller for the hex text. Works with or without [hexInputBar]: set
  /// its text to a hex color to change the picker.
  final TextEditingController? hexInputController;

  /// Hex layout for the field and the controller. Defaults to
  /// [HexFormat.aarrggbb] with alpha, [HexFormat.rrggbb] without.
  final HexFormat? hexFormat;

  /// Colors saved by the user. The history row is shown when this and
  /// [onHistoryChanged] are both set.
  final List<Color>? colorHistory;

  /// Called with the new history when the user saves a color.
  final ValueChanged<List<Color>>? onHistoryChanged;

  /// When set, a badge shows the WCAG contrast of the color against it.
  final Color? contrastReference;

  /// When set, an eyedropper button calls it and applies the result.
  final EyeDropperCallback? onEyeDropper;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late HSVColor _hsv = widget.pickerHsvColor ?? colorToHsv(widget.pickerColor);

  HexFormat get _format =>
      widget.hexFormat ??
      (widget.enableAlpha ? HexFormat.aarrggbb : HexFormat.rrggbb);

  bool get _bindController =>
      widget.hexInputController != null && !widget.hexInputBar;

  @override
  void initState() {
    super.initState();
    if (_bindController) {
      _writeController();
      widget.hexInputController!.addListener(_onControllerText);
    }
  }

  @override
  void didUpdateWidget(ColorPicker old) {
    super.didUpdateWidget(old);
    if (old.hexInputController != widget.hexInputController ||
        old.hexInputBar != widget.hexInputBar) {
      old.hexInputController?.removeListener(_onControllerText);
      if (_bindController) {
        widget.hexInputController!.addListener(_onControllerText);
      }
    }
    final hsv = widget.pickerHsvColor;
    if (hsv != null) {
      if (hsv != old.pickerHsvColor) _hsv = hsv;
    } else {
      _hsv = hsvFromColor(widget.pickerColor, previous: _hsv);
    }
    if (_bindController) _writeController();
  }

  @override
  void dispose() {
    widget.hexInputController?.removeListener(_onControllerText);
    super.dispose();
  }

  Color? _parse(String text) => colorFromHex(text,
      enableAlpha: widget.enableAlpha && _format.hasAlpha,
      alphaPosition: _format.alphaPosition);

  void _writeController() {
    final controller = widget.hexInputController!;
    final current = hsvToColor(_hsv);
    if (_parse(controller.text) == _visible(current)) return;
    final text = colorToHex(current, format: _format);
    controller.value = TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  Color _visible(Color c) =>
      widget.enableAlpha && _format.hasAlpha ? c : c.withAlpha(255);

  void _onControllerText() {
    final c = _parse(widget.hexInputController!.text);
    if (c == null || c == _visible(hsvToColor(_hsv))) return;
    _setColor(c);
  }

  void _setColor(Color c) {
    final keepAlpha = widget.enableAlpha && _format.hasAlpha;
    var hsv = hsvFromColor(c, previous: _hsv);
    if (!keepAlpha) hsv = hsv.withAlpha(_hsv.alpha);
    _setHsv(hsv);
  }

  void _setHsv(HSVColor hsv) {
    if (!widget.enableAlpha && hsv.alpha != 1) hsv = hsv.withAlpha(1);
    setState(() => _hsv = hsv);
    if (_bindController) _writeController();
    widget.onColorChanged(hsvToColor(hsv));
    widget.onHsvColorChanged?.call(hsv);
  }

  void _start(HSVColor hsv) => widget.onColorChangeStart?.call(hsvToColor(hsv));
  void _end(HSVColor hsv) => widget.onColorChangeEnd?.call(hsvToColor(hsv));

  Future<void> _eyeDrop() async {
    final c = await widget.onEyeDropper!();
    if (c == null || !mounted) return;
    _setColor(c);
    widget.onColorChangeEnd?.call(hsvToColor(_hsv));
  }

  Widget _history(BuildContext context) {
    final history = widget.colorHistory!;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          IconButton.outlined(
            tooltip: 'Add to history',
            icon: const Icon(Icons.add),
            onPressed: () =>
                widget.onHistoryChanged!([...history, hsvToColor(_hsv)]),
          ),
          for (final c in history)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Semantics(
                button: true,
                label:
                    'History color ${colorToHex(c, format: HexFormat.aarrggbb)}',
                child: ExcludeSemantics(
                  child: InkResponse(
                    onTap: () {
                      _setColor(c);
                      widget.onColorChangeEnd?.call(hsvToColor(_hsv));
                    },
                    radius: 24,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.colorPickerWidth;
    final sliders = <Widget>[
      ColorPickerSlider(
        widget.paletteType.sliderTrack,
        _hsv,
        _setHsv,
        displayThumbColor: widget.displayThumbColor,
        onChangeStart: _start,
        onChangeEnd: _end,
      ),
      if (widget.enableAlpha)
        ColorPickerSlider(
          TrackType.alpha,
          _hsv,
          _setHsv,
          displayThumbColor: widget.displayThumbColor,
          onChangeStart: _start,
          onChangeEnd: _end,
        ),
    ];
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: width * widget.pickerAreaHeightPercent,
            child: ColorPickerArea(
              _hsv,
              _setHsv,
              widget.paletteType,
              borderRadius: widget.pickerAreaBorderRadius,
              onChangeStart: _start,
              onChangeEnd: _end,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            ColorIndicator(_hsv, width: 40, height: 40),
            const SizedBox(width: 8),
            Expanded(child: Column(children: sliders)),
            if (widget.onEyeDropper != null)
              IconButton(
                tooltip: 'Pick a color from the screen',
                icon: const Icon(Icons.colorize),
                onPressed: _eyeDrop,
              ),
          ]),
          if (widget.colorHistory != null &&
              widget.onHistoryChanged != null) ...[
            const SizedBox(height: 8),
            _history(context),
          ],
          if (widget.labelTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ColorPickerLabel(
              _hsv,
              enableAlpha: widget.enableAlpha,
              colorLabelTypes: widget.labelTypes,
              textStyle: widget.labelTextStyle,
            ),
          ],
          if (widget.hexInputBar) ...[
            const SizedBox(height: 12),
            ColorPickerInput(
              hsvToColor(_hsv),
              (c) {
                _setColor(c);
                widget.onColorChangeEnd?.call(hsvToColor(_hsv));
              },
              enableAlpha: widget.enableAlpha,
              format: widget.hexFormat,
              controller: widget.hexInputController,
            ),
          ],
          if (widget.contrastReference != null) ...[
            const SizedBox(height: 12),
            ContrastBadge(
                color: hsvToColor(_hsv), reference: widget.contrastReference!),
          ],
        ],
      ),
    );
  }
}
