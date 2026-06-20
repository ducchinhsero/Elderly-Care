// Model for the weekly/monthly statistical report (GET /period-report).
//
// Mirrors the payload built by `src/assessment/daily_report.py:compute_period_report`
// on the backend. Parsing is tolerant: numeric fields may arrive as int/double
// and optional blocks may be absent when there is no data.

double? _toD(dynamic v) => v == null ? null : (v as num).toDouble();
double _toDor0(dynamic v) => v == null ? 0 : (v as num).toDouble();
int _toI(dynamic v) => v == null ? 0 : (v as num).toInt();

Map<String, int> _toCountMap(dynamic v) {
  if (v is! Map) return {};
  return v.map((k, value) => MapEntry(k.toString(), _toI(value)));
}

/// One calendar day inside the period (per-day HR trend point).
class PeriodDay {
  final String day; // YYYYMMDD
  final String date; // YYYY-MM-DD
  final int n;
  final double mean, min, max, pctOver100, pctOver120;
  const PeriodDay({
    required this.day,
    required this.date,
    required this.n,
    required this.mean,
    required this.min,
    required this.max,
    required this.pctOver100,
    required this.pctOver120,
  });

  factory PeriodDay.fromJson(Map<String, dynamic> j) => PeriodDay(
        day: j['day']?.toString() ?? '',
        date: j['date']?.toString() ?? '',
        n: _toI(j['n']),
        mean: _toDor0(j['mean']),
        min: _toDor0(j['min']),
        max: _toDor0(j['max']),
        pctOver100: _toDor0(j['pct_over100']),
        pctOver120: _toDor0(j['pct_over120']),
      );
}

class PeriodHrStats {
  final int n;
  final double mean, min, max, std;
  const PeriodHrStats({
    required this.n,
    required this.mean,
    required this.min,
    required this.max,
    required this.std,
  });

  factory PeriodHrStats.fromJson(Map<String, dynamic> j) => PeriodHrStats(
        n: _toI(j['n']),
        mean: _toDor0(j['mean']),
        min: _toDor0(j['min']),
        max: _toDor0(j['max']),
        std: _toDor0(j['std']),
      );
}

class PeriodCriticalEvent {
  final String date, t, type;
  final double? hr;
  const PeriodCriticalEvent({
    required this.date,
    required this.t,
    required this.type,
    required this.hr,
  });

  factory PeriodCriticalEvent.fromJson(Map<String, dynamic> j) =>
      PeriodCriticalEvent(
        date: j['date']?.toString() ?? '',
        t: j['t']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        hr: _toD(j['hr']),
      );
}

/// One rate-based finding from the shared long-term evaluator.
class PeriodFinding {
  final String type, level, title, reason;
  final Map<String, dynamic> evidence;
  const PeriodFinding({
    required this.type,
    required this.level,
    required this.title,
    required this.reason,
    required this.evidence,
  });

  factory PeriodFinding.fromJson(Map<String, dynamic> j) => PeriodFinding(
        type: j['type']?.toString() ?? '',
        level: j['level']?.toString() ?? 'low',
        title: j['title']?.toString() ?? '',
        reason: j['reason']?.toString() ?? '',
        evidence: (j['evidence'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class PeriodAssessment {
  final String level, summary;
  final double score;
  final List<PeriodFinding> findings;
  const PeriodAssessment({
    required this.level,
    required this.summary,
    required this.score,
    required this.findings,
  });

  factory PeriodAssessment.fromJson(Map<String, dynamic> j) => PeriodAssessment(
        level: j['level']?.toString() ?? 'unknown',
        summary: j['summary']?.toString() ?? '',
        score: _toDor0(j['score']),
        findings: ((j['findings'] as List?) ?? [])
            .map((e) => PeriodFinding.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PeriodReportModel {
  final String patientId, period, dateStart, dateEnd;
  final int days, totalWindows, reliableWindows, dayCount, totalEvents;
  final double goodSignalRatio;
  final bool hasData;
  final PeriodHrStats? hrStats;
  final Map<String, int> hrBands;
  final List<PeriodDay> daysDetail;
  final Map<String, int> rhythm, ectopy;
  final double? afibMax, afibWindowRatio, afibMaxBurden;
  final Map<String, int> eventTypes, eventSeverity;
  final List<PeriodCriticalEvent> criticalEvents;
  final double? stressPct;
  final int stressCount, nonStressCount;
  final PeriodAssessment? assessment;

  const PeriodReportModel({
    required this.patientId,
    required this.period,
    required this.dateStart,
    required this.dateEnd,
    required this.days,
    required this.totalWindows,
    required this.reliableWindows,
    required this.dayCount,
    required this.totalEvents,
    required this.goodSignalRatio,
    required this.hasData,
    required this.hrStats,
    required this.hrBands,
    required this.daysDetail,
    required this.rhythm,
    required this.ectopy,
    required this.afibMax,
    required this.afibWindowRatio,
    required this.afibMaxBurden,
    required this.eventTypes,
    required this.eventSeverity,
    required this.criticalEvents,
    required this.stressPct,
    required this.stressCount,
    required this.nonStressCount,
    required this.assessment,
  });

  bool get isWeek => period == 'week';

  int get criticalCount => eventSeverity['critical'] ?? 0;

  int get ectopyTotal =>
      (ectopy['pvc'] ?? 0) + (ectopy['pac'] ?? 0) + (ectopy['mixed_ectopic'] ?? 0);

  factory PeriodReportModel.fromJson(Map<String, dynamic> j) {
    final afib = (j['afib'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stress = (j['stress_stats'] as Map?)?.cast<String, dynamic>();
    return PeriodReportModel(
      patientId: j['patient_id']?.toString() ?? '',
      period: j['period']?.toString() ?? 'week',
      dateStart: j['date_start']?.toString() ?? '',
      dateEnd: j['date_end']?.toString() ?? '',
      days: _toI(j['days']),
      totalWindows: _toI(j['total_windows']),
      reliableWindows: _toI(j['reliable_windows']),
      dayCount: _toI(j['day_count']),
      totalEvents: _toI(j['total_events']),
      goodSignalRatio: _toDor0(j['good_signal_ratio']),
      hasData: j['has_data'] == true,
      hrStats: j['hr_stats'] is Map
          ? PeriodHrStats.fromJson((j['hr_stats'] as Map).cast<String, dynamic>())
          : null,
      hrBands: _toCountMap(j['hr_bands']),
      daysDetail: ((j['days_detail'] as List?) ?? [])
          .map((e) => PeriodDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      rhythm: _toCountMap(j['rhythm']),
      ectopy: _toCountMap(j['ectopy']),
      afibMax: _toD(afib['max']),
      afibWindowRatio: _toD(afib['window_ratio']),
      afibMaxBurden: _toD(afib['max_burden_percent']),
      eventTypes: _toCountMap(j['event_types']),
      eventSeverity: _toCountMap(j['event_severity']),
      criticalEvents: ((j['critical_events'] as List?) ?? [])
          .map((e) => PeriodCriticalEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      stressPct: stress == null ? null : _toD(stress['pct_stress']),
      stressCount: stress == null ? 0 : _toI(stress['stress']),
      nonStressCount: stress == null ? 0 : _toI(stress['non_stress']),
      assessment: j['assessment'] is Map
          ? PeriodAssessment.fromJson(
              (j['assessment'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}
