enum CameraZoomPreset { close, normal, far }

class SettingsData {
  const SettingsData({
    this.cameraZoom = CameraZoomPreset.normal,
    this.showDebug = false,
    this.inspectSquadOnClick = false,
    this.rngSeed,
  });

  final CameraZoomPreset cameraZoom;
  final bool showDebug;
  final bool inspectSquadOnClick;
  final int? rngSeed;

  SettingsData copyWith({
    CameraZoomPreset? cameraZoom,
    bool? showDebug,
    bool? inspectSquadOnClick,
    int? rngSeed,
    bool clearSeed = false,
  }) {
    return SettingsData(
      cameraZoom: cameraZoom ?? this.cameraZoom,
      showDebug: showDebug ?? this.showDebug,
      inspectSquadOnClick: inspectSquadOnClick ?? this.inspectSquadOnClick,
      rngSeed: clearSeed ? null : (rngSeed ?? this.rngSeed),
    );
  }
}
