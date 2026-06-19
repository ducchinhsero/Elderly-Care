// Models for the per-day statistical report (GET /daily-report).
//
// Mirrors the payload built by `src/assessment/daily_report.py` on the
// backend. Parsing is tolerant: numeric fields may arrive as int or double.

double? _toD(dynamic v) => v == null ? null : (v as num).toDouble();
double _toDor0(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _toI(dynamic v) => v == null ? 0 : (v as num).toInt();

Map<String, int> _toCountMap(dynamic v) {
  if (v is! Map) return {};
  return v.map((k, value) => MapEntry(k.toString(), _toI(value)));
}

class HrStats {
  final int n;
  final double mean, median, min, max, p5, p95, std;
  const HrStats({
    required this.n,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.p5,
    required this.p95,
    required this.std,
  });

  factory HrStats.fromJson(Map<String, dynamic> j) => HrStats(
        n: _toI(j['n']),
        mean: _toDor0(j['mean']),
        median: _toDor0(j['median']),
        min: _toDor0(j['min']),
        max: _toDor0(j['max']),
        p5: _toDor0(j['p5']),
        p95: _toDor0(j['p95']),
        std: _toDor0(j['std']),
      );
}

class HourlyHr {
  final String hour;
  final int n;
  final double mean, min, max, p25, p75;
  const HourlyHr({
    required this.hour,
    required this.n,
    required this.mean,
    required this.min,
    required this.max,
    required this.p25,
    required this.p75,
  });

  int get hourInt => int.tryParse(hour) ?? 0;

  factory HourlyHr.fromJson(Map<String, dynamic> j) => HourlyHr(
        hour: j['hour']?.toString() ?? '',
        n: _toI(j['n']),
        mean: _toDor0(j['mean']),
        min: _toDor0(j['min']),
        max: _toDor0(j['max']),
        p25: _toDor0(j['p25']),
        p75: _toDor0(j['p75']),
      );
}

class HrPoint {
  final String t; // "HH:MM"
  final double hr;
  const HrPoint({required this.t, required this.hr});

  /// Minutes since midnight, for the timeline x-axis.
  double get minuteOfDay {
    final parts = t.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60.0 + (int.tryParse(parts[1]) ?? 0);
  }

  factory HrPoint.fromJson(Map<String, dynamic> j) =>
      HrPoint(t: j['t']?.toString() ?? '', hr: _toDor0(j['hr']));
}

class StressHour {
  final String hour;
  final int stress, total;
  final double pct;
  const StressHour({
    required this.hour,
    required this.stress,
    required this.total,
    required this.pct,
  });

  int get hourInt => int.tryParse(hour) ?? 0;

  factory StressHour.fromJson(Map<String, dynamic> j) => StressHour(
        hour: j['hour']?.toString() ?? '',
        stress: _toI(j['stress']),
        total: _toI(j['total']),
        pct: _toDor0(j['pct']),
      );
}

class StressStats {
  final int valid, unknown, stress, nonStress;
  final double pctStress;
  final double? meanProb, maxProb;
  final List<StressHour> hourly;
  const StressStats({
    required this.valid,
    required this.unknown,
    required this.stress,
    required this.nonStress,
    required this.pctStress,
    required this.meanProb,
    required this.maxProb,
    required this.hourly,
  });

  factory StressStats.fromJson(Map<String, dynamic> j) => StressStats(
        valid: _toI(j['valid']),
        unknown: _toI(j['unknown']),
        stress: _toI(j['stress']),
        nonStress: _toI(j['non_stress']),
        pctStress: _toDor0(j['pct_stress']),
        meanProb: _toD(j['mean_prob']),
        maxProb: _toD(j['max_prob']),
        hourly: ((j['hourly'] as List?) ?? [])
            .map((e) => StressHour.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DayTrend {
  final String day, date;
  final int n;
  final double mean, median, max, pctOver100;
  const DayTrend({
    required this.day,
    required this.date,
    required this.n,
    required this.mean,
    required this.median,
    required this.max,
    required this.pctOver100,
  });

  factory DayTrend.fromJson(Map<String, dynamic> j) => DayTrend(
        day: j['day']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
        n: _toI(j['n']),
        mean: _toDor0(j['mean']),
        median: _toDor0(j['median']),
        max: _toDor0(j['max']),
        pctOver100: _toDor0(j['pct_over100']),
      );
}

class CriticalEvent {
  final String t, type;
  final double? hr;
  const CriticalEvent({required this.t, required this.type, this.hr});

  factory CriticalEvent.fromJson(Map<String, dynamic> j) => CriticalEvent(
        t: j['t']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        hr: _toD(j['hr']),
      );
}

class FallEvent {
  final String t, msg;
  final double? conf;
  const FallEvent({required this.t, required this.msg, this.conf});

  factory FallEvent.fromJson(Map<String, dynamic> j) => FallEvent(
        t: j['t']?.toString() ?? '',
        msg: j['msg']?.toString() ?? '',
        conf: _toD(j['conf']),
      );
}

class DailyReportModel {
  final String patientId, date, sessionId;
  final bool hasData;
  final int totalWindows, reliableWindows, totalEvents;
  final String? tStart, tEnd;
  final Map<String, int> signalQuality, activity;
  final Map<String, int> hrBands, rhythm, ectopy, eventTypes, eventSeverity;
  final HrStats? hrStats;
  final List<HourlyHr> hourly;
  final List<HrPoint> series;
  final double? afibMean, afibMax;
  final int afibOver03;
  final StressStats? stress;
  final List<DayTrend> days;
  final List<CriticalEvent> criticalEvents;
  final List<FallEvent> fallEvents;

  const DailyReportModel({
    required this.patientId,
    required this.date,
    required this.sessionId,
    required this.hasData,
    required this.totalWindows,
    required this.reliableWindows,
    required this.totalEvents,
    required this.tStart,
    required this.tEnd,
    required this.signalQuality,
    required this.activity,
    required this.hrBands,
    required this.rhythm,
    required this.ectopy,
    required this.eventTypes,
    required this.eventSeverity,
    required this.hrStats,
    required this.hourly,
    required this.series,
    required this.afibMean,
    required this.afibMax,
    required this.afibOver03,
    required this.stress,
    required this.days,
    required this.criticalEvents,
    required this.fallEvents,
  });

  int get ectopyTotal =>
      (ectopy['pac'] ?? 0) +
      (ectopy['pvc'] ?? 0) +
      (ectopy['mixed_ectopic'] ?? 0);

  int get criticalCount => eventSeverity['critical'] ?? 0;

  factory DailyReportModel.fromJson(Map<String, dynamic> j) {
    final afib = j['afib'] as Map<String, dynamic>?;
    return DailyReportModel(
      patientId: j['patient_id']?.toString() ?? '',
      date: j['date']?.toString() ?? '',
      sessionId: j['session_id']?.toString() ?? '',
      hasData: j['has_data'] == true,
      totalWindows: _toI(j['total_windows']),
      reliableWindows: _toI(j['reliable_windows']),
      totalEvents: _toI(j['total_events']),
      tStart: j['t_start']?.toString(),
      tEnd: j['t_end']?.toString(),
      signalQuality: _toCountMap(j['signal_quality']),
      activity: _toCountMap(j['activity']),
      hrBands: _toCountMap(j['hr_bands']),
      rhythm: _toCountMap(j['rhythm']),
      ectopy: _toCountMap(j['ectopy']),
      eventTypes: _toCountMap(j['event_types']),
      eventSeverity: _toCountMap(j['event_severity']),
      hrStats: j['hr_stats'] is Map
          ? HrStats.fromJson(j['hr_stats'] as Map<String, dynamic>)
          : null,
      hourly: ((j['hourly'] as List?) ?? [])
          .map((e) => HourlyHr.fromJson(e as Map<String, dynamic>))
          .toList(),
      series: ((j['series'] as List?) ?? [])
          .map((e) => HrPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      afibMean: _toD(afib?['mean']),
      afibMax: _toD(afib?['max']),
      afibOver03: _toI(afib?['over03']),
      stress: j['stress_stats'] is Map
          ? StressStats.fromJson(j['stress_stats'] as Map<String, dynamic>)
          : null,
      days: ((j['days'] as List?) ?? [])
          .map((e) => DayTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      criticalEvents: ((j['critical_events'] as List?) ?? [])
          .map((e) => CriticalEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      fallEvents: ((j['fall_events'] as List?) ?? [])
          .map((e) => FallEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AvailableDay {
  final String sessionId, date;
  const AvailableDay({required this.sessionId, required this.date});

  factory AvailableDay.fromJson(Map<String, dynamic> j) => AvailableDay(
        sessionId: j['session_id']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
      );
}
