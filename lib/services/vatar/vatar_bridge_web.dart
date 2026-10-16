import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

import 'vatar_models.dart';

/// Web implementation of the Lagos Life / Vatar Games SDK bridge using modern dart:js_interop.
class VatarPlatformBridge {
  static final VatarPlatformBridge instance = VatarPlatformBridge._internal();
  VatarPlatformBridge._internal();

  bool _isInsideVatar = false;
  VatarSession? _session;

  bool get isSupported => true;
  bool get isInsideVatar => _isInsideVatar;
  VatarSession? get session => _session;
  VatarPlayer? get player => _session?.player;

  JSObject? get _vatar {
    try {
      if (globalContext.hasProperty('Vatar'.toJS).toDart) {
        final val = globalContext['Vatar'];
        if (val != null && val.isA<JSObject>()) {
          return val as JSObject;
        }
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
      final initPromise = vatar.callMethod<JSPromise<JSObject>>('init'.toJS);
      final res = await initPromise.toDart;
      if (res.isA<JSObject>()) {
        final resObj = res;
        final mode = (resObj['mode'] as JSString?)?.toDart ?? 'live';
        final sessionToken = (resObj['session'] as JSString?)?.toDart;
        final playerVal = resObj['player'];

        VatarPlayer? player;
        if (playerVal != null && playerVal.isA<JSObject>()) {
          final playerObj = playerVal as JSObject;
          final id = (playerObj['id'] as JSString?)?.toDart ?? '';
          final name = (playerObj['name'] as JSString?)?.toDart ?? 'Player';
          final avatar = (playerObj['avatar'] as JSString?)?.toDart;
          player = VatarPlayer(id: id, name: name, avatar: avatar);
        }

        _session = VatarSession(player: player, sessionToken: sessionToken, mode: mode);
        _isInsideVatar = true;
        debugPrint('[VatarBridge] Initialized inside Lagos Life! Player: ${player?.name} ($mode mode)');
        return _session;
      }
    } catch (e) {
      debugPrint('[VatarBridge] Standalone mode (init rejected or outside iframe): $e');
      _isInsideVatar = false;
    }
    return null;
  }

  void onPause(VoidCallback callback) {
    final vatar = _vatar;
    if (vatar == null) return;
    try {
      final jsCb = callback.toJS;
      vatar.callMethod<JSAny?>('onPause'.toJS, jsCb);
    } catch (e) {
      debugPrint('[VatarBridge] Failed to register onPause: $e');
    }
  }

  void onResume(VoidCallback callback) {
    final vatar = _vatar;
    if (vatar == null) return;
    try {
      final jsCb = callback.toJS;
      vatar.callMethod<JSAny?>('onResume'.toJS, jsCb);
    } catch (e) {
      debugPrint('[VatarBridge] Failed to register onResume: $e');
    }
  }

  Future<bool> submitScore(int score) async {
    if (!_isInsideVatar) return false;
    final vatar = _vatar;
    if (vatar == null) return false;

    try {
      final promise = vatar.callMethod<JSPromise<JSAny?>>(
        'submitScore'.toJS,
        score.toJS,
      );
      await promise.toDart;
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
      final promise = vatar.callMethod<JSPromise<JSObject>>('leaderboard'.toJS);
      final res = await promise.toDart;
      if (!res.isA<JSObject>()) return null;

      final resObj = res;
      final entries = <VatarLeaderboardEntry>[];
      final jsEntriesVal = resObj['entries'];
      if (jsEntriesVal != null && jsEntriesVal.isA<JSArray>()) {
        final jsArray = jsEntriesVal as JSArray;
        final length = jsArray.length;
        for (var i = 0; i < length; i++) {
          final item = jsArray[i];
          if (item != null && item.isA<JSObject>()) {
            final entryObj = item as JSObject;
            final rank = (entryObj['rank'] as JSNumber?)?.toDartInt ?? (i + 1);
            final label = (entryObj['label'] as JSString?)?.toDart ?? 'Player';
            final score = (entryObj['score'] as JSNumber?)?.toDartInt ?? 0;
            entries.add(VatarLeaderboardEntry(rank: rank, label: label, score: score));
          }
        }
      }

      VatarLeaderboardEntry? me;
      final meVal = resObj['me'];
      if (meVal != null && meVal.isA<JSObject>()) {
        final meObj = meVal as JSObject;
        final rank = (meObj['rank'] as JSNumber?)?.toDartInt ?? 0;
        final label = (meObj['label'] as JSString?)?.toDart ?? 'You';
        final score = (meObj['score'] as JSNumber?)?.toDartInt ?? 0;
        me = VatarLeaderboardEntry(rank: rank, label: label, score: score);
      }

      return VatarLeaderboardResult(entries: entries, me: me);
    } catch (e) {
      debugPrint('[VatarBridge] leaderboard fetch error: $e');
      return null;
    }
  }
}
