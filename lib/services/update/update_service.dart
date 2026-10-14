import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'update_platform.dart';

/// Service responsible for polling deployment versions and alerting players
/// when a new game update is available, avoiding stale browser cache issues.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// The compiled build version of this client release (matches pubspec.yaml).
  static const String currentVersion = '1.0.0';
  static const String currentBuildNumber = '2';

  static final ValueNotifier<bool> isUpdateAvailable =
      ValueNotifier<bool>(false);

  Timer? _checkTimer;
  bool _dismissed = false;

  /// Initializes the update monitor and starts background polling.
  Future<void> initialize() async {
    // Check once shortly after launch (10 seconds)
    Future.delayed(const Duration(seconds: 10), checkForUpdates);

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
          remoteString.trim().startsWith('{')) {
        final Map<String, dynamic> data =
            jsonDecode(remoteString) as Map<String, dynamic>;
        final String remoteBuild = (data['build_number'] ?? '').toString();
        final String remoteVersion = (data['version'] ?? '').toString();

        if (remoteBuild.isNotEmpty && remoteBuild != currentBuildNumber) {
          debugPrint(
            '[UpdateService] ⚡ New version on server: $remoteVersion+$remoteBuild (current: $currentVersion+$currentBuildNumber)',
          );
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
    _dismissed = true;
    isUpdateAvailable.value = false;
    reloadPage();
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}
