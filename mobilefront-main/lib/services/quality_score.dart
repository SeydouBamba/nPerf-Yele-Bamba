class QualityScore {
  const QualityScore._();

  // Yélé's transparent 0-100 reference scale; it is not nPerf's proprietary score.
  static int calculate({
    required double downloadMbps,
    required double uploadMbps,
    required double latencyMs,
  }) {
    final download = (downloadMbps / 50 * 60).clamp(0, 60);
    final upload = (uploadMbps / 25 * 20).clamp(0, 20);
    final latency = latencyMs <= 20
        ? 20.0
        : latencyMs >= 300
        ? 0.0
        : (300 - latencyMs) / 280 * 20;
    return (download + upload + latency).round().clamp(0, 100).toInt();
  }

  static String label(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Très bon';
    if (score >= 60) return 'Bon';
    if (score >= 40) return 'Moyen';
    return 'Faible';
  }
}
