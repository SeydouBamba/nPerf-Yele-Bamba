import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AppPreferences {
  static const _boxName = 'yelePreferences';
  static const defaultTestKey = 'defaultTestRoute';
  static const speedUnitKey = 'speedUnit';
  static const backgroundStyleKey = 'backgroundStyle';
  static const useGpsKey = 'useGps';

  static Box<dynamic>? _box;
  static final ValueNotifier<String> backgroundStyle = ValueNotifier<String>(
    'green',
  );
  static final ValueNotifier<String> speedUnit = ValueNotifier<String>('Mb/s');

  static Future<void> initialize() async {
    if (_box?.isOpen ?? false) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    backgroundStyle.value = getString(
      backgroundStyleKey,
      defaultValue: 'green',
    );
    speedUnit.value = getString(speedUnitKey, defaultValue: 'Mb/s');
  }

  static String getString(String key, {required String defaultValue}) =>
      _box?.get(key, defaultValue: defaultValue) as String? ?? defaultValue;

  static bool getBool(String key, {required bool defaultValue}) =>
      _box?.get(key, defaultValue: defaultValue) as bool? ?? defaultValue;

  static Future<void> setString(String key, String value) async {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('AppPreferences must be initialized before use');
    }
    await box.put(key, value);
    if (key == backgroundStyleKey) backgroundStyle.value = value;
    if (key == speedUnitKey) speedUnit.value = value;
  }

  static Future<void> setBool(String key, bool value) async {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('AppPreferences must be initialized before use');
    }
    await box.put(key, value);
  }
}

double displaySpeedValue(double mbps, String unit) =>
    unit == 'MB/s' ? mbps / 8 : mbps;

String formatSpeed(double mbps, String unit, {int decimals = 1}) =>
    '${displaySpeedValue(mbps, unit).toStringAsFixed(decimals)} $unit';
