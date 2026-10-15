import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class PermissionStatusService {
  static const MethodChannel _channel = MethodChannel('com.yele/telephony');

  Future<Map<String, bool?>> readStatuses() async {
    final locationPermission = await Geolocator.checkPermission();
    final locationAllowed =
        locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse;
    final locationEnabled = await Geolocator.isLocationServiceEnabled();

    if (kIsWeb || !Platform.isAndroid) {
      return {
        'location': locationAllowed && locationEnabled,
        'phone': null,
        'notifications': null,
      };
    }

    final native = await _channel.invokeMapMethod<String, bool>(
      'getPermissionStatuses',
    );
    if (native == null) {
      throw StateError('Android n’a pas retourné l’état des permissions');
    }
    return {
      'location': locationAllowed && locationEnabled,
      'phone': native['phone'],
      'notifications': native['notifications'],
    };
  }
}
