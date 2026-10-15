import 'dart:ui';
import 'vatar_bridge_stub.dart'
    if (dart.library.html) 'vatar_bridge_web.dart' as platform;
import 'vatar_models.dart';

export 'vatar_models.dart';

/// Unified cross-platform facade for the Lagos Life / Vatar Games integration.
///
/// Automatically delegates to the Web JS bridge when running inside the
/// Lagos Life in-game browser frame, and safely no-ops on standalone / native platforms.
class VatarBridge {
  static final VatarBridge instance = VatarBridge._internal();
  VatarBridge._internal();

  final _bridge = platform.VatarPlatformBridge.instance;

  /// Whether the host platform supports the Vatar bridge (Web).
  bool get isSupported => _bridge.isSupported;

  /// Whether the game is actively executing inside a Lagos Life in-game phone frame.
  bool get isInsideVatar => _bridge.isInsideVatar;

  /// Active session details and token if initialized inside Lagos Life.
  VatarSession? get session => _bridge.session;

  /// Active player identity provided by the Lagos Life host.
  VatarPlayer? get player => _bridge.player;

  /// Initializes the bridge and fetches player context from Lagos Life.
  Future<VatarSession?> init() => _bridge.init();

  /// Registers a callback when the Lagos Life phone minimizes or is paused.
  void onPause(VoidCallback callback) => _bridge.onPause(callback);

  /// Registers a callback when the Lagos Life phone regains active focus.
  void onResume(VoidCallback callback) => _bridge.onResume(callback);

  /// Submits an integer score to the Lagos Life city-wide leaderboard.
  /// Note: Rate limited to 1 call per 20 seconds by Lagos Life.
  Future<bool> submitScore(int score) => _bridge.submitScore(score);

  /// Fetches the top 50 rankings and player's standing from the city leaderboard.
  Future<VatarLeaderboardResult?> getLeaderboard() => _bridge.getLeaderboard();

  /// Prompts the native Lagos Life payment sheet for real Naira purchases.
  Future<String?> purchase(String productId) => _bridge.purchase(productId);
}
