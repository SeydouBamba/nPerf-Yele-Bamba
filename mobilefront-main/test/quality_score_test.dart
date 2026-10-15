import 'package:flutter_test/flutter_test.dart';
import 'package:yele/services/app_preferences.dart';
import 'package:yele/services/quality_score.dart';

void main() {
  group('QualityScore', () {
    test('is shared normalized 0-100 calculation', () {
      expect(
        QualityScore.calculate(downloadMbps: 50, uploadMbps: 25, latencyMs: 20),
        100,
      );
      expect(
        QualityScore.calculate(downloadMbps: 0, uploadMbps: 0, latencyMs: 300),
        0,
      );
    });

    test('labels score bands consistently', () {
      expect(QualityScore.label(90), 'Excellent');
      expect(QualityScore.label(75), 'Très bon');
      expect(QualityScore.label(60), 'Bon');
      expect(QualityScore.label(40), 'Moyen');
      expect(QualityScore.label(39), 'Faible');
    });
  });

  test('converts Mbps to MB/s without changing stored units', () {
    expect(displaySpeedValue(80, 'MB/s'), 10);
    expect(displaySpeedValue(80, 'Mb/s'), 80);
    expect(formatSpeed(80, 'MB/s'), '10.0 MB/s');
  });
}
