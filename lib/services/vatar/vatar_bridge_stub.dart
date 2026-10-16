import 'dart:ui';
import 'vatar_models.dart';

/// Non-web fallback stub for platforms where Lagos Life iframe bridge is unavailable.
class VatarPlatformBridge {
  static final VatarPlatformBridge instance = VatarPlatformBridge._internal();
  VatarPlatformBridge._internal();

  bool get isSupported => false;
  bool get isInsideVatar => false;
  VatarSession? get session => null;
  VatarPlayer? get player => null;

  Future<VatarSession?> init() async => null;
  void onPause(VoidCallback callback) {}
  void onResume(VoidCallback callback) {}
  Future<bool> submitScore(int score) async => false;
  Future<VatarLeaderboardResult?> getLeaderboard() async => null;
}
