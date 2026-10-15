import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// État réseau à un instant donné.
///
/// Distingue deux notions volontairement séparées :
///  - [connectionType] : par où passe Internet *maintenant* (WiFi ou mobile) ;
///  - [cellularTech] / [simOperator] : la techno et l'opérateur de la **SIM**,
///    lisibles même quand Internet passe par le WiFi.
///
/// [wifiSsid]/[wifiBand] identifient le point d'accès quand le test passe par
/// le WiFi : sans eux, un test WiFi ne permettait pas de savoir *quel* réseau
/// avait été mesuré et la seule information réseau affichée restait celle de
/// la SIM (ISS-03).
class NetworkStatus {
  /// 'WiFi', 'Mobile', 'Ethernet', 'Aucune', 'Web' ou 'Inconnu'.
  final String connectionType;

  /// Nom du point d'accès WiFi connecté. null hors WiFi, ou quand l'OS le
  /// masque (localisation refusée).
  final String? wifiSsid;

  /// Bande radio du WiFi : '2,4 GHz', '5 GHz', '6 GHz' ou null.
  final String? wifiBand;

  /// Localisation système activée ? Android masque le SSID aux applications
  /// tant qu'elle est éteinte ; null si l'OS ne le dit pas.
  final bool? locationEnabled;

  /// Techno radio mobile : '2G'/'3G'/'4G'/'4G+'/'5G', ou null si indisponible.
  final String? cellularTech;

  /// Code brut de l'opérateur rapporté par le modem (« 61310 »), affiché
  /// « (613:10) » comme nPerf. null si indisponible.
  final String? operatorCode;

  /// Nom de l'opérateur SIM (Android). null/n.d. sur iOS 16+ ou sans SIM.
  final String? simOperator;

  /// Emplacement 0-indexé de la SIM utilisée pour les données. null si
  /// indéterminé. Permet d'afficher « SIM 2 » et de lever l'ambiguïté quand
  /// l'appareil porte deux SIM (ISS-02).
  final int? dataSimSlot;

  /// Nombre de SIM actives (0 si aucune / non déterminable).
  final int simCount;

  /// RSRP de la cellule servante, en dBm (négatif). null si indisponible.
  final int? rsrp;

  /// RSRQ de la cellule servante, en dB (négatif). null si indisponible.
  final int? rsrq;

  const NetworkStatus({
    required this.connectionType,
    this.wifiSsid,
    this.wifiBand,
    this.locationEnabled,
    this.cellularTech,
    this.simOperator,
    this.operatorCode,
    this.dataSimSlot,
    this.simCount = 0,
    this.rsrp,
    this.rsrq,
  });

  bool get isWifi => connectionType == 'WiFi';

  /// Badge réseau affiché et stocké : 'WiFi' en WiFi, sinon la techno mobile.
  String get networkBadge =>
      isWifi ? 'WiFi' : (cellularTech ?? connectionType);

  /// Libellé du chemin Internet réellement utilisé (« Wi-Fi », « Mobile », …).
  String get connectionLabel => isWifi ? 'Wi-Fi' : connectionType;

  /// Point d'accès WiFi tel qu'affiché : « Maison · 5 GHz », « Maison », ou,
  /// si l'OS ne livre pas le nom, la raison — la localisation éteinte est la
  /// cause la plus fréquente et elle est actionnable par l'utilisateur.
  String get wifiLabel {
    if (!isWifi) return '—';
    final ssid = wifiSsid;
    if (ssid != null && ssid.isNotEmpty) {
      final band = wifiBand;
      return (band == null || band.isEmpty) ? ssid : '$ssid · $band';
    }
    return locationEnabled == false
        ? 'nom masqué (localisation off)'
        : 'nom indisponible';
  }

  /// Libellé de la SIM data : « SIM 2 » quand l'appareil en porte plusieurs,
  /// sinon null (un seul emplacement ou information indisponible).
  String? get simSlotLabel {
    if (simCount < 2 || dataSimSlot == null) return null;
    return 'SIM ${dataSimSlot! + 1}';
  }

  @override
  String toString() =>
      'NetworkStatus($connectionType, wifi=$wifiSsid/$wifiBand, '
      'loc=$locationEnabled, tech=$cellularTech, sim=$simOperator, '
      'code=$operatorCode, slot=$dataSimSlot, rsrp=$rsrp, rsrq=$rsrq)';
}

/// Service d'information réseau : type de connexion (connectivity_plus) +
/// opérateur SIM et techno radio (canal natif [_channel]).
class NetworkInfoService {
  final logger = Logger();
  final Connectivity _connectivity = Connectivity();

  static const MethodChannel _channel = MethodChannel('com.yele/telephony');

  // Repli MCC/MNC → nom d'opérateur, utilisé uniquement quand le nom natif est
  // vide. Le nom fourni par le système reste la source principale. Limité au
  // Burkina Faso (pays de déploiement) pour éviter des libellés erronés.
  static const Map<String, String> operatorsByMccMnc = {
    '61301': 'Telmob (Onatel)', // MCC 613 = Burkina Faso
    '61302': 'Orange Burkina Faso',
    '61303': 'Telecel Faso',
  };

  /// Récupère l'état réseau complet.
  Future<NetworkStatus> getStatus() async {
    if (kIsWeb) {
      return const NetworkStatus(connectionType: 'Web');
    }

    // mutable : le canal natif peut la préciser juste après (voir ci-dessous).
    var connectionType = await _connectionType();

    String? wifiSsid;
    String? wifiBand;
    bool? locationEnabled;
    String? cellularTech;
    String? simOperator;
    String? operatorCode;
    int? dataSimSlot;
    int simCount = 0;
    int? rsrp;
    int? rsrq;

    // Sur Android, on s'assure d'avoir la permission avant de lire.
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('requestPhonePermission');
      } catch (_) {
        // Permission non demandable : lecture en mode dégradé.
      }
    }

    // ISS-03 : le type de connexion vient du **réseau par défaut** du système
    // (canal natif) ; connectivity_plus ne peut pas désambiguïser WiFi + data
    // mobile allumés simultanément. Le canal natif n'est qu'un complément :
    // sans lui (tests, iOS, VPN), on garde la détection ci-dessus.
    try {
      final conn = await _channel.invokeMapMethod<String, dynamic>('getConnection');
      if (conn != null) {
        final type = (conn['connectionType'] as String?)?.trim();
        if (type != null &&
            const ['WiFi', 'Mobile', 'Ethernet'].contains(type)) {
          connectionType = type;
        }

        wifiSsid = (conn['wifiSsid'] as String?)?.trim();
        if (wifiSsid != null && wifiSsid.isEmpty) wifiSsid = null;
        wifiBand = (conn['wifiBand'] as String?)?.trim();
        if (wifiBand != null && wifiBand.isEmpty) wifiBand = null;
        locationEnabled = conn['locationEnabled'] as bool?;
      }
    } on MissingPluginException {
      // Canal natif absent : la détection Dart suffit.
    } catch (e) {
      logger.w('Lecture connexion échouée: $e');
    }

    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getTelephony');
      if (info != null) {
        cellularTech = (info['cellularTech'] as String?)?.trim();
        if (cellularTech != null && cellularTech.isEmpty) cellularTech = null;

        simOperator = (info['simOperator'] as String?)?.trim();
        if (simOperator == null || simOperator.isEmpty) {
          final mccMnc = (info['mccMnc'] as String?)?.trim();
          simOperator = _operatorFromMccMnc(mccMnc);
        }

        operatorCode = (info['operatorCode'] as String?)?.trim();
        if (operatorCode != null && operatorCode.isEmpty) operatorCode = null;

        // ISS-02 : SIM réellement utilisée pour les données + nombre de SIM.
        dataSimSlot = (info['dataSimSlot'] as num?)?.toInt();
        simCount = (info['simCount'] as num?)?.toInt() ?? 0;

        // ISS-01 : RSRP/RSRQ de la cellule servante (null si indisponible).
        rsrp = (info['rsrp'] as num?)?.toInt();
        rsrq = (info['rsrq'] as num?)?.toInt();
      }
    } on MissingPluginException {
      // Canal natif absent (ex. tests) : on reste sur le type de connexion.
    } catch (e) {
      logger.w('Lecture téléphonie échouée: $e');
    }

    final status = NetworkStatus(
      connectionType: connectionType,
      wifiSsid: wifiSsid,
      wifiBand: wifiBand,
      locationEnabled: locationEnabled,
      cellularTech: cellularTech,
      simOperator: simOperator,
      operatorCode: operatorCode,
      dataSimSlot: dataSimSlot,
      simCount: simCount,
      rsrp: rsrp,
      rsrq: rsrq,
    );
    logger.i('📶 $status');
    return status;
  }

  Future<String> _connectionType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      // connectivity_plus 6.x renvoie une liste ; on prend le lien actif.
      if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
      if (results.contains(ConnectivityResult.mobile)) return 'Mobile';
      if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
      if (results.contains(ConnectivityResult.none)) return 'Aucune';
      return 'Inconnu';
    } catch (e) {
      logger.e('Erreur détection connexion: $e');
      return 'Inconnu';
    }
  }
  String? _operatorFromMccMnc(String? mccMnc) {
    if (mccMnc == null || mccMnc.isEmpty) return null;
    return operatorsByMccMnc[mccMnc];
  }

  // ── Compatibilité : anciens appels ponctuels ────────────────────────────────

  /// Badge réseau (WiFi / 4G / …). Conserve l'ancienne signature.
  Future<String?> getNetworkType() async => (await getStatus()).networkBadge;
}
