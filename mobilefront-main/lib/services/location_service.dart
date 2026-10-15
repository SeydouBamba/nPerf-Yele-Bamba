import 'dart:io' show Platform;
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/config.dart';

/// Service de localisation — GPS réel avec fallback IP
class LocationService {
  final logger = Logger();
  late final Dio _dio;
  static const MethodChannel _channel = MethodChannel('com.yele/telephony');

  LocationService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: API_BASE_URL,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  /// Demande la permission GPS et retourne la position réelle.
  /// Retourne null si l'utilisateur refuse ou si le GPS est indisponible.
  Future<Position?> requestGpsPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        logger.w('Service GPS désactivé');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          logger.w('Permission GPS refusée');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        logger.w('Permission GPS refusée définitivement');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      logger.i('📍 GPS: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      logger.e('Erreur GPS: $e');
      return null;
    }
  }

  /// Récupère la localisation basée sur l'IP publique (pour l'accueil)
  Future<LocationData?> getCurrentLocation() async {
    try {
      final response = await _dio.get(
        '/getIP',
        queryParameters: {'isp': 'true'},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = _asJsonMap(response.data);
        final ispInfo = data?['rawIspInfo'];

        if (ispInfo is Map) {
          final loc = (ispInfo['loc'] ?? '').toString().split(',');
          final lat = loc.isNotEmpty ? double.tryParse(loc[0].trim()) : null;
          final lng = loc.length > 1 ? double.tryParse(loc[1].trim()) : null;
          final city = (ispInfo['city'] ?? '').toString();
          final country = (ispInfo['country'] ?? '').toString();
          final operator = _cleanOrg(ispInfo['org']);

          // Rien d'exploitable (backend joignable en local, FAI non résolu) :
          // on renvoie null plutôt que d'inventer une position 0,0 et un
          // opérateur. Le FAI s'affiche alors « — », jamais une fausse valeur.
          final hasPosition = lat != null && lng != null;
          if (hasPosition ||
              operator.isNotEmpty ||
              city.isNotEmpty ||
              country.isNotEmpty) {
            final locationData = LocationData(
              latitude: lat ?? 0.0,
              longitude: lng ?? 0.0,
              city: city.isEmpty ? 'Unknown' : city,
              region: (ispInfo['region'] ?? '').toString(),
              country: country.isEmpty ? 'Unknown' : country,
              countryName: _getCountryName(country),
              operator: operator,
              ip: (ispInfo['ip'] ?? '').toString(),
              timezone: (ispInfo['timezone'] ?? 'UTC').toString(),
              processedString: (data?['processedString'] ?? '').toString(),
            );

            logger.i(
              '🌍 Localisation IP: ${locationData.city}, ${locationData.countryName}',
            );
            return locationData;
          }

          logger.w(
            'ℹ️ /getIP sans information FAI exploitable : ${data?['processedString']}',
          );
        } else {
          logger.w('⚠️ Réponse /getIP inattendue : ${response.data}');
        }
      }
    } on DioException catch (e) {
      logger.e('❌ Erreur localisation IP: ${e.message}');
    } catch (e) {
      logger.e('❌ Erreur inattendue localisation: $e');
    }

    return null;
  }

  /// Récupère le nom de la localisation (ville, pays) depuis les coordonnées IP
  Future<String?> getLocationName(double lat, double lng) async {
    try {
      if (!Platform.isAndroid) return null;
      final address = await _channel.invokeMethod<String>('reverseGeocode', {
        'latitude': lat,
        'longitude': lng,
      });
      return address?.trim().isNotEmpty == true ? address!.trim() : null;
    } on MissingPluginException {
      return null;
    } catch (e) {
      logger.w('Adresse indisponible pour $lat, $lng: $e');
    }
    return null;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<dynamic> requestLocationPermission() async {
    return await requestGpsPosition();
  }

  /// `/getIP` peut répondre en `text/plain` (backend local, proxy mal
  /// configuré) au lieu de `application/json` : Dio livre alors une chaîne.
  /// On normalise les deux formes, sinon `data['rawIspInfo']` lève une
  /// exception et le FAI reste vide sans explication.
  Map? _asJsonMap(dynamic payload) {
    if (payload is Map) return payload;
    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return decoded;
      } catch (_) {
        // Charge utile non JSON : rien à en tirer.
      }
    }
    return null;
  }

  /// « AS25543 ONATEL » → « ONATEL ». Le préfixe AS du FAI n'est retiré que
  /// s'il est présent, pour ne jamais amputer un nom d'opérateur légitime.
  String _cleanOrg(dynamic org) {
    final value = (org ?? '').toString().trim();
    if (value.isEmpty) return '';
    return value.replaceFirst(RegExp(r'^AS\d+\s+'), '').trim();
  }

  String _getCountryName(String countryCode) {
    const countryNames = {
      'US': 'États-Unis',
      'GB': 'Royaume-Uni',
      'FR': 'France',
      'DE': 'Allemagne',
      'IT': 'Italie',
      'ES': 'Espagne',
      'CA': 'Canada',
      'AU': 'Australie',
      'JP': 'Japon',
      'CN': 'Chine',
      'IN': 'Inde',
      'BR': 'Brésil',
      'MX': 'Mexique',
      'SN': 'Sénégal',
      'MA': 'Maroc',
      'NG': 'Nigeria',
      'ZA': 'Afrique du Sud',
      'BF': 'Burkina Faso',
      'CI': "Côte d'Ivoire",
      'ML': 'Mali',
      'NE': 'Niger',
      'TG': 'Togo',
      'BJ': 'Bénin',
      'GH': 'Ghana',
      'KE': 'Kenya',
      'RW': 'Rwanda',
      'UG': 'Ouganda',
    };
    return countryNames[countryCode] ?? countryCode;
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String region;
  final String country;
  final String countryName;
  final String operator;
  final String ip;
  final String timezone;
  final String processedString;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.region,
    required this.country,
    required this.countryName,
    required this.operator,
    required this.ip,
    required this.timezone,
    required this.processedString,
  });

  @override
  String toString() => '$city, $countryName ($ip - $operator)';
}
