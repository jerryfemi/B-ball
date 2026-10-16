import 'update_platform_stub.dart'
    if (dart.library.html) 'update_platform_web.dart' as platform;

Future<void> reloadPage() => platform.reloadPage();

Future<String?> fetchRemoteVersion() => platform.fetchRemoteVersion();

bool isDeviceOnline() => platform.isDeviceOnline();
