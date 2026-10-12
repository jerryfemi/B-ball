/// Telemetry data model capturing 3D basketball trajectory parameters
/// and timestamps for deterministic ghost replay and multiplayer sync.
class RecordedShot {
  /// Milliseconds elapsed from round clock start to shot launch.
  final int timestampMs;

  /// Initial release coordinates in 3D arena meters.
  final double startX;
  final double startY;
  final double startZ;

  /// Initial 3D velocity vector in meters/second.
  final double vx;
  final double vy;
  final double vz;

  /// Physical backspin angular velocity (rad/s).
  final double backspin;

  /// Outcome metadata.
  final bool isMake;
  final bool isSwish;
  final bool isBankShot;
  final int points;

  const RecordedShot({
    required this.timestampMs,
    required this.startX,
    required this.startY,
    required this.startZ,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.backspin,
    this.isMake = false,
    this.isSwish = false,
    this.isBankShot = false,
    this.points = 0,
  });

  RecordedShot copyWith({
    bool? isMake,
    bool? isSwish,
    bool? isBankShot,
    int? points,
  }) {
    return RecordedShot(
      timestampMs: timestampMs,
      startX: startX,
      startY: startY,
      startZ: startZ,
      vx: vx,
      vy: vy,
      vz: vz,
      backspin: backspin,
      isMake: isMake ?? this.isMake,
      isSwish: isSwish ?? this.isSwish,
      isBankShot: isBankShot ?? this.isBankShot,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
    't': timestampMs,
    'x': startX,
    'y': startY,
    'z': startZ,
    'vx': vx,
    'vy': vy,
    'vz': vz,
    'spin': backspin,
    'make': isMake,
    'swish': isSwish,
    'bank': isBankShot,
    'pts': points,
  };

  factory RecordedShot.fromJson(Map<String, dynamic> json) => RecordedShot(
    timestampMs: (json['t'] as num).toInt(),
    startX: (json['x'] as num).toDouble(),
    startY: (json['y'] as num).toDouble(),
    startZ: (json['z'] as num).toDouble(),
    vx: (json['vx'] as num).toDouble(),
    vy: (json['vy'] as num).toDouble(),
    vz: (json['vz'] as num).toDouble(),
    backspin: (json['spin'] as num?)?.toDouble() ?? 14.0,
    isMake: json['make'] as bool? ?? false,
    isSwish: json['swish'] as bool? ?? false,
    isBankShot: json['bank'] as bool? ?? false,
    points: (json['pts'] as num?)?.toInt() ?? 0,
  );
}

/// Complete telemetry dataset for a 60-second shooting round.
class RoundTelemetry {
  final int roundScore;
  final int madeShots;
  final int totalShots;
  final List<RecordedShot> shots;

  const RoundTelemetry({
    required this.roundScore,
    required this.madeShots,
    required this.totalShots,
    required this.shots,
  });

  int get swishCount => shots.where((s) => s.isSwish).length;

  Map<String, dynamic> toJson() => {
    'score': roundScore,
    'made': madeShots,
    'total': totalShots,
    'shots': shots.map((s) => s.toJson()).toList(),
  };

  factory RoundTelemetry.fromJson(Map<String, dynamic> json) => RoundTelemetry(
    roundScore: (json['score'] as num).toInt(),
    madeShots: (json['made'] as num).toInt(),
    totalShots: (json['total'] as num).toInt(),
    shots: (json['shots'] as List<dynamic>)
        .map((e) => RecordedShot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
