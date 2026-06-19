import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:elder_health_monitor/core/models/daily_report_model.dart';

/// Parses the REAL /daily-report payload captured from the cloud reader to
/// verify the statistics-parsing logic that the report screen relies on.
void main() {
  test('DailyReportModel.fromJson parses a real cloud /daily-report payload',
      () {
    final raw =
        File('test/fixtures/daily_report_18.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final r = DailyReportModel.fromJson(json);

    expect(r.hasData, isTrue, reason: 'has_data should be true');
    expect(r.date, '2026-06-18');
    expect(r.totalWindows, greaterThan(0));
    expect(r.reliableWindows, greaterThan(0));

    expect(r.hrStats, isNotNull);
    expect(r.hrStats!.mean, closeTo(108.7, 1.0));
    expect(r.hrStats!.max, closeTo(182.2, 1.0));
    expect(r.hrStats!.min, greaterThan(0));

    expect(r.hrBands.isNotEmpty, isTrue);
    expect(r.hrBands['60-99'], greaterThan(0));

    expect(r.hourly.length, greaterThan(0));
    expect(r.hourly.first.mean, greaterThan(0));

    expect(r.series.length, greaterThan(0));
    expect(r.series.first.minuteOfDay, greaterThanOrEqualTo(0));

    expect(r.eventTypes.isNotEmpty, isTrue);
    expect(r.totalEvents, greaterThan(0));
    expect(r.criticalEvents.length, greaterThan(0));

    expect(r.rhythm.isNotEmpty, isTrue);
    expect(r.ectopy.isNotEmpty, isTrue);
    expect(r.stress, isNotNull);
    expect(r.stress!.pctStress, greaterThanOrEqualTo(0));

    expect(r.days.length, greaterThanOrEqualTo(2),
        reason: '3-day trend should have prior days');
  });

  test('AvailableDay list parses', () {
    final raw = File('test/fixtures/available_days.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final days = (json['days'] as List)
        .map((e) => AvailableDay.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(days, isNotEmpty);
    expect(days.first.date, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });
}
