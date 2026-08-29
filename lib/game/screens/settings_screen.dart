import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/settings_data.dart';
import '../persistence/settings_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = SettingsStorage();
  SettingsData _settings = const SettingsData();
  final _seedController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await _storage.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = loaded;
      _seedController.text = loaded.rngSeed?.toString() ?? '';
      _loaded = true;
    });
  }

  Future<void> _save(SettingsData next) async {
    setState(() => _settings = next);
    await _storage.save(next);
  }

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12160F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2218),
        title: const Text('Settings'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Camera zoom',
                  style: TextStyle(color: Color(0xFF9AA890)),
                ),
                const SizedBox(height: 8),
                SegmentedButton<CameraZoomPreset>(
                  segments: const [
                    ButtonSegment(
                      value: CameraZoomPreset.close,
                      label: Text('Close'),
                    ),
                    ButtonSegment(
                      value: CameraZoomPreset.normal,
                      label: Text('Normal'),
                    ),
                    ButtonSegment(
                      value: CameraZoomPreset.far,
                      label: Text('Far'),
                    ),
                  ],
                  selected: {_settings.cameraZoom},
                  onSelectionChanged: (value) {
                    _save(_settings.copyWith(cameraZoom: value.first));
                  },
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Debug overlay',
                    style: TextStyle(color: Color(0xFFEDE8D8)),
                  ),
                  subtitle: const Text(
                    'Radii, targets, squad colors, FPS. Press D in-game on desktop.',
                    style: TextStyle(color: Color(0xFF9AA890)),
                  ),
                  value: _settings.showDebug,
                  onChanged: (value) {
                    _save(_settings.copyWith(showDebug: value));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Inspect enemy squad (Windows left click)',
                    style: TextStyle(color: Color(0xFFEDE8D8)),
                  ),
                  subtitle: const Text(
                    'Desktop: left-click an enemy to highlight its squad. Phone: tap an enemy — always on.',
                    style: TextStyle(color: Color(0xFF9AA890)),
                  ),
                  value: _settings.inspectSquadOnClick,
                  onChanged: (value) {
                    _save(_settings.copyWith(inspectSquadOnClick: value));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hunt enemy squad',
                    style: TextStyle(color: Color(0xFFEDE8D8)),
                  ),
                  subtitle: const Text(
                    'Windows: right-click an enemy. Phone: double-tap an enemy. Your army hunts that squad until it is gone.',
                    style: TextStyle(color: Color(0xFF9AA890)),
                  ),
                  value: _settings.focusHuntOnCommand,
                  onChanged: (value) {
                    _save(_settings.copyWith(focusHuntOnCommand: value));
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Debug RNG seed (optional)',
                  style: TextStyle(color: Color(0xFF9AA890)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _seedController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Color(0xFFEDE8D8)),
                  decoration: const InputDecoration(
                    hintText: 'Leave empty for random',
                    hintStyle: TextStyle(color: Color(0xFF6B7464)),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    _save(
                      _settings.copyWith(
                        rngSeed: parsed,
                        clearSeed: value.isEmpty,
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
