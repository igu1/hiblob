import 'package:hiblob/flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const HiblobStudioApp());

/// An interactive studio: change the name, expression, backdrop, accessories,
/// shape pin, and motion mode of one large hiblob — with a hover gallery
/// underneath and SVG export built in.
class HiblobStudioApp extends StatelessWidget {
  const HiblobStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hiblob Studio',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF7C6FF0)),
      home: const StudioPage(),
    );
  }
}

/// Accessory selection: leave a key unpinned (`auto`), force it on, or off.
enum AccessoryChoice { auto, on, off }

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  String _name = 'ada@example.com';
  Expression _expression = idle;
  Backdrop _backdrop = Backdrop.squircle;
  bool _animated = true;
  bool _mouth = true;
  double? _hue;
  double? _tone;
  String? _shape;
  final Map<String, AccessoryChoice> _accessories = {
    for (final key in AccessoryKeys.all) key: AccessoryChoice.auto
  };

  late final TextEditingController _nameController =
      TextEditingController(text: _name)
        ..addListener(() {
          if (_nameController.text != _name) {
            setState(() => _name = _nameController.text);
          }
        });

  HiblobOptions get _options => HiblobOptions(
        background: _backdrop,
        expression: _expression,
        hue: _hue,
        tone: _tone,
        mouth: _mouth,
        accessories: {
          for (final e in _accessories.entries)
            if (e.value != AccessoryChoice.auto)
              e.key: e.value == AccessoryChoice.on ? 1.0 : 0.0,
        },
        traits: {
          if (_shape != null) 'shape': _shapeBandValue(_shape!),
        },
      );

  /// Shape traits are bands: a pin anywhere inside a shape's band selects it.
  static double _shapeBandValue(String shape) =>
      (shapeBands[shape]!.$1 + shapeBands[shape]!.$2) / 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hiblob Studio')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: _animated
                ? AnimatedHiblob(
                    name: _name,
                    size: 160,
                    options: _options,
                    animation: HiblobAnimation.always,
                    semanticLabel: 'Animated hiblob of $_name',
                  )
                : Hiblob(
                    name: _name,
                    size: 160,
                    options: _options,
                    semanticLabel: 'Hiblob of $_name',
                  ),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            controller: _nameController,
          ),
          const SizedBox(height: 12),
          _section(context, 'Expression — `thinking` seesaws, `mad` tremors'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in expressions)
                ChoiceChip(
                  label: Text(e.id),
                  selected: _expression == e,
                  onSelected: (_) => setState(() => _expression = e),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _section(context, 'Shape'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final shape in ['auto', ...shapeBands.keys])
                ChoiceChip(
                  label: Text(shape),
                  selected: _shape == (shape == 'auto' ? null : shape),
                  onSelected: (_) =>
                      setState(() => _shape = shape == 'auto' ? null : shape),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _section(context, 'Accessories'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final key in AccessoryKeys.all) _accessoryChip(context, key),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<Backdrop>(
            segments: const [
              ButtonSegment(value: Backdrop.none, label: Text('None')),
              ButtonSegment(value: Backdrop.squircle, label: Text('Squircle')),
              ButtonSegment(value: Backdrop.circle, label: Text('Circle')),
              ButtonSegment(value: Backdrop.square, label: Text('Square')),
            ],
            selected: {_backdrop},
            onSelectionChanged: (s) => setState(() => _backdrop = s.first),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Animated'),
            value: _animated,
            onChanged: (v) => setState(() => _animated = v),
          ),
          SwitchListTile(
            title: const Text('Mouth'),
            value: _mouth,
            onChanged: (v) => setState(() => _mouth = v),
          ),
          _hueSlider(scheme),
          _toneSlider(scheme),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.code),
            label: const Text('Copy SVG'),
            onPressed: _copySvg,
          ),
          const SizedBox(height: 20),
          _section(context, 'Gallery (hover each to see ambient motion)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in [
                'ada@example.com',
                'grace',
                'linus',
                'margaret',
                'edsgar',
                'katherine',
              ])
                AnimatedHiblob(
                  name: name,
                  size: 64,
                  animation: HiblobAnimation.hover,
                  options: HiblobOptions(background: _backdrop),
                  semanticLabel: 'Hiblob of $name',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleSmall);

  /// Cycles auto → on → off → auto, labeled accordingly.
  Widget _accessoryChip(BuildContext context, String key) {
    final choice = _accessories[key]!;
    final scheme = Theme.of(context).colorScheme;
    return InputChip(
      label: Text(
        switch (choice) {
          AccessoryChoice.auto => '$key · auto',
          AccessoryChoice.on => '$key · on',
          AccessoryChoice.off => '$key · off',
        },
        style: TextStyle(
          fontWeight: choice == AccessoryChoice.auto
              ? FontWeight.w400
              : FontWeight.w600,
          color: choice == AccessoryChoice.auto ? null : scheme.primary,
        ),
      ),
      onPressed: () => setState(() {
        _accessories[key] = AccessoryChoice
            .values[(choice.index + 1) % AccessoryChoice.values.length];
      }),
    );
  }

  void _copySvg() {
    final svg = svgOf(resolve(_name, options: _options));
    Clipboard.setData(ClipboardData(text: svg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG for "$_name" copied to the clipboard')),
    );
  }

  Widget _hueSlider(ColorScheme scheme) => Row(
        children: [
          const SizedBox(
              width: 64,
              child:
                  Text('Hue', style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Slider(
              value: _hue ?? 0,
              max: 359,
              onChanged: (v) => setState(() => _hue = v),
            ),
          ),
          IconButton(
            tooltip: 'Name-driven hue',
            onPressed: () => setState(() => _hue = null),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      );

  Widget _toneSlider(ColorScheme scheme) => Row(
        children: [
          const SizedBox(
              width: 64,
              child:
                  Text('Tone', style: TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: Slider(
              value: _tone ?? 0,
              max: 0.99,
              onChanged: (v) => setState(() => _tone = v),
            ),
          ),
          IconButton(
            tooltip: 'Name-driven tone',
            onPressed: () => setState(() => _tone = null),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      );
}
