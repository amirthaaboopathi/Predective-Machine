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
    required this.totalReadings,
    required this.totalAbnormalEvents,
    required this.mostFrequentAbnormalParam,
    required this.sensorAvailabilityPercent,
    this.periodStart,
    this.periodEnd,
  });
}

/// Service computing trend analytics, stats, and filtered historical data.
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
    // Return chronologically sorted for charting
    filtered.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return filtered;
  }

  /// Calculates statistical summaries and trends for a set of readings.
  static ApplianceAnalyticsSummary computeAnalytics(List<SensorReadingModel> rawReadings) {
    if (rawReadings.isEmpty) {
      return const ApplianceAnalyticsSummary(
        filteredReadings: [],
        temperature: ParameterStats.emptyTemp,
        vibration: ParameterStats.emptyVib,
        sound: ParameterStats.emptySound,
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
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
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
    final minVib = vibs.reduce((a, b) => a < b ? a : b);
    final maxVib = vibs.reduce((a, b) => a > b ? a : b);
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
    final minSound = sounds.reduce((a, b) => a < b ? a : b);
    final maxSound = sounds.reduce((a, b) => a > b ? a : b);
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

    return ApplianceAnalyticsSummary(
      filteredReadings: rawReadings,
      temperature: tempStats,
      vibration: vibStats,
      sound: soundStats,
      totalReadings: count,
      totalAbnormalEvents: totalAnomalies,
      mostFrequentAbnormalParam: dominantAnomalous,
      sensorAvailabilityPercent: 100.0,
      periodStart: rawReadings.first.recordedAt,
      periodEnd: rawReadings.last.recordedAt,
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
