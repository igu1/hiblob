import 'package:hiblob/flutter.dart';
import 'package:flutter/material.dart';

void main() => runApp(const HiblobStudioApp());

/// An interactive studio: change the name, expression, backdrop, and motion
/// mode of one large hiblob, with a small gallery underneath.
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
  double? _hue;
  double? _tone;

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
      );

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
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Animated'),
            value: _animated,
            onChanged: (v) => setState(() => _animated = v),
          ),
          _hueSlider(scheme),
          _toneSlider(scheme),
          const SizedBox(height: 20),
          Text('Gallery', style: Theme.of(context).textTheme.titleMedium),
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
