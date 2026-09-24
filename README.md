# hsv_color_picker

Maintained HSV, HSL, RGB, hue-ring, Material and block color pickers for Flutter. It is a
clean-room replacement for `flutter_colorpicker` that uses the Flutter 3.27+ `Color` API, has
screen reader and keyboard support, and fixes that package's long-standing hex-input and state bugs.

[![pub package](https://img.shields.io/pub/v/hsv_color_picker.svg)](https://pub.dev/packages/hsv_color_picker)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **`ColorPicker`**: a 2D palette with a channel slider and an alpha slider. It supports 13
  `PaletteType`s (HSV, HSL and RGB squares plus a hue wheel), color history, labels (hex, RGB,
  HSV and HSL), an editable hex field, a WCAG contrast badge and an eyedropper hook.
- **`SlidePicker`** (one slider per RGB, HSV or HSL channel), **`HueRingPicker`**,
  **`MaterialPicker`**, **`BlockPicker`** and **`MultipleChoiceBlockPicker`**.
- **Modern `Color` API.** The package reads colors only through `.r`, `.g`, `.b`, `.a` and
  `toARGB32()`, and a test checks that `lib/` has no deprecated API use. It converts wide-gamut
  colors (Display P3) to sRGB before any HSV, HSL or hex math.
- **No drift.** Every color the pickers emit is quantized to 8-bit sRGB, so the HSV to RGB round
  trip is idempotent. The pickers also keep their own `HSVColor`, so hue and saturation survive
  greys and black, and echoing `onColorChanged` back into `pickerColor` does not make the pointer
  jump.
- **Hex helpers.** `colorFromHex` and `colorToHex` handle `#RGB`, `#RGBA`/`#ARGB`, `#RRGGBB`,
  `#AARRGGBB` and `#RRGGBBAA`. The alpha position is configurable, and the parser accepts an
  optional `#` or `0x`, any letter case and surrounding whitespace.
- **WCAG helpers.** `relativeLuminance`, `contrastRatio`, `wcagRating` (Fail, AA Large, AA, AAA)
  and `useWhiteForeground`.
- **Accessibility.**
  - Every slider, including the hue ring, is a real `Semantics` slider with a label, a value and
    increase and decrease actions.
  - Every control is focusable.
  - Arrow keys, Page Up/Down, Home and End adjust sliders, and arrow keys (with Shift for bigger
    steps) move the palette pointer.
  - Blocks are buttons with a selected state.
- **RTL and Material 3.** Sliders and their arrow keys are mirrored in right-to-left layouts.
  Colors come from the `ColorScheme`: focus rings use `primary` and outlines use
  `outlineVariant`.
- **Gestures.** Drags on the palette and sliders win against a parent `TabBarView`, `PageView`
  or scroll view. `onColorChangeStart` and `onColorChangeEnd` let you save or submit only when
  the user lets go.

## Install

```yaml
dependencies:
  hsv_color_picker: ^0.1.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:hsv_color_picker/hsv_color_picker.dart';

Future<Color?> pickColor(BuildContext context, Color initial) {
  var picked = initial;
  return showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pick a color'),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setState) => ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => setState(() => picked = c),
            hexInputBar: true,
            contrastReference: Colors.white,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, picked),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
```

Other pickers:

```dart
Widget otherPickers(
  Color color,
  ValueChanged<Color> onChanged,
  List<Color> colors,
  ValueChanged<List<Color>> onColorsChanged,
) {
  return Column(children: [
    SlidePicker(
        pickerColor: color,
        onColorChanged: onChanged,
        colorModel: ColorModel.hsl),
    HueRingPicker(
        pickerColor: color, onColorChanged: onChanged, enableAlpha: true),
    MaterialPicker(
        pickerColor: color, onColorChanged: onChanged, enableLabel: true),
    BlockPicker(pickerColor: color, onColorChanged: onChanged),
    MultipleChoiceBlockPicker(
        pickerColors: colors, onColorsChanged: onColorsChanged),
  ]);
}
```

Helpers:

```dart
void helpers() {
  final c = colorFromHex('#3366CC80', alphaPosition: HexAlphaPosition.trailing)!;
  colorToHex(c, format: HexFormat.aarrggbb); // '#803366CC'
  colorToHex(c, format: HexFormat.rrggbbaa); // '#3366CC80'
  contrastRatio(const Color(0xFF767676), Colors.white); // 4.54
  wcagRating(4.54); // WcagRating.aa
  hsvToHsl(colorToHsv(c)); // exact HSV -> HSL, keeps the hue of greys
}
```

Eyedropper: the package has no platform code. You supply a callback that returns the sampled
color, or `null` if the user cancelled:

```dart
Future<Color?> sampleScreenColor() async {
  // Sample the screen with your own platform code or a screenshot.
  return null;
}

Widget pickerWithEyedropper(Color color, ValueChanged<Color> onChanged) =>
    ColorPicker(
      pickerColor: color,
      onColorChanged: onChanged,
      onEyeDropper: sampleScreenColor,
    );
```

The `example/` app shows every picker, with dark mode and RTL toggles.

## Migrating from flutter_colorpicker

Most code only needs a new import:

```dart
// before
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
// after
import 'package:hsv_color_picker/hsv_color_picker.dart';
```

The following names are kept, with the same main parameters:

| Kind | Names |
|---|---|
| Widgets | `ColorPicker`, `SlidePicker`, `HueRingPicker`, `MaterialPicker`, `BlockPicker`, `MultipleChoiceBlockPicker` |
| Building blocks | `ColorPickerArea`, `ColorPickerSlider`, `ColorPickerHueRing`, `ColorPickerLabel`, `ColorPickerInput`, `ColorIndicator` |
| Enums | `PaletteType`, `TrackType`, `ColorLabelType`, `ColorModel` |
| Typedefs | `PickerItem`, `PickerLayoutBuilder`, `PickerItemBuilder` |
| Helpers | `useWhiteForeground`, `hsvToHsl`, `hslToHsv`, `colorFromHex`, `colorToHex`, `String.toColor()`, `Color.toHexString()` |

What changed:

| flutter_colorpicker | hsv_color_picker |
|---|---|
| `colorToHex(c, includeHashSign: false, enableAlpha: true, toUpperCase: true)` returns `AARRGGBB` | `colorToHex(c, format: HexFormat.aarrggbb, includeHash: true, upperCase: true)`. The default format is `HexFormat.rrggbb` and a `#` is included by default. |
| `colorFromHex(s, enableAlpha:)` | Same, plus `alphaPosition:` for CSS-style `#RRGGBBAA`, 4-digit input, `0x` prefixes and whitespace. It returns `null` for invalid input. |
| `Color.toHexString(...)` ignored its arguments (#125) | The arguments are honoured. |
| The hex field showed `#RRGGBBAA` but parsed `#AARRGGBB` (#131) | The field shows and parses the same `hexFormat`. |
| `ColorPicker(showLabel:, labelTextStyle:)` (deprecated) | Pass `labelTypes: []` to hide the label. `labelTextStyle` is still accepted. |
| `ColorPicker(portraitOnly:)`, `HueRingPicker(portraitOnly:)` | Removed. There is one vertical layout, so the hex field is never disabled in landscape (#102). |
| `SlidePicker(sliderTextStyle:, showLabel:, indicatorAlignmentBegin/End:)` | Removed. Text uses the theme. |
| `MaterialPicker(portraitOnly:)` | Removed. |
| `BlockPicker(useInShowDialog:)` | Accepted but has no effect. |
| `onPrimaryChanged` received a `Color` | It receives the swatch's `MaterialColor`. |
| The painters (`HSVWithHueColorPainter`, `TrackPainter`, ...) were public | They are private. Use `ColorPickerArea` and `ColorPickerSlider`. |
| `kValidHexPattern`, `kCompleteValidHexPattern`, `UpperCaseTextFormatter` | Use `colorFromHex` and `HexInputFormatter`. The field does not force upper case while typing, which broke IME input (#100). |

New in this package: `onColorChangeStart`/`onColorChangeEnd` (#103, #118), `hexFormat`,
`contrastReference` and `ContrastBadge`, `onEyeDropper`, `hexInputBar` on `HueRingPicker` (#113),
`PaletteType.rgb` as an alias of `rgbWithBlue`, `ColorSlider`, `HexInputFormatter`,
`hsvFromColor`, `hsvToColor`, `colorToHsl`, `hslToColor`, `Color.quantized()`, `Color.toSrgb()`
and the 8-bit getters `alpha8`, `red8`, `green8` and `blue8`.

### Issues fixed

These `flutter_colorpicker` 1.1.0 issues were reproduced or confirmed, and each fix has a test:

- **Deprecation warnings.** On Flutter 3.35, `flutter analyze` reports 70 `deprecated_member_use`
  hits in its `lib/`: `withOpacity`, `.red`, `.green`, `.blue`, `.alpha`, `.opacity` and
  `.value`. See also #108, #105 and #133. Here, `test/deprecation_test.dart` runs the analyzer
  on `lib/` and requires zero hits.
- **The hex input rejected valid values or lost the cursor.**
  - It wrote alpha last but parsed it first (#131).
  - It reset the controller text on every build, which broke IME composing (#100).
  - It rejected pasted `0x` values, whitespace and 4-digit forms.

  The tests cover the cursor position after an edit, filtering without moving the cursor, short,
  lowercase and `0x` input, and `#RRGGBBAA`.
- **Controls did not follow external color changes.**
  - The hex controller was not updated.
  - Re-deriving HSV from the echoed color reset the hue and saturation of greys and black, so
    the pointer jumped and the hue slider looked stuck (#80, #23, #79).

  The tests change the color from outside and check the alpha slider, the hue slider and the hex
  text. They also echo the output back and check that the hue is kept.
- **Precision drift after repeated HSV and RGB round trips.** The tests run property checks
  over 20,000 random colors, 1,000 chained round trips, and 30 echoed palette taps.

## Limitations

- The palette geometry is not mirrored in RTL: a color space has no reading direction. Sliders
  are mirrored.
- The eyedropper is only a hook. Sampling the screen is up to the app.
- Contrast is computed with WCAG 2.x relative luminance (sRGB threshold 0.04045). APCA (WCAG 3
  draft) is not implemented. Translucent foregrounds are composited over the reference color,
  and the reference color's own alpha is ignored.
- The UI strings (semantic labels, tooltips) are in English and are not localized yet.
- Requires Flutter 3.27 or later, because the `Color.r`/`.g`/`.b`/`.a` and `toARGB32()` API
  does not exist before that.

## License

MIT. See [LICENSE](LICENSE).

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
