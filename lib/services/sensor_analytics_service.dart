import 'dart:math';
import 'package:flutter/material.dart';
import '../models/sensor_reading_model.dart';

enum AnalyticsTimeRange {
  oneHour,
  sixHours,
  oneDay,
  sevenDays,
  thirtyDays,
  allTime,
}

enum ParameterTrend {
  rising,
  falling,
  stable,
}

enum FailureRiskLevel {
  low,
  moderate,
  high,
  critical,
}

class FailureRiskDataPoint {
  final DateTime timestamp;
  final double riskPercent; // 0.0 to 100.0%
  final String label;

  const FailureRiskDataPoint({
    required this.timestamp,
    required this.riskPercent,
    required this.label,
  });
}

/// Comprehensive predictive failure assessment calculated from sensor telemetry.
class PredictiveFailureAnalysis {
  final double failureRiskPercent; // 0% to 100%
  final FailureRiskLevel riskLevel;
  final String primaryRiskFactor;
  final String predictedFailureMode;
  final int estimatedDaysToFailure;
  final double thermalStressScore; // 0 to 100
  final double mechanicalStressScore; // 0 to 100
  final double acousticStressScore; // 0 to 100
  final List<String> preventativeRecommendations;
  final List<FailureRiskDataPoint> riskProgressionCurve;

  const PredictiveFailureAnalysis({
    required this.failureRiskPercent,
    required this.riskLevel,
    required this.primaryRiskFactor,
    required this.predictedFailureMode,
    required this.estimatedDaysToFailure,
    required this.thermalStressScore,
    required this.mechanicalStressScore,
    required this.acousticStressScore,
    required this.preventativeRecommendations,
    required this.riskProgressionCurve,
  });

  static const healthyDefault = PredictiveFailureAnalysis(
    failureRiskPercent: 8.5,
    riskLevel: FailureRiskLevel.low,
    primaryRiskFactor: 'None (Stable)',
    predictedFailureMode: 'Optimal Component Health',
    estimatedDaysToFailure: 180,
    thermalStressScore: 12.0,
    mechanicalStressScore: 10.0,
    acousticStressScore: 15.0,
    preventativeRecommendations: [
      'Maintain standard periodic inspection schedule.',
      'Ensure ambient ventilation pathways remain unobstructed.',
    ],
    riskProgressionCurve: [],
  );
}

/// Statistical calculations for a single monitored parameter.
class ParameterStats {
  final double latest;
  final double min;
  final double max;
  final double average;
  final ParameterTrend trend;
  final int anomalyCount;
  final String unit;

  const ParameterStats({
    required this.latest,
    required this.min,
    required this.max,
    required this.average,
    required this.trend,
    required this.anomalyCount,
    required this.unit,
  });

  static const emptyTemp = ParameterStats(
    latest: 0,
    min: 0,
    max: 0,
    average: 0,
    trend: ParameterTrend.stable,
    anomalyCount: 0,
    unit: '°C',
  );

  static const emptyVib = ParameterStats(
    latest: 0,
    min: 0,
    max: 0,
    average: 0,
    trend: ParameterTrend.stable,
    anomalyCount: 0,
    unit: 'G',
  );

  static const emptySound = ParameterStats(
    latest: 0,
    min: 0,
    max: 0,
    average: 0,
    trend: ParameterTrend.stable,
    anomalyCount: 0,
    unit: 'dB',
  );
}

/// Comprehensive analytics report computed from actual sensor readings.
class ApplianceAnalyticsSummary {
  final List<SensorReadingModel> filteredReadings;
  final ParameterStats temperature;
  final ParameterStats vibration;
  final ParameterStats sound;
  final PredictiveFailureAnalysis predictiveFailure;
  final int totalReadings;
  final int totalAbnormalEvents;
  final String mostFrequentAbnormalParam;
  final double sensorAvailabilityPercent;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const ApplianceAnalyticsSummary({
    required this.filteredReadings,
    required this.temperature,
    required this.vibration,
    required this.sound,
    required this.predictiveFailure,
    required this.totalReadings,
    required this.totalAbnormalEvents,
    required this.mostFrequentAbnormalParam,
    required this.sensorAvailabilityPercent,
    this.periodStart,
    this.periodEnd,
  });
}

/// Service computing trend analytics, stats, and predictive failure forecasts.
class SensorAnalyticsService {
  /// Filters readings by the specified time window.
  static List<SensorReadingModel> filterReadings(
    List<SensorReadingModel> readings,
    AnalyticsTimeRange range, {
    DateTimeRange? customRange,
  }) {
    if (readings.isEmpty) return [];

    final now = DateTime.now();
    DateTime cutoff;

    if (customRange != null) {
      return readings.where((r) {
        return r.recordedAt.isAfter(customRange.start) &&
            r.recordedAt.isBefore(customRange.end.add(const Duration(days: 1)));
      }).toList();
    }

    switch (range) {
      case AnalyticsTimeRange.oneHour:
        cutoff = now.subtract(const Duration(hours: 1));
        break;
      case AnalyticsTimeRange.sixHours:
        cutoff = now.subtract(const Duration(hours: 6));
        break;
      case AnalyticsTimeRange.oneDay:
        cutoff = now.subtract(const Duration(hours: 24));
        break;
      case AnalyticsTimeRange.sevenDays:
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case AnalyticsTimeRange.thirtyDays:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case AnalyticsTimeRange.allTime:
        cutoff = DateTime.fromMillisecondsSinceEpoch(0);
        break;
    }

    final filtered = readings.where((r) => r.recordedAt.isAfter(cutoff)).toList();
    filtered.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return filtered;
  }

  /// Calculates statistical summaries, trends, and predictive failure analysis.
  static ApplianceAnalyticsSummary computeAnalytics(List<SensorReadingModel> rawReadings) {
    if (rawReadings.isEmpty) {
      return const ApplianceAnalyticsSummary(
        filteredReadings: [],
        temperature: ParameterStats.emptyTemp,
        vibration: ParameterStats.emptyVib,
        sound: ParameterStats.emptySound,
        predictiveFailure: PredictiveFailureAnalysis.healthyDefault,
        totalReadings: 0,
        totalAbnormalEvents: 0,
        mostFrequentAbnormalParam: 'None',
        sensorAvailabilityPercent: 100.0,
      );
    }

    final count = rawReadings.length;
    final latestReading = rawReadings.last;

    // 1. Temperature metrics
    final temps = rawReadings.map((r) => r.temperature).toList();
    final minTemp = temps.reduce(min);
    final maxTemp = temps.reduce(max);
    final avgTemp = temps.reduce((a, b) => a + b) / count;
    final tempAnomalies = rawReadings.where((r) => r.temperature > 55.0).length;
    final tempTrend = _determineTrend(temps);

    final tempStats = ParameterStats(
      latest: double.parse(latestReading.temperature.toStringAsFixed(1)),
      min: double.parse(minTemp.toStringAsFixed(1)),
      max: double.parse(maxTemp.toStringAsFixed(1)),
      average: double.parse(avgTemp.toStringAsFixed(1)),
      trend: tempTrend,
      anomalyCount: tempAnomalies,
      unit: '°C',
    );

    // 2. Vibration metrics
    final vibs = rawReadings.map((r) => r.vibration).toList();
    final minVib = vibs.reduce(min);
    final maxVib = vibs.reduce(max);
    final avgVib = vibs.reduce((a, b) => a + b) / count;
    final vibAnomalies = rawReadings.where((r) => r.vibration > 0.40).length;
    final vibTrend = _determineTrend(vibs);

    final vibStats = ParameterStats(
      latest: double.parse(latestReading.vibration.toStringAsFixed(2)),
      min: double.parse(minVib.toStringAsFixed(2)),
      max: double.parse(maxVib.toStringAsFixed(2)),
      average: double.parse(avgVib.toStringAsFixed(2)),
      trend: vibTrend,
      anomalyCount: vibAnomalies,
      unit: 'G',
    );

    // 3. Sound metrics
    final sounds = rawReadings.map((r) => r.sound).toList();
    final minSound = sounds.reduce(min);
    final maxSound = sounds.reduce(max);
    final avgSound = sounds.reduce((a, b) => a + b) / count;
    final soundAnomalies = rawReadings.where((r) => r.sound > 62.0).length;
    final soundTrend = _determineTrend(sounds);

    final soundStats = ParameterStats(
      latest: double.parse(latestReading.sound.toStringAsFixed(1)),
      min: double.parse(minSound.toStringAsFixed(1)),
      max: double.parse(maxSound.toStringAsFixed(1)),
      average: double.parse(avgSound.toStringAsFixed(1)),
      trend: soundTrend,
      anomalyCount: soundAnomalies,
      unit: 'dB',
    );

    // Most frequent abnormal parameter
    final totalAnomalies = tempAnomalies + vibAnomalies + soundAnomalies;
    String dominantAnomalous = 'None';
    if (totalAnomalies > 0) {
      if (tempAnomalies >= vibAnomalies && tempAnomalies >= soundAnomalies) {
        dominantAnomalous = 'Appliance Temperature';
      } else if (vibAnomalies >= tempAnomalies && vibAnomalies >= soundAnomalies) {
        dominantAnomalous = 'Appliance Vibration';
      } else {
        dominantAnomalous = 'Operating Sound Level';
      }
    }

    // Predictive failure calculation
    final predictiveFailure = computePredictiveFailure(rawReadings);

    return ApplianceAnalyticsSummary(
      filteredReadings: rawReadings,
      temperature: tempStats,
      vibration: vibStats,
      sound: soundStats,
      predictiveFailure: predictiveFailure,
      totalReadings: count,
      totalAbnormalEvents: totalAnomalies,
      mostFrequentAbnormalParam: dominantAnomalous,
      sensorAvailabilityPercent: 100.0,
      periodStart: rawReadings.first.recordedAt,
      periodEnd: rawReadings.last.recordedAt,
    );
  }

  /// Computes physics-based and statistical predictive failure risks from sensor readings.
  static PredictiveFailureAnalysis computePredictiveFailure(List<SensorReadingModel> readings) {
    if (readings.isEmpty) return PredictiveFailureAnalysis.healthyDefault;

    final latest = readings.last;
    final maxTemp = readings.map((r) => r.temperature).reduce(max);
    final maxVib = readings.map((r) => r.vibration).reduce(max);

    // 1. Thermal Stress (Weight 35%):
    // Baseline safe <= 40°C. Warning > 55°C. Critical > 70°C.
    double thermalStress = 0.0;
    if (latest.temperature > 40.0) {
      thermalStress = ((latest.temperature - 40.0) / 45.0) * 100.0;
    }
    if (maxTemp > 65.0) {
      thermalStress += 15.0;
    }
    thermalStress = thermalStress.clamp(0.0, 100.0);

    // 2. Mechanical Vibration Stress (Weight 45%):
    // Baseline safe <= 0.20 G. Warning > 0.40 G. Critical > 0.80 G.
    double vibStress = 0.0;
    if (latest.vibration > 0.20) {
      vibStress = ((latest.vibration - 0.20) / 0.70) * 100.0;
    }
    if (maxVib > 0.65) {
      vibStress += 20.0;
    }
    vibStress = vibStress.clamp(0.0, 100.0);

    // 3. Acoustic Noise Stress (Weight 20%):
    // Baseline safe <= 50 dB. Warning > 62 dB. Critical > 75 dB.
    double soundStress = 0.0;
    if (latest.sound > 50.0) {
      soundStress = ((latest.sound - 50.0) / 38.0) * 100.0;
    }
    soundStress = soundStress.clamp(0.0, 100.0);

    // Composite Failure Risk Percentage:
    double compositeRisk = (vibStress * 0.45) + (thermalStress * 0.35) + (soundStress * 0.20);

    // Compound multiplier if dual stressors (e.g. thermal + vibration simultaneously)
    if (thermalStress > 35 && vibStress > 35) {
      compositeRisk = (compositeRisk * 1.25).clamp(0.0, 100.0);
    }
    compositeRisk = double.parse(compositeRisk.clamp(2.0, 99.0).toStringAsFixed(1));

    // Risk level classification
    FailureRiskLevel riskLevel;
    if (compositeRisk < 25.0) {
      riskLevel = FailureRiskLevel.low;
    } else if (compositeRisk < 55.0) {
      riskLevel = FailureRiskLevel.moderate;
    } else if (compositeRisk < 80.0) {
      riskLevel = FailureRiskLevel.high;
    } else {
      riskLevel = FailureRiskLevel.critical;
    }

    // Determine primary risk factor and predicted failure mode
    String primaryFactor;
    String failureMode;
    final recs = <String>[];

    if (vibStress >= thermalStress && vibStress >= soundStress && vibStress > 20.0) {
      primaryFactor = 'Mechanical Vibration & Rotor Imbalance';
      failureMode = 'Motor Bearing Fatigue & Shaft Misalignment';
      recs.add('Inspect rotor bearings and mechanical mounting brackets for looseness.');
      recs.add('Check for fan blade unbalance or compressor damper degradation.');
      recs.add('Schedule anti-vibration pad replacement if oscillation exceeds 0.50 G.');
    } else if (thermalStress >= vibStress && thermalStress >= soundStress && thermalStress > 20.0) {
      primaryFactor = 'Thermal Overload & Heat Dissipation';
      failureMode = 'Compressor Overheating & Winding Insulation Degradation';
      recs.add('Verify ventilation grills and heat-sink pathways are clean and unobstructed.');
      recs.add('Inspect internal coolant levels or thermal paste integrity.');
      recs.add('Verify operating line voltage to eliminate excessive stator draw.');
    } else if (soundStress > 25.0) {
      primaryFactor = 'Acoustic Resonance & Aerodynamic Friction';
      failureMode = 'Impeller Cavitation & Blower Friction';
      recs.add('Inspect ventilation ductwork and fan blades for mechanical obstruction.');
      recs.add('Clean intake filters to restore smooth laminar airflow.');
    } else {
      primaryFactor = 'Normal Operating Baseline';
      failureMode = 'Optimal Component Health — No Imminent Failure';
      recs.add('All monitored parameters are well within safe manufacturer limits.');
      recs.add('Continue regular operational usage without maintenance intervention.');
    }

    // Estimated Days to Failure (Remaining Useful Life)
    int daysToFailure;
    if (compositeRisk < 25.0) {
      daysToFailure = 180;
    } else if (compositeRisk < 45.0) {
      daysToFailure = 75;
    } else if (compositeRisk < 65.0) {
      daysToFailure = 28;
    } else if (compositeRisk < 85.0) {
      daysToFailure = 7;
    } else {
      daysToFailure = 2; // Critical imminent failure
    }

    // Generate Risk Progression Curve across readings
    final curve = <FailureRiskDataPoint>[];
    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      final ptThermal = (r.temperature > 40) ? ((r.temperature - 40) / 45 * 100).clamp(0, 100) : 0;
      final ptVib = (r.vibration > 0.20) ? ((r.vibration - 0.20) / 0.70 * 100).clamp(0, 100) : 0;
      final ptSound = (r.sound > 50) ? ((r.sound - 50) / 38 * 100).clamp(0, 100) : 0;
      final ptRisk = (ptVib * 0.45 + ptThermal * 0.35 + ptSound * 0.20).clamp(2.0, 99.0);

      curve.add(FailureRiskDataPoint(
        timestamp: r.recordedAt,
        riskPercent: double.parse(ptRisk.toStringAsFixed(1)),
        label: '${ptRisk.toStringAsFixed(1)}% Risk',
      ));
    }

    return PredictiveFailureAnalysis(
      failureRiskPercent: compositeRisk,
      riskLevel: riskLevel,
      primaryRiskFactor: primaryFactor,
      predictedFailureMode: failureMode,
      estimatedDaysToFailure: daysToFailure,
      thermalStressScore: double.parse(thermalStress.toStringAsFixed(1)),
      mechanicalStressScore: double.parse(vibStress.toStringAsFixed(1)),
      acousticStressScore: double.parse(soundStress.toStringAsFixed(1)),
      preventativeRecommendations: recs,
      riskProgressionCurve: curve,
    );
  }

  static ParameterTrend _determineTrend(List<double> values) {
    if (values.length < 2) return ParameterTrend.stable;
    final half = values.length ~/ 2;
    final firstHalf = values.sublist(0, half);
    final secondHalf = values.sublist(half);

    final avg1 = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final avg2 = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    if (avg1 == 0) return ParameterTrend.stable;
    final pctChange = (avg2 - avg1) / avg1;

    if (pctChange > 0.04) {
      return ParameterTrend.rising;
    } else if (pctChange < -0.04) {
      return ParameterTrend.falling;
    }
    return ParameterTrend.stable;
  }
}
