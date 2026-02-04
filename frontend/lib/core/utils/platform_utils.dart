import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class PlatformUtils {
  /// Returns true if the app is running on a desktop platform (Windows, macOS, Linux).
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Returns true if the app is running on a mobile platform (Android, iOS).
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Returns true if the screen width is considered "Large/Desktop" (typically > 900px).
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 900;
  }

  /// Returns true if the screen width is considered "Medium" (typically > 600px).
  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }
}
