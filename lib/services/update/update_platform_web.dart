// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void reloadPage() {
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
