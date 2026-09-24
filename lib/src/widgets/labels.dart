import 'package:flutter/material.dart';

import '../color_math.dart';
import '../contrast.dart';
import '../hex.dart';
import 'common.dart';

/// Which values a [ColorPickerLabel] shows.
enum ColorLabelType {
  /// `#AARRGGBB` (or `#RRGGBB` without alpha).
  hex,

  /// Red, green, blue in `0..255`.
  rgb,

  /// Hue in degrees, saturation and value in percent.
  hsv,

  /// Hue in degrees, saturation and lightness in percent.
  hsl;

  /// Display name, for example `RGB`.
  String get label => switch (this) {
        hex => 'HEX',
        rgb => 'RGB',
        hsv => 'HSV',
        hsl => 'HSL',
      };
}

/// Shows the current color as numbers, with a menu to switch between
/// [colorLabelTypes].
class ColorPickerLabel extends StatefulWidget {
  /// Creates a label.
  const ColorPickerLabel(
    this.hsvColor, {
    super.key,
    this.enableAlpha = true,
    this.colorLabelTypes = const [
      ColorLabelType.rgb,
      ColorLabelType.hsv,
      ColorLabelType.hsl
    ],
    this.textStyle,
  });

  /// The color to describe.
  final HSVColor hsvColor;

  /// Whether to include alpha.
  final bool enableAlpha;

  /// Label types the user can switch between. Must not be empty.
  final List<ColorLabelType> colorLabelTypes;

  /// Style of the numbers. Defaults to the theme's `bodyLarge`.
  final TextStyle? textStyle;

  @override
  State<ColorPickerLabel> createState() => _ColorPickerLabelState();
}

class _ColorPickerLabelState extends State<ColorPickerLabel> {
  late ColorLabelType _type = widget.colorLabelTypes.first;

  @override
  void didUpdateWidget(ColorPickerLabel old) {
    super.didUpdateWidget(old);
    if (!widget.colorLabelTypes.contains(_type)) {
      _type = widget.colorLabelTypes.first;
    }
  }

  List<(String, String)> _values() {
    final hsv = widget.hsvColor;
    final c = hsvToColor(hsv);
    String pct(double v) => '${(v * 100).round()}%';
    String deg(double v) => '${v.round()}°';
    final alpha = widget.enableAlpha
        ? [('A', pct(hsv.alpha))]
        : const <(String, String)>[];
    switch (_type) {
      case ColorLabelType.hex:
        return [
          (
            'HEX',
            colorToHex(c,
                format:
                    widget.enableAlpha ? HexFormat.aarrggbb : HexFormat.rrggbb)
          )
        ];
      case ColorLabelType.rgb:
        return [
          ('R', '${c.red8}'),
          ('G', '${c.green8}'),
          ('B', '${c.blue8}'),
          ...alpha
        ];
      case ColorLabelType.hsv:
        return [
          ('H', deg(hsv.hue)),
          ('S', pct(hsv.saturation)),
          ('V', pct(hsv.value)),
          ...alpha
        ];
      case ColorLabelType.hsl:
        final hsl = hsvToHsl(hsv);
        return [
          ('H', deg(hsl.hue)),
          ('S', pct(hsl.saturation)),
          ('L', pct(hsl.lightness)),
          ...alpha
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.textStyle ?? theme.textTheme.bodyLarge;
    final head = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        if (widget.colorLabelTypes.length > 1)
          DropdownButton<ColorLabelType>(
            value: _type,
            underline: const SizedBox.shrink(),
            onChanged: (t) => setState(() => _type = t ?? _type),
            items: [
              for (final t in widget.colorLabelTypes)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
          ),
        for (final (name, value) in _values())
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(name, style: head),
            const SizedBox(height: 4),
            Text(value, style: style),
          ]),
      ],
    );
  }
}

/// A round swatch of a color, with a checkerboard behind translucent
/// colors.
class ColorIndicator extends StatelessWidget {
  /// Creates an indicator.
  const ColorIndicator(this.hsvColor,
      {super.key, this.width = 50, this.height = 50});

  /// The color to show.
  final HSVColor hsvColor;

  /// Width of the swatch.
  final double width;

  /// Height of the swatch.
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = hsvToColor(hsvColor);
    return Semantics(
      label: 'Selected color ${colorToHex(c, format: HexFormat.aarrggbb)}',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant, width: 2),
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: const CheckerboardPainter(),
            child: ColoredBox(color: c),
          ),
        ),
      ),
    );
  }
}

/// Shows the WCAG contrast ratio of [color] against [reference] and the
/// conformance level it reaches, for example `4.54:1` and `AA`.
class ContrastBadge extends StatelessWidget {
  /// Creates a contrast badge.
  const ContrastBadge(
      {super.key, required this.color, required this.reference});

  /// The picked color (drawn as text).
  final Color color;

  /// The color it is compared against (drawn as background).
  final Color reference;

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio(color, reference);
    final rating = wcagRating(ratio);
    final theme = Theme.of(context);
    final ratioText = '${ratio.toStringAsFixed(2)}:1';
    return Semantics(
      container: true,
      label: 'Contrast ${ratio.toStringAsFixed(2)} to 1 against '
          '${colorToHex(reference)}, ${rating.label}',
      child: ExcludeSemantics(
        child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: reference.withValues(alpha: 1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text('Aa',
                    style: theme.textTheme.titleMedium?.copyWith(color: color)),
              ),
              Text(ratioText, style: theme.textTheme.bodyLarge),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(rating.label),
                avatar: Icon(
                    rating == WcagRating.fail ? Icons.close : Icons.check,
                    size: 16),
              ),
            ]),
      ),
    );
  }
}
