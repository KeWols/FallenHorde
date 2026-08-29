import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_data.dart';

class SettingsStorage {
  static const _zoomKey = 'fallen_horde_zoom';
  static const _debugKey = 'fallen_horde_debug';
  static const _inspectKey = 'fallen_horde_inspect_squad';
  static const _seedKey = 'fallen_horde_seed';

  Future<SettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final zoomIndex = prefs.getInt(_zoomKey) ?? CameraZoomPreset.normal.index;
    final zoom = CameraZoomPreset.values[zoomIndex.clamp(
      0,
      CameraZoomPreset.values.length - 1,
    )];
    final seed = prefs.containsKey(_seedKey) ? prefs.getInt(_seedKey) : null;
    return SettingsData(
      cameraZoom: zoom,
      showDebug: prefs.getBool(_debugKey) ?? false,
      inspectSquadOnClick: prefs.getBool(_inspectKey) ?? false,
      rngSeed: seed,
    );
  }

  Future<void> save(SettingsData settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_zoomKey, settings.cameraZoom.index);
    await prefs.setBool(_debugKey, settings.showDebug);
    await prefs.setBool(_inspectKey, settings.inspectSquadOnClick);
    if (settings.rngSeed == null) {
      await prefs.remove(_seedKey);
    } else {
      await prefs.setInt(_seedKey, settings.rngSeed!);
    }
  }
}
