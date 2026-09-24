import 'package:flutter/material.dart';

import '../color_math.dart';
import 'color_slider.dart';
import 'labels.dart';

/// The channels a [SlidePicker] shows.
enum ColorModel {
  /// Red, green, blue.
  rgb,

  /// Hue, saturation, value.
  hsv,

  /// Hue, saturation, lightness.
  hsl;

  /// The slider tracks for this model.
  List<TrackType> get tracks => switch (this) {
        rgb => const [TrackType.red, TrackType.green, TrackType.blue],
        hsv => const [TrackType.hue, TrackType.saturation, TrackType.value],
        hsl => const [
            TrackType.hue,
            TrackType.saturationForHSL,
            TrackType.lightness
          ],
      };
}

/// A picker made of one slider per channel, with a preview on top.
class SlidePicker extends StatefulWidget {
  /// Creates a slide picker.
  const SlidePicker({
    super.key,
    required this.pickerColor,
    required this.onColorChanged,
    this.onColorChangeEnd,
    this.colorModel = ColorModel.rgb,
    this.enableAlpha = true,
    this.sliderSize = const Size(260, 40),
    this.showSliderText = true,
    this.showParams = true,
    this.labelTypes = const [],
    this.showIndicator = true,
    this.indicatorSize = const Size(280, 50),
    this.displayThumbColor = true,
    this.indicatorBorderRadius = BorderRadius.zero,
  });

  /// The color to show. Changing it from outside updates every slider.
  final Color pickerColor;

  /// Called with every new color.
  final ValueChanged<Color> onColorChanged;

  /// Called when an interaction ends, with the final color.
  final ValueChanged<Color>? onColorChangeEnd;

  /// The channels to show.
  final ColorModel colorModel;

  /// Add an alpha slider.
  final bool enableAlpha;

  /// Size of each slider (the width includes the text columns).
  final Size sliderSize;

  /// Show the channel letter before each slider.
  final bool showSliderText;

  /// Show the channel value after each slider.
  final bool showParams;

  /// Label types to show at the bottom. Empty hides the label.
  final List<ColorLabelType> labelTypes;

  /// Show the preview bar.
  final bool showIndicator;

  /// Size of the preview bar.
  final Size indicatorSize;

  /// Fill slider thumbs with the color under them.
  final bool displayThumbColor;

  /// Corner radius of the preview bar.
  final BorderRadius indicatorBorderRadius;

  @override
  State<SlidePicker> createState() => _SlidePickerState();
}

class _SlidePickerState extends State<SlidePicker> {
  late HSVColor _hsv = colorToHsv(widget.pickerColor);

  @override
  void didUpdateWidget(SlidePicker old) {
    super.didUpdateWidget(old);
    _hsv = hsvFromColor(widget.pickerColor, previous: _hsv);
  }

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    widget.onColorChanged(hsvToColor(hsv));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = hsvToColor(_hsv);
    final tracks = [
      ...widget.colorModel.tracks,
      if (widget.enableAlpha) TrackType.alpha
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIndicator)
          Container(
            width: widget.indicatorSize.width,
            height: widget.indicatorSize.height,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: widget.indicatorBorderRadius,
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: widget.indicatorBorderRadius,
              child: ColoredBox(color: color),
            ),
          ),
        for (final t in tracks)
          SizedBox(
            width: widget.sliderSize.width,
            height: widget.sliderSize.height,
            child: Row(children: [
              if (widget.showSliderText)
                SizedBox(
                    width: 20,
                    child: ExcludeSemantics(
                        child: Text(t.shortLabel, style: text.titleSmall))),
              Expanded(
                child: ColorPickerSlider(
                  t,
                  _hsv,
                  _set,
                  displayThumbColor: widget.displayThumbColor,
                  height: widget.sliderSize.height * 0.8,
                  onChangeEnd: widget.onColorChangeEnd == null
                      ? null
                      : (h) => widget.onColorChangeEnd!(hsvToColor(h)),
                ),
              ),
              if (widget.showParams)
                SizedBox(
                  width: 48,
                  child: ExcludeSemantics(
                    child: Text(t.format(t.read(_hsv)),
                        textAlign: TextAlign.end, style: text.bodyMedium),
                  ),
                ),
            ]),
          ),
        if (widget.labelTypes.isNotEmpty)
          ColorPickerLabel(_hsv,
              enableAlpha: widget.enableAlpha,
              colorLabelTypes: widget.labelTypes),
      ],
    );
  }
}
