import 'package:flutter/material.dart';
import 'package:chroma_picker/chroma_picker.dart';

void main() => runApp(const DemoApp());

/// Demo of every picker in `chroma_picker`.
class DemoApp extends StatefulWidget {
  /// Creates the demo.
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  Color _seed = const Color(0xFF3366CC);
  bool _dark = false;
  bool _rtl = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'chroma_picker demo',
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: _seed,
          brightness: Brightness.dark,
          useMaterial3: true),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('chroma_picker'),
            actions: [
              IconButton(
                tooltip: 'Toggle dark mode',
                icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => setState(() => _dark = !_dark),
              ),
              IconButton(
                tooltip: 'Toggle right-to-left',
                icon: const Icon(Icons.format_textdirection_r_to_l),
                onPressed: () => setState(() => _rtl = !_rtl),
              ),
            ],
            bottom: const TabBar(isScrollable: true, tabs: [
              Tab(text: 'ColorPicker'),
              Tab(text: 'Palettes'),
              Tab(text: 'SlidePicker'),
              Tab(text: 'HueRing'),
              Tab(text: 'Material'),
              Tab(text: 'Blocks'),
            ]),
          ),
          body: TabBarView(children: [
            _FullPickerPage(
                color: _seed, onChanged: (c) => setState(() => _seed = c)),
            const _PalettesPage(),
            _Scroll(
              SlidePicker(
                pickerColor: _seed,
                onColorChanged: (c) => setState(() => _seed = c),
                labelTypes: const [ColorLabelType.hex, ColorLabelType.rgb],
              ),
            ),
            _Scroll(
              HueRingPicker(
                pickerColor: _seed,
                onColorChanged: (c) => setState(() => _seed = c),
                enableAlpha: true,
                hexInputBar: true,
              ),
            ),
            _Scroll(
              MaterialPicker(
                pickerColor: _seed,
                onColorChanged: (c) => setState(() => _seed = c),
                enableLabel: true,
              ),
            ),
            const _BlocksPage(),
          ]),
        ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(child: child),
      );
}

class _FullPickerPage extends StatefulWidget {
  const _FullPickerPage({required this.color, required this.onChanged});
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_FullPickerPage> createState() => _FullPickerPageState();
}

class _FullPickerPageState extends State<_FullPickerPage> {
  List<Color> _history = [];

  /// A stand-in eyedropper: a real app would sample the screen here.
  Future<Color?> _eyeDropper() => showDialog<Color>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Eyedropper (demo)'),
          children: [
            for (final c in const [
              Color(0xFFE91E63),
              Color(0xFF009688),
              Color(0xFFFFC107)
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c),
                child: Text(colorToHex(c), style: TextStyle(color: c)),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _Scroll(
      Column(children: [
        ColorPicker(
          pickerColor: widget.color,
          onColorChanged: widget.onChanged,
          hexInputBar: true,
          labelTypes: ColorLabelType.values,
          pickerAreaBorderRadius: BorderRadius.circular(12),
          colorHistory: _history,
          onHistoryChanged: (h) => setState(() => _history = h),
          contrastReference: Theme.of(context).colorScheme.surface,
          onEyeDropper: _eyeDropper,
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Pick a color'),
              content: SingleChildScrollView(
                child: _DialogPicker(
                    initial: widget.color, onDone: widget.onChanged),
              ),
            ),
          ),
          child: const Text('Open in a dialog'),
        ),
      ]),
    );
  }
}

class _DialogPicker extends StatefulWidget {
  const _DialogPicker({required this.initial, required this.onDone});
  final Color initial;
  final ValueChanged<Color> onDone;

  @override
  State<_DialogPicker> createState() => _DialogPickerState();
}

class _DialogPickerState extends State<_DialogPicker> {
  late Color _color = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ColorPicker(
        pickerColor: _color,
        onColorChanged: (c) => setState(() => _color = c),
        paletteType: PaletteType.hueWheel,
        labelTypes: const [],
        hexInputBar: true,
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () {
          widget.onDone(_color);
          Navigator.pop(context);
        },
        child: const Text('Use this color'),
      ),
    ]);
  }
}

class _PalettesPage extends StatefulWidget {
  const _PalettesPage();

  @override
  State<_PalettesPage> createState() => _PalettesPageState();
}

class _PalettesPageState extends State<_PalettesPage> {
  Color _color = const Color(0xFF8BC34A);
  PaletteType _type = PaletteType.hsl;

  @override
  Widget build(BuildContext context) {
    return _Scroll(Column(children: [
      DropdownButton<PaletteType>(
        value: _type,
        onChanged: (t) => setState(() => _type = t ?? _type),
        items: [
          for (final t in PaletteType.values)
            DropdownMenuItem(value: t, child: Text(t.name)),
        ],
      ),
      const SizedBox(height: 12),
      ColorPicker(
        pickerColor: _color,
        onColorChanged: (c) => setState(() => _color = c),
        paletteType: _type,
        enableAlpha: false,
        displayThumbColor: true,
        labelTypes: const [ColorLabelType.hex, ColorLabelType.hsl],
        hexFormat: HexFormat.rrggbb,
        hexInputBar: true,
      ),
    ]));
  }
}

class _BlocksPage extends StatefulWidget {
  const _BlocksPage();

  @override
  State<_BlocksPage> createState() => _BlocksPageState();
}

class _BlocksPageState extends State<_BlocksPage> {
  Color _one = const Color(0xFF2196F3);
  List<Color> _many = const [Color(0xFFF44336), Color(0xFF4CAF50)];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Scroll(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BlockPicker', style: text.titleMedium),
        const SizedBox(height: 8),
        BlockPicker(
          pickerColor: _one,
          onColorChanged: (c) => setState(() => _one = c),
        ),
        const SizedBox(height: 24),
        Text('MultipleChoiceBlockPicker (${_many.length} selected)',
            style: text.titleMedium),
        const SizedBox(height: 8),
        MultipleChoiceBlockPicker(
          pickerColors: _many,
          onColorsChanged: (c) => setState(() => _many = c),
        ),
        const SizedBox(height: 24),
        Text('Custom palette and layout', style: text.titleMedium),
        const SizedBox(height: 8),
        BlockPicker(
          pickerColor: _one,
          availableColors: const [
            Color(0xFF1B1B1F),
            Color(0xFF5E5CE6),
            Color(0xFF30D158),
            Color(0xFFFF9F0A),
          ],
          onColorChanged: (c) => setState(() => _one = c),
          layoutBuilder: (context, colors, child) => Row(children: [
            for (final c in colors)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: child(c),
              ),
          ]),
        ),
      ],
    ));
  }
}
