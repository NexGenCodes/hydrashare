import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  factory PermissionService() {
    return _instance;
  }

  PermissionService._internal();

  /// Request all necessary permissions for the app to function properly
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return {};

    Map<Permission, PermissionStatus> statuses = {};

    // 1. Storage Permissions
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        // Android 11+
        if (!await Permission.manageExternalStorage.isGranted) {
          statuses[Permission.manageExternalStorage] = await Permission
              .manageExternalStorage
              .request();
        }
      } else {
        // Android < 11
        if (!await Permission.storage.isGranted) {
          statuses[Permission.storage] = await Permission.storage.request();
        }
      }
    }

    // 2. Location/Nearby (Required for P2P/mDNS on Android)
    // Android 13+ (SDK 33) uses nearbyWifiDevices for Wi-Fi Direct
    // Android 12 and below use Location
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        if (!await Permission.nearbyWifiDevices.isGranted) {
          statuses[Permission.nearbyWifiDevices] = await Permission
              .nearbyWifiDevices
              .request();
        }
      } else {
        if (!await Permission.location.isGranted) {
          statuses[Permission.location] = await Permission.location.request();
        }
      }
    }

    // 3. Notifications (Android 13+)
    if (Platform.isAndroid) {
      if (!await Permission.notification.isGranted) {
        statuses[Permission.notification] = await Permission.notification
            .request();
      }
    }

    return statuses;
  }

  Future<bool> checkAndRequestPermission(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted) {
      return true;
    }
    final result = await permission.request();
    return result.isGranted;
  }
}
