import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/speed_test_result.dart';
import '../services/app_preferences.dart';
import '../services/local_storage_service.dart';
import '../services/quality_score.dart';
import '../theme/yele_theme.dart';
import '../widgets/yele_scaffold.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = LocalStorageService();
  final _mapController = MapController();
  final _date = DateFormat('dd/MM/yy');
  final _time = DateFormat('HH:mm:ss');
  String _speedUnit = AppPreferences.speedUnit.value;

  List<SpeedTestResult> _all = [];
  int _tab = 0; // 0 = Test complet, 1 = Speed test
  String? _expandedId;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    AppPreferences.speedUnit.addListener(_onSpeedUnitChanged);
    _all = _storage.getResultsSorted();
  }

  @override
  void dispose() {
    AppPreferences.speedUnit.removeListener(_onSpeedUnitChanged);
    super.dispose();
  }

  void _onSpeedUnitChanged() {
    if (mounted) {
      setState(() => _speedUnit = AppPreferences.speedUnit.value);
    }
  }

  bool _isComplet(SpeedTestResult r) => r.hasStreamingTest || r.hasBrowsingTest;

  /// Note de qualité /100 dérivée des mesures réelles (transparente) :
  /// 60 pts max pour le download, 20 pour l'upload, 20 pour la latence.
  int _score(SpeedTestResult r) {
    return QualityScore.calculate(
      downloadMbps: r.downloadSpeed,
      uploadMbps: r.uploadSpeed,
      latencyMs: r.ping,
    );
  }

  List<SpeedTestResult> get _filtered =>
      _all.where((r) => _tab == 0 ? _isComplet(r) : !_isComplet(r)).toList();

  @override
  Widget build(BuildContext context) {
    final pts = _all
        .where((r) => (r.latitude ?? 0) != 0 && (r.longitude ?? 0) != 0)
        .toList();
    final list = _filtered;
    return YeleScaffold(
      title: 'Historique',
      route: '/history',
      body: Column(
        children: [
          SizedBox(height: 200, child: _map(pts)),
          _tabs(),
          _header(),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun test pour cet onglet.',
                      style: TextStyle(color: Color(0xFF6B7689)),
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => _row(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _map(List<SpeedTestResult> pts) {
    final center = pts.isNotEmpty
        ? LatLng(pts.first.latitude!, pts.first.longitude!)
        : const LatLng(12.366, -1.527);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 12,
        onMapReady: () => _mapReady = true,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.yele',
        ),
        MarkerLayer(
          markers: [
            for (final r in pts)
              Marker(
                point: LatLng(r.latitude!, r.longitude!),
                width: 32,
                height: 32,
                child: Icon(
                  Icons.location_on,
                  color: _expandedId == r.id
                      ? YeleColors.danger
                      : const Color(0xFF16557E),
                  size: 28,
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _selectResult(SpeedTestResult result) {
    setState(() => _expandedId = _expandedId == result.id ? null : result.id);
    final latitude = result.latitude;
    final longitude = result.longitude;
    if (_mapReady && latitude != null && longitude != null) {
      _mapController.move(LatLng(latitude, longitude), 14);
    }
  }

  Widget _tabs() {
    Widget tab(String label, int index) {
      final active = _tab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _tab = index;
            _expandedId = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: YeleColors.panel2,
              border: Border(
                bottom: BorderSide(
                  color: active ? YeleColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
                color: active ? YeleColors.ink : const Color(0xFF5A6577),
              ),
            ),
          ),
        ),
      );
    }

    return Row(children: [tab('TEST COMPLET', 0), tab('SPEED TEST', 1)]);
  }

  Widget _header() {
    Widget h(IconData icon, String label, int flex) {
      return Expanded(
        flex: flex,
        child: Column(
          children: [
            Icon(icon, size: 18, color: YeleColors.field),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: YeleColors.field,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        color: YeleColors.panel,
        border: Border(bottom: BorderSide(color: YeleColors.line)),
      ),
      child: Row(
        children: [
          h(Icons.network_check, 'Type', 12),
          h(Icons.public, 'Opé. / Réseau', 20),
          h(Icons.calendar_today, 'Date', 13),
          h(Icons.hourglass_bottom, 'Débits', 14),
          h(Icons.workspace_premium, 'Score', 12),
        ],
      ),
    );
  }

  Color _typeColor(String? net) {
    final n = (net ?? '').toUpperCase();
    if (n.contains('WIFI') || n.contains('WI-FI')) return YeleColors.primary;
    if (n.contains('5G')) return YeleColors.g5;
    if (n.contains('4G')) return YeleColors.g4;
    if (n.contains('3G')) return YeleColors.g3;
    if (n.contains('2G')) return YeleColors.g2;
    return YeleColors.muted; // Inconnu / défaut
  }

  /// Icône reflétant le type de connexion réellement utilisé pour le test.
  IconData _typeIcon(String? net) {
    final n = (net ?? '').toUpperCase();
    if (n.contains('WIFI') || n.contains('WI-FI')) return Icons.wifi;
    if (n.contains('2G') ||
        n.contains('3G') ||
        n.contains('4G') ||
        n.contains('5G')) {
      return Icons.signal_cellular_alt;
    }
    return Icons.network_check;
  }

  Widget _row(SpeedTestResult r) {
    final expanded = _expandedId == r.id;
    final net = r.networkType ?? '—';
    return Column(
      children: [
        InkWell(
          onTap: () => _selectResult(r),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF10161F),
              border: Border(bottom: BorderSide(color: YeleColors.testBot)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Type
                Expanded(
                  flex: 12,
                  child: Column(
                    children: [
                      Icon(
                        _typeIcon(net),
                        size: 16,
                        color: const Color(0xFFCFD6E0),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        net,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCFD6E0),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: _typeColor(net),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          net.length > 5 ? net.substring(0, 5) : net,
                          style: const TextStyle(
                            color: Color(0xFF11210B),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ISP / Réseau
                Expanded(
                  flex: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.operator ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFCFD6E0),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _networkName(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8FA0B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Date
                Expanded(
                  flex: 13,
                  child: Column(
                    children: [
                      Text(
                        _date.format(r.timestamp),
                        style: const TextStyle(
                          color: Color(0xFFCFD6E0),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _time.format(r.timestamp),
                        style: const TextStyle(
                          color: Color(0xFF8FA0B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Débits
                Expanded(
                  flex: 14,
                  child: Column(
                    children: [
                      Text(
                        _fmtSpeed(r.downloadSpeed),
                        style: const TextStyle(
                          color: Color(0xFFCFD6E0),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _fmtSpeed(r.uploadSpeed),
                        style: const TextStyle(
                          color: Color(0xFF8FA0B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score /100 + bouton d'expansion
                Expanded(
                  flex: 12,
                  child: Column(
                    children: [
                      Text(
                        '${_score(r)}',
                        style: const TextStyle(
                          color: Color(0xFFCFD6E0),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: YeleColors.testBot,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          expanded ? Icons.remove : Icons.add,
                          size: 16,
                          color: const Color(0xFF11210B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) _detail(r),
      ],
    );
  }

  /// Volume en ko → « Mo » / « Go » selon l'ordre de grandeur.
  String _fmtData(int kb) {
    if (kb >= 1024 * 1024) {
      return '${(kb / 1024 / 1024).toStringAsFixed(2)} Go';
    }
    if (kb >= 1024) return '${(kb / 1024).toStringAsFixed(1)} Mo';
    return '$kb Ko';
  }

  String _fmtSpeed(double mbps) => formatSpeed(mbps, _speedUnit, decimals: 2);

  String _networkName(SpeedTestResult r) {
    if (r.isWifiTest) {
      final ssid = r.wifiSsid;
      return ssid == null || ssid.isEmpty ? 'Wi-Fi' : ssid;
    }

    final name = r.simOperator;
    final code = r.operatorCode;
    final formattedCode = code != null && code.length == 5
        ? ' (${code.substring(0, 3)}:${code.substring(3)})'
        : '';
    if (name != null && name.isNotEmpty) return '$name$formattedCode';
    return (r.networkType ?? '').isNotEmpty ? r.networkType! : '—';
  }

  String _technology(SpeedTestResult r) {
    if (!r.isWifiTest) {
      final tech = r.cellularTech;
      return tech == null || tech.isEmpty ? (r.networkType ?? '—') : tech;
    }
    final band = r.wifiBand;
    return band == null || band.isEmpty ? 'WiFi' : 'WiFi $band';
  }

  String _signal(SpeedTestResult r) {
    if (r.isWifiTest || (r.rsrp == null && r.rsrq == null)) {
      return 'Non disponible';
    }
    return [
      if (r.rsrp != null) '${r.rsrp} dBm',
      if (r.rsrq != null) '${r.rsrq} dB',
    ].join(' / ');
  }

  Widget _detail(SpeedTestResult r) {
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Text(
              '$k :',
              style: const TextStyle(color: Color(0xFF1F3A00), fontSize: 10),
            ),
          ),
          Expanded(
            flex: 9,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1F3A00),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final left = <Widget>[
      line('Serveur', r.server),
      line('Opérateur', r.operator ?? '—'),
      line('Réseau', _networkName(r)),
      line('Techno', _technology(r)),
      line('Signal', _signal(r)),
      line(
        'Coord.',
        r.latitude != null && r.longitude != null
            ? '${r.latitude!.toStringAsFixed(4)}, '
                  '${r.longitude!.toStringAsFixed(4)}'
            : '—',
      ),
      line('Adresse', r.location ?? '—'),
      if (r.dataConsumedKb != null)
        line('Trafic consommé', _fmtData(r.dataConsumedKb!)),
      if (r.durationLabel != null) line('Durée du test', r.durationLabel!),
      if (r.qoeRating != null && r.qoeRating! > 0)
        line('QoE', '${r.qoeRating}/5'),
    ];
    final right = <Widget>[
      line(
        'Débit descendant min / moy / max',
        r.minDownloadSpeed == null || r.maxDownloadSpeed == null
            ? '—'
            : '${_fmtSpeed(r.minDownloadSpeed!)} / '
                  '${_fmtSpeed(r.avgDownloadSpeed ?? r.downloadSpeed)} / '
                  '${_fmtSpeed(r.maxDownloadSpeed!)}',
      ),
      line(
        'Débit montant min / moy / max',
        r.minUploadSpeed == null ||
                r.avgUploadSpeed == null ||
                r.maxUploadSpeed == null
            ? '—'
            : '${_fmtSpeed(r.minUploadSpeed!)} / '
                  '${_fmtSpeed(r.avgUploadSpeed!)} / '
                  '${_fmtSpeed(r.maxUploadSpeed!)}',
      ),
      line(
        'Latence min / moy / max',
        r.minPing == null || r.maxPing == null
            ? '—'
            : '${r.minPing!.toStringAsFixed(0)} / '
                  '${(r.avgPing ?? r.ping).toStringAsFixed(0)} / '
                  '${r.maxPing!.toStringAsFixed(0)} ms',
      ),
      line('Gigue', '${r.jitter.toStringAsFixed(0)} ms'),
      if (r.hasBrowsingTest)
        line(
          'Indice performance navig.',
          '${r.browsingScore!.toStringAsFixed(2)}%',
        ),
      if (r.hasStreamingTest)
        line(
          'Indice performance vidéo',
          '${r.streamingScore!.toStringAsFixed(2)}%',
        ),
    ];
    final rows = left.length > right.length ? left.length : right.length;

    return Container(
      width: double.infinity,
      color: YeleColors.testMid,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(
          rows,
          (index) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left[index]),
              const SizedBox(width: 12),
              Expanded(
                child: index < right.length ? right[index] : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
