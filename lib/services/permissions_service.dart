import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'debug_logger.dart';

class PermissionsService {
  PermissionsService._();
  static final PermissionsService I = PermissionsService._();

  /// Request microphone permission
  Future<bool> requestMicrophone() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.microphone.request();
      DebugLogger.I.log('[Permissions] Microphone: ${status.isDenied ? "DENIED" : status.isPermanentlyDenied ? "PERMANENTLY_DENIED" : "GRANTED"}');
      return status.isGranted;
    } catch (e) {
      DebugLogger.I.log('[Permissions] Microphone request error: $e');
      return false;
    }
  }

  /// Request camera permission
  Future<bool> requestCamera() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.request();
      DebugLogger.I.log('[Permissions] Camera: ${status.isDenied ? "DENIED" : status.isPermanentlyDenied ? "PERMANENTLY_DENIED" : "GRANTED"}');
      return status.isGranted;
    } catch (e) {
      DebugLogger.I.log('[Permissions] Camera request error: $e');
      return false;
    }
  }

  /// Request notification permission (iOS)
  Future<bool> requestNotification() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      DebugLogger.I.log('[Permissions] Notification: ${status.isDenied ? "DENIED" : status.isPermanentlyDenied ? "PERMANENTLY_DENIED" : "GRANTED"}');
      return status.isGranted;
    } catch (e) {
      DebugLogger.I.log('[Permissions] Notification request error: $e');
      return false;
    }
  }

  /// Request all required permissions
  Future<Map<String, bool>> requestAllPermissions() async {
    if (kIsWeb) {
      return {'microphone': true, 'camera': true, 'notification': true};
    }

    final results = {
      'microphone': await requestMicrophone(),
      'camera': await requestCamera(),
      'notification': await requestNotification(),
    };

    DebugLogger.I.log('[Permissions] All results: $results');
    return results;
  }

  /// Check if permission is permanently denied (need to open Settings)
  Future<bool> isMicrophonePermanentlyDenied() async {
    if (kIsWeb) return false;
    final status = await Permission.microphone.status;
    return status.isPermanentlyDenied;
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    DebugLogger.I.log('[Permissions] Opening app settings...');
    await openAppSettings();
  }

  /// Check and request microphone with fallback to settings
  Future<bool> requestMicrophoneWithFallback() async {
    final status = await requestMicrophone();
    if (status) return true;

    if (await isMicrophonePermanentlyDenied()) {
      DebugLogger.I.log('[Permissions] Microphone permanently denied, opening settings');
      await openAppSettings();
    }
    return false;
  }

  /// Check and request camera with fallback to settings
  Future<bool> requestCameraWithFallback() async {
    final status = await requestCamera();
    if (status) return true;

    final camStatus = await Permission.camera.status;
    if (camStatus.isPermanentlyDenied) {
      DebugLogger.I.log('[Permissions] Camera permanently denied, opening settings');
      await openAppSettings();
    }
    return false;
  }
}
