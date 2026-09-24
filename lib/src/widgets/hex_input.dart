import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../color_math.dart';
import '../hex.dart';

/// Keeps only hex digits and one leading `#` (a leading `0x` is dropped),
/// and never lets a hex string grow past 8 digits.
///
/// Valid edits are returned untouched, so the cursor, selection and IME
/// composing region are preserved. When characters are removed the cursor
/// is moved to where it would have been without them.
class HexInputFormatter extends TextInputFormatter {
  /// Creates the formatter.
  const HexInputFormatter();

  static bool _isHex(int c) =>
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x46) ||
      (c >= 0x61 && c <= 0x66);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    var skipPrefix = 0;
    final lead = text.trimLeft();
    if (lead.startsWith('0x') || lead.startsWith('0X')) {
      skipPrefix = text.length - lead.length + 2;
    }
    final kept = StringBuffer();
    // keptBefore[i] = number of kept characters before index i.
    final keptBefore = List<int>.filled(text.length + 1, 0);
    var digits = 0;
    for (var i = 0; i < text.length; i++) {
      keptBefore[i] = kept.length;
      final c = text.codeUnitAt(i);
      final keep =
          i >= skipPrefix && (_isHex(c) || (c == 0x23 && kept.isEmpty));
      if (keep) {
        kept.writeCharCode(c);
        if (c != 0x23) digits++;
      }
    }
    keptBefore[text.length] = kept.length;
    if (digits > 8) return oldValue;
    final result = kept.toString();
    if (result == text) return newValue;
    int map(int offset) =>
        offset < 0 ? offset : keptBefore[offset.clamp(0, text.length)];
    return TextEditingValue(
      text: result,
      selection: newValue.selection.copyWith(
        baseOffset: map(newValue.selection.baseOffset),
        extentOffset: map(newValue.selection.extentOffset),
      ),
    );
  }
}

/// A hex text field bound to a color.
///
/// - Accepts `#RGB`, `#RGBA`/`#ARGB`, `#RRGGBB` and 8-digit input with the
///   alpha position of [format], with or without `#` or `0x`, any case.
/// - Reports a color as soon as the text is valid, without rewriting what
///   the user typed, so the cursor stays put.
/// - Rewrites the text only when the color changes from outside, or when
///   editing is finished (to the canonical form).
class ColorPickerInput extends StatefulWidget {
  /// Creates a hex field.
  const ColorPickerInput(
    this.color,
    this.onColorChanged, {
    super.key,
    this.enableAlpha = true,
    this.format,
    this.controller,
    this.focusNode,
    this.embeddedText = false,
    this.disable = false,
    this.label = 'Hex',
  });

  /// The current color.
  final Color color;

  /// Called when the user enters a valid color.
  final ValueChanged<Color> onColorChanged;

  /// Whether alpha may be typed. When `false`, alpha in the input is
  /// ignored and the field shows `#RRGGBB`.
  final bool enableAlpha;

  /// Display format. Defaults to [HexFormat.aarrggbb] with alpha, else
  /// [HexFormat.rrggbb]. Also decides where alpha is read from in 8-digit
  /// input.
  final HexFormat? format;

  /// Optional controller. The field sets its text to the current color.
  final TextEditingController? controller;

  /// Optional focus node.
  final FocusNode? focusNode;

  /// Show the label inside the field instead of beside it.
  final bool embeddedText;

  /// Make the field read-only.
  final bool disable;

  /// The field label.
  final String label;

  @override
  State<ColorPickerInput> createState() => _ColorPickerInputState();
}

class _ColorPickerInputState extends State<ColorPickerInput> {
  TextEditingController? _own;
  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController());

  HexFormat get _format =>
      widget.format ??
      (widget.enableAlpha ? HexFormat.aarrggbb : HexFormat.rrggbb);

  @override
  void initState() {
    super.initState();
    _syncText(force: _controller.text.isEmpty);
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(ColorPickerInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_onText);
      _controller.addListener(_onText);
      _syncText(force: true);
    } else if (old.color != widget.color ||
        old.format != widget.format ||
        old.enableAlpha != widget.enableAlpha) {
      _syncText();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _own?.dispose();
    super.dispose();
  }

  Color? _parse(String text) => colorFromHex(text,
      enableAlpha: widget.enableAlpha && _format.hasAlpha,
      alphaPosition: _format.alphaPosition);

  Color get _shown => widget.enableAlpha && _format.hasAlpha
      ? widget.color.quantized()
      : widget.color.quantized().withAlpha(255);

  String get _canonical => colorToHex(widget.color, format: _format);

  /// Replaces the text only if it does not already describe the color.
  void _syncText({bool force = false}) {
    final parsed = _parse(_controller.text);
    if (!force && parsed != null && parsed == _shown) return;
    final text = _canonical;
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onText() {
    final c = _parse(_controller.text);
    if (c == null || c == _shown) return;
    widget.onColorChanged(widget.enableAlpha && _format.hasAlpha
        ? c
        : c.withValues(alpha: widget.color.a));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: !widget.disable,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: const [HexInputFormatter()],
      style: theme.textTheme.bodyLarge
          ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.embeddedText ? widget.label : null,
        border: const OutlineInputBorder(),
      ),
      onEditingComplete: () => _syncText(force: true),
      onTapOutside: (_) {
        if (_parse(_controller.text) == null) _syncText(force: true);
      },
    );
    if (widget.embeddedText) return SizedBox(width: 170, child: field);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.label, style: theme.textTheme.bodyLarge),
      const SizedBox(width: 12),
      SizedBox(width: 150, child: field),
    ]);
  }
}
