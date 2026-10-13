import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'update_platform.dart';

/// Service responsible for polling deployment versions and alerting players
/// when a new game update is available, avoiding stale browser cache issues.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static final ValueNotifier<bool> isUpdateAvailable = ValueNotifier<bool>(false);

  String? _localVersionString;
  Timer? _checkTimer;
  bool _dismissed = false;

  /// Initializes the update monitor and starts background polling.
  Future<void> initialize() async {
    try {
      _localVersionString = await rootBundle.loadString('version.json');
    } catch (_) {
      // In development mode version.json may not exist yet
      _localVersionString = null;
    }

    // Check once shortly after launch
    Future.delayed(const Duration(seconds: 8), checkForUpdates);

    // Poll periodically every 10 minutes
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) => checkForUpdates(),
    );
  }

  /// Polls the server for any newly deployed build.
  Future<void> checkForUpdates() async {
    if (_dismissed) return;
    try {
      final remoteString = await fetchRemoteVersion();
      if (remoteString != null &&
          remoteString.trim().isNotEmpty &&
          _localVersionString != null &&
          _localVersionString!.trim().isNotEmpty) {
        if (remoteString.trim() != _localVersionString!.trim()) {
          debugPrint('[UpdateService] ⚡ New version detected on server!');
          isUpdateAvailable.value = true;
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Check update silent warning: $e');
    }
  }

  /// Dismisses the update banner for the current gameplay session.
  void dismiss() {
    _dismissed = true;
    isUpdateAvailable.value = false;
  }

  /// Reloads the web page to immediately execute the new release.
  void reload() {
    reloadPage();
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}
