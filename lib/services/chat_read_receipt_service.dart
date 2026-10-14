import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local read-receipt tracker for match banter and direct friend chats.
///
/// Stores `lastRead` timestamps locally in SharedPreferences to provide immediate,
/// zero-cost read tracking without requiring extra Firestore writes or security rule updates.
class ChatReadReceiptService extends ChangeNotifier {
  static final ChatReadReceiptService instance = ChatReadReceiptService._();
  ChatReadReceiptService._();

  SharedPreferences? _prefs;
  final Map<String, int> _cache = {};
  bool _initialized = false;

  /// Initializes the service and preloads cached timestamps.
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith('last_read_')) {
        _cache[key] = _prefs!.getInt(key) ?? 0;
      }
    }
    _initialized = true;
  }

  String _matchKey(String matchId) => 'last_read_match_$matchId';
  String _friendKey(String friendUid) => 'last_read_friend_$friendUid';

  /// Returns the millisecond timestamp when the match chat was last opened/read.
  int getMatchLastRead(String matchId) {
    final key = _matchKey(matchId);
    if (_cache.containsKey(key)) return _cache[key]!;
    final val = _prefs?.getInt(key) ?? 0;
    _cache[key] = val;
    return val;
  }

  /// Marks a match chat as read up to the current timestamp.
  Future<void> markMatchRead(String matchId, {int? atTimestamp}) async {
    if (matchId.isEmpty) return;
    final now = atTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    final key = _matchKey(matchId);
    final current = _cache[key] ?? 0;
    if (now >= current) {
      _cache[key] = now;
      notifyListeners();

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(key, now);
    }
  }

  /// Returns the millisecond timestamp when direct chat with a friend was last read.
  int getFriendChatLastRead(String friendUid) {
    final key = _friendKey(friendUid);
    if (_cache.containsKey(key)) return _cache[key]!;
    final val = _prefs?.getInt(key) ?? 0;
    _cache[key] = val;
    return val;
  }

  /// Marks direct conversation with a friend as read up to the current timestamp.
  Future<void> markFriendChatRead(String friendUid, {int? atTimestamp}) async {
    if (friendUid.isEmpty) return;
    final now = atTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    final key = _friendKey(friendUid);
    final current = _cache[key] ?? 0;
    if (now >= current) {
      _cache[key] = now;
      notifyListeners();

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt(key, now);
    }
  }
}
