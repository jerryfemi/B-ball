// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'vatar_models.dart';

/// Web implementation of the Lagos Life / Vatar Games SDK bridge.
class VatarPlatformBridge {
  static final VatarPlatformBridge instance = VatarPlatformBridge._internal();
  VatarPlatformBridge._internal();

  bool _isInsideVatar = false;
  VatarSession? _session;

  bool get isSupported => true;
  bool get isInsideVatar => _isInsideVatar;
  VatarSession? get session => _session;
  VatarPlayer? get player => _session?.player;

  dynamic get _vatar {
    try {
      if (js_util.hasProperty(html.window, 'Vatar')) {
        return js_util.getProperty(html.window, 'Vatar');
      }
    } catch (_) {}
    return null;
  }

  /// Initializes the bridge.
  /// Rejects silently if called outside of a Lagos Life frame, falling back to standalone mode.
  Future<VatarSession?> init() async {
    final vatar = _vatar;
    if (vatar == null) {
      debugPrint('[VatarBridge] window.Vatar not found, running in standalone mode.');
      _isInsideVatar = false;
      return null;
    }

    try {
      final initPromise = js_util.callMethod(vatar, 'init', []);
      final res = await js_util.promiseToFuture(initPromise);
      if (res != null) {
        final mode = js_util.getProperty(res, 'mode') as String? ?? 'live';
        final sessionToken = js_util.getProperty(res, 'session') as String?;
        final playerObj = js_util.getProperty(res, 'player');

        VatarPlayer? player;
        if (playerObj != null) {
          final id = js_util.getProperty(playerObj, 'id') as String? ?? '';
          final name = js_util.getProperty(playerObj, 'name') as String? ?? 'Player';
          final avatar = js_util.getProperty(playerObj, 'avatar') as String?;
          player = VatarPlayer(id: id, name: name, avatar: avatar);
        }

        _session = VatarSession(player: player, sessionToken: sessionToken, mode: mode);
        _isInsideVatar = true;
        debugPrint('[VatarBridge] Initialized inside Lagos Life! Player: ${player?.name} ($mode mode)');
        return _session;
      }
    } catch (e) {
      debugPrint('[VatarBridge] Standalone mode (init failed or not in iframe): $e');
      _isInsideVatar = false;
    }
    return null;
  }

  void onPause(VoidCallback callback) {
    final vatar = _vatar;
    if (vatar == null) return;
    try {
      js_util.callMethod(vatar, 'onPause', [js_util.allowInterop(callback)]);
    } catch (e) {
      debugPrint('[VatarBridge] Failed to register onPause: $e');
    }
  }

  void onResume(VoidCallback callback) {
    final vatar = _vatar;
    if (vatar == null) return;
    try {
      js_util.callMethod(vatar, 'onResume', [js_util.allowInterop(callback)]);
    } catch (e) {
      debugPrint('[VatarBridge] Failed to register onResume: $e');
    }
  }

  Future<bool> submitScore(int score) async {
    if (!_isInsideVatar) return false;
    final vatar = _vatar;
    if (vatar == null) return false;

    try {
      final promise = js_util.callMethod(vatar, 'submitScore', [score]);
      await js_util.promiseToFuture(promise);
      debugPrint('[VatarBridge] Score $score posted to Lagos Life leaderboard.');
      return true;
    } catch (e) {
      debugPrint('[VatarBridge] submitScore error (rate limit is 20s): $e');
      return false;
    }
  }

  Future<VatarLeaderboardResult?> getLeaderboard() async {
    if (!_isInsideVatar) return null;
    final vatar = _vatar;
    if (vatar == null) return null;

    try {
      final promise = js_util.callMethod(vatar, 'leaderboard', []);
      final res = await js_util.promiseToFuture(promise);
      if (res == null) return null;

      final entries = <VatarLeaderboardEntry>[];
      final jsEntries = js_util.getProperty(res, 'entries');
      if (jsEntries != null) {
        final length = js_util.getProperty(jsEntries, 'length') as int? ?? 0;
        for (var i = 0; i < length; i++) {
          final entryObj = js_util.callMethod(jsEntries, 'at', [i]) ??
              js_util.getProperty(jsEntries, i.toString());
          if (entryObj != null) {
            final rank =
                (js_util.getProperty(entryObj, 'rank') as num?)?.toInt() ?? (i + 1);
            final label =
                js_util.getProperty(entryObj, 'label') as String? ?? 'Player';
            final score =
                (js_util.getProperty(entryObj, 'score') as num?)?.toInt() ?? 0;
            entries.add(
              VatarLeaderboardEntry(rank: rank, label: label, score: score),
            );
          }
        }
      }

      VatarLeaderboardEntry? me;
      final meObj = js_util.getProperty(res, 'me');
      if (meObj != null) {
        final rank =
            (js_util.getProperty(meObj, 'rank') as num?)?.toInt() ?? 0;
        final label =
            js_util.getProperty(meObj, 'label') as String? ?? 'You';
        final score =
            (js_util.getProperty(meObj, 'score') as num?)?.toInt() ?? 0;
        me = VatarLeaderboardEntry(rank: rank, label: label, score: score);
      }

      return VatarLeaderboardResult(entries: entries, me: me);
    } catch (e) {
      debugPrint('[VatarBridge] leaderboard fetch error: $e');
      return null;
    }
  }

  Future<String?> purchase(String productId) async {
    if (!_isInsideVatar) return null;
    final vatar = _vatar;
    if (vatar == null) return null;

    try {
      final promise = js_util.callMethod(vatar, 'purchase', [productId]);
      final res = await js_util.promiseToFuture(promise);
      if (res != null) {
        return js_util.getProperty(res, 'purchaseId') as String?;
      }
    } catch (e) {
      debugPrint('[VatarBridge] purchase error: $e');
    }
    return null;
  }
}
