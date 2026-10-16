// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<void> reloadPage() async {
  try {
    final registrations = await html.window.navigator.serviceWorker
        ?.getRegistrations()
        .timeout(const Duration(milliseconds: 1500));
    if (registrations != null) {
      for (final reg in registrations) {
        await reg.update().timeout(const Duration(milliseconds: 1500));
      }
    }
  } catch (_) {}
  html.window.location.reload();
}

Future<String?> fetchRemoteVersion() async {
  try {
    final response = await html.HttpRequest.getString(
      '/version.json?t=${DateTime.now().millisecondsSinceEpoch}',
    );
    return response;
  } catch (_) {
    return null;
  }
}

bool isDeviceOnline() {
  try {
    return html.window.navigator.onLine ?? true;
  } catch (_) {
    return true;
  }
}
