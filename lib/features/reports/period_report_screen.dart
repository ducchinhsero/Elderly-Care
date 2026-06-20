import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/period_report_model.dart';
import '../../core/providers/period_report_provider.dart';

/// "Báo cáo theo tuần / tháng" — aggregate the last 7 or 30 days into a per-day
/// HR trend, band/rhythm/ectopy/stress breakdowns, event totals and an overall
/// rate-based risk assessment (same evaluator the edge backend uses).
class PeriodReportScreen extends ConsumerStatefulWidget {
  const PeriodReportScreen({super.key});

  @override
  ConsumerState<PeriodReportScreen> createState() => _PeriodReportScreenState();
}

class _PeriodReportScreenState extends ConsumerState<PeriodReportScreen> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(periodReportProvider(_period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo tuần / tháng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(periodReportProvider(_period)),
          ),
        ],
      ),
      body: Column(
        children: [
          _PeriodToggle(
            period: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const _LoadingState(),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(periodReportProvider(_period)),
              ),
              data: (report) => report.hasData && report.dayCount > 0
                  ? _ReportBody(report: report)
                  : const _EmptyState(),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── Period toggle ──
class _PeriodToggle extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  const _PeriodToggle({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'week', label: Text('7 ngày'), icon: Icon(Icons.view_week_outlined)),
            ButtonSegment(value: 'month', label: Text('30 ngày'), icon: Icon(Icons.calendar_month_outlined)),
          ],
          selected: {period},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── Report body ──
class _ReportBody extends StatelessWidget {
  final PeriodReportModel report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RangeHeader(report: report),
          const SizedBox(height: 12),
          if (report.assessment != null) ...[
            _AssessmentCard(assessment: report.assessment!),
            const SizedBox(height: 16),
          ],
          _KpiGrid(report: report),
          const SizedBox(height: 16),
          if (report.daysDetail.isNotEmpty) ...[
            _DailyTrendCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.hrBands.isNotEmpty) ...[
            _BandsCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.eventTypes.isNotEmpty) ...[
            _EventsCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.rhythm.isNotEmpty || report.ectopy.isNotEmpty) ...[
            _RhythmCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.criticalEvents.isNotEmpty) ...[
            _CriticalCard(report: report),
            const SizedBox(height: 16),
          ],
          const _Disclaimer(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RangeHeader extends StatelessWidget {
  final PeriodReportModel report;
  const _RangeHeader({required this.report});

  String _fmt(String iso) {
    if (iso.length < 10) return iso;
    return '${iso.substring(8, 10)}/${iso.substring(5, 7)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.date_range, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_fmt(report.dateStart)} → ${_fmt(report.dateEnd)} · '
            '${report.dayCount} ngày có dữ liệu',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────── Assessment card ──
class _AssessmentCard extends StatelessWidget {
  final PeriodAssessment assessment;
  const _AssessmentCard({required this.assessment});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(assessment.level);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment_outlined, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Đánh giá nhiều ngày',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              _LevelChip(level: assessment.level),
            ],
          ),
          const SizedBox(height: 8),
          Text(_summaryVi(assessment), style: const TextStyle(height: 1.35)),
          if (assessment.findings.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...assessment.findings.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8, color: _levelColor(f.level)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_findingTitleVi(f.type)} — ${_levelText(f.level)}'
                          '${_evidenceHint(f)}',
                          style: const TextStyle(fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 8),
          const Text(
            'Đánh giá theo ngưỡng tỉ lệ/ngày (chuẩn hoá để so sánh được giữa tuần và tháng), '
            'là sàng lọc — không phải chẩn đoán.',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  String _summaryVi(PeriodAssessment a) {
    if (a.findings.isEmpty) {
      return 'Không phát hiện mẫu nguy cơ đáng kể trong giai đoạn này.';
    }
    return 'Phát hiện mẫu nguy cơ/nghi ngờ lặp lại nhiều ngày trong giai đoạn.';
  }

  String _evidenceHint(PeriodFinding f) {
    final perDay = f.evidence['events_per_day'];
    if (perDay is num) return ' (~${perDay.toStringAsFixed(1)} lần/ngày)';
    final count = f.evidence['event_count'];
    if (count is num) return ' (${count.toInt()} lần)';
    return '';
  }
}

// ───────────────────────────────────────────────────────────────── KPI grid ──
class _KpiGrid extends StatelessWidget {
  final PeriodReportModel report;
  const _KpiGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final hr = report.hrStats;
    final over120 = (report.hrBands['120-149'] ?? 0) + (report.hrBands['>=150'] ?? 0);
    final reliable = report.reliableWindows;
    final pctOver120 = reliable > 0 ? over120 / reliable * 100 : 0.0;

    final cards = <_Kpi>[
      _Kpi('Nhịp TB', hr?.mean.toStringAsFixed(0) ?? '--', 'bpm', _hrColor(hr?.mean ?? 0)),
      _Kpi('Cao nhất', hr?.max.toStringAsFixed(0) ?? '--', 'bpm', AppColors.critical),
      _Kpi('Thấp nhất', hr?.min.toStringAsFixed(0) ?? '--', 'bpm', AppColors.safe),
      _Kpi('Thời gian >120bpm', pctOver120.toStringAsFixed(0), '%', AppColors.alert),
      _Kpi('Sự kiện nguy kịch', '${report.criticalCount}', '', AppColors.critical),
      _Kpi('Nghi rung nhĩ (AF)', '${report.eventTypes['af_suspicion'] ?? 0}', 'lần', AppColors.watchDark),
      _Kpi('Ngoại tâm thu', '${report.ectopyTotal}', 'cửa sổ', AppColors.watchDark),
      _Kpi('Stress', report.stressPct != null ? report.stressPct!.toStringAsFixed(0) : '--', '%', AppColors.stressed),
      _Kpi('Chất lượng tín hiệu', (report.goodSignalRatio * 100).toStringAsFixed(0), '%', AppColors.safe),
      _Kpi('Ngày có dữ liệu', '${report.dayCount}', '', AppColors.primary),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: cards.map((c) => _KpiCard(kpi: c)).toList(),
    );
  }
}

class _Kpi {
  final String label, value, unit;
  final Color color;
  const _Kpi(this.label, this.value, this.unit, this.color);
}

class _KpiCard extends StatelessWidget {
  final _Kpi kpi;
  const _KpiCard({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(kpi.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: kpi.value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kpi.color),
              children: [
                TextSpan(
                  text: kpi.unit.isEmpty ? '' : ' ${kpi.unit}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── Per-day HR trend ──
class _DailyTrendCard extends StatelessWidget {
  final PeriodReportModel report;
  const _DailyTrendCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final dd = report.daysDetail;
    final maxY = (dd.map((d) => d.max).fold<double>(0, (a, b) => a > b ? a : b) + 10)
        .clamp(120, 220)
        .toDouble();
    return _ChartCard(
      title: 'Diễn biến nhịp tim theo ngày',
      subtitle: 'Thanh = khoảng thấp–cao trong ngày, màu theo nhịp trung bình.',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            minY: 50,
            alignment: BarChartAlignment.spaceBetween,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 30,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: AppColors.chartGrid.withValues(alpha: 0.3), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 30,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= dd.length) return const SizedBox.shrink();
                    final step = dd.length > 10 ? 5 : 1;
                    if (i % step != 0) return const SizedBox.shrink();
                    final d = dd[i].date;
                    final label = d.length >= 10 ? d.substring(5) : d; // MM-DD
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(label, style: const TextStyle(fontSize: 8, color: AppColors.textHint)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: 100, color: AppColors.watchDark.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4, 3]),
              HorizontalLine(y: 130, color: AppColors.critical.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4, 3]),
            ]),
            barGroups: [
              for (var i = 0; i < dd.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    fromY: dd[i].min,
                    toY: dd[i].max,
                    width: dd.length > 12 ? 6 : 12,
                    color: _hrColor(dd[i].mean),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── Band distribution ──
class _BandsCard extends StatelessWidget {
  final PeriodReportModel report;
  const _BandsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final b = report.hrBands;
    final total = b.values.fold<int>(0, (a, c) => a + c);
    final rows = <_BarRow>[
      _BarRow('60–99 (bình thường)', b['60-99'] ?? 0, AppColors.safe),
      _BarRow('100–119 (hơi nhanh)', b['100-119'] ?? 0, AppColors.watch),
      _BarRow('120–149 (nhanh)', b['120-149'] ?? 0, AppColors.alert),
      _BarRow('≥150 (rất nhanh)', b['>=150'] ?? 0, AppColors.critical),
    ];
    if ((b['<60'] ?? 0) > 0) {
      rows.insert(0, _BarRow('<60 (chậm)', b['<60']!, AppColors.primary));
    }
    return _ChartCard(
      title: 'Tỷ lệ thời gian theo dải nhịp tim',
      subtitle: 'Trên $total cửa sổ tín hiệu tin cậy của cả giai đoạn.',
      child: Column(
        children: rows.map((r) => _LabeledBar(row: r, total: total, asPercent: true)).toList(),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────── Events ──
class _EventsCard extends StatelessWidget {
  final PeriodReportModel report;
  const _EventsCard({required this.report});

  static const _labels = {
    'hr_context': 'Cảnh báo HR theo ngữ cảnh',
    'stress_suspicion': 'Nghi stress',
    'ectopy_suspicion': 'Nghi ngoại tâm thu',
    'af_suspicion': 'Nghi rung nhĩ (AF)',
    'poor_signal': 'Tín hiệu kém',
    'sustained_tachycardia_immobile': 'Nhịp nhanh kéo dài',
    'sustained_bradycardia_immobile': 'Nhịp chậm kéo dài',
    'critical_hr_immobile': 'HR nguy kịch',
    'fall_candidate': 'Nghi ngã',
    'tachycardia': 'Nhịp nhanh',
    'bradycardia': 'Nhịp chậm',
  };

  Color _eventColor(String type) {
    switch (type) {
      case 'critical_hr_immobile':
      case 'fall_candidate':
        return AppColors.critical;
      case 'af_suspicion':
      case 'sustained_tachycardia_immobile':
      case 'sustained_bradycardia_immobile':
        return AppColors.alert;
      case 'ectopy_suspicion':
      case 'tachycardia':
      case 'bradycardia':
        return AppColors.watchDark;
      case 'stress_suspicion':
        return AppColors.stressed;
      case 'poor_signal':
        return AppColors.textHint;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = report.eventTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.fold<int>(0, (a, c) => c.value > a ? c.value : a);
    return _ChartCard(
      title: 'Sự kiện theo loại (tổng ${report.totalEvents})',
      subtitle: 'Tổng hợp toàn bộ giai đoạn.',
      child: Column(
        children: entries
            .map((e) => _LabeledBar(
                  row: _BarRow(_labels[e.key] ?? e.key, e.value, _eventColor(e.key)),
                  total: maxVal,
                  asPercent: false,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── Rhythm + ectopy ──
class _RhythmCard extends StatelessWidget {
  final PeriodReportModel report;
  const _RhythmCard({required this.report});

  static const _rhythmLabels = {
    'normal': 'Bình thường',
    'other_rhythm': 'Nhịp khác',
    'noise': 'Nhiễu',
    'possible_afib': 'Nghi AF',
  };
  static const _ectopyLabels = {
    'normal': 'Bình thường',
    'pac': 'PAC (nhĩ)',
    'pvc': 'PVC (thất)',
    'mixed_ectopic': 'Hỗn hợp',
    'other': 'Khác',
  };

  Color _rhythmColor(String k) {
    switch (k) {
      case 'normal':
        return AppColors.safe;
      case 'possible_afib':
        return AppColors.critical;
      case 'noise':
        return AppColors.textHint;
      default:
        return AppColors.primary;
    }
  }

  Color _ectopyColor(String k) {
    switch (k) {
      case 'normal':
        return AppColors.safe;
      case 'pac':
        return AppColors.watch;
      case 'pvc':
        return AppColors.alert;
      case 'mixed_ectopic':
        return AppColors.critical;
      default:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Phân loại nhịp & ngoại tâm thu',
      subtitle: 'Trên tín hiệu tốt của cả giai đoạn.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.rhythm.isNotEmpty) ...[
            const Text('Nhịp (rhythm)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            _StackedBar(counts: report.rhythm, labels: _rhythmLabels, colorOf: _rhythmColor),
            const SizedBox(height: 14),
          ],
          if (report.ectopy.isNotEmpty) ...[
            const Text('Ngoại tâm thu (ectopy)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            _StackedBar(counts: report.ectopy, labels: _ectopyLabels, colorOf: _ectopyColor),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── Critical events ──
class _CriticalCard extends StatelessWidget {
  final PeriodReportModel report;
  const _CriticalCard({required this.report});

  String _typeLabel(String t) {
    switch (t) {
      case 'critical_hr_immobile':
        return 'HR nguy kịch khi bất động';
      case 'fall_candidate':
        return 'Nghi ngã';
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cap the list so a long month doesn't render hundreds of rows.
    final events = report.criticalEvents;
    final shown = events.length > 40 ? events.sublist(0, 40) : events;
    return _ChartCard(
      title: 'Sự kiện nguy kịch (${events.length})',
      subtitle: events.length > shown.length
          ? 'Hiển thị ${shown.length} sự kiện gần đầu giai đoạn.'
          : 'Ngày, giờ và nhịp tim ghi nhận.',
      child: Column(
        children: shown.map((e) {
          final hrText = e.hr != null ? '${e.hr!.toStringAsFixed(0)} bpm' : '—';
          final hrColor = (e.hr ?? 0) >= 150 ? AppColors.critical : AppColors.alert;
          final dateLabel = e.date.length >= 10 ? e.date.substring(5) : e.date;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text('$dateLabel ${e.t.length >= 5 ? e.t.substring(0, 5) : e.t}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Text(_typeLabel(e.type), style: const TextStyle(fontSize: 13))),
                Text(hrText,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: hrColor)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ───────────────────────────────────────────────────── Shared small widgets ──
class _ChartCard extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BarRow {
  final String label;
  final int value;
  final Color color;
  const _BarRow(this.label, this.value, this.color);
}

class _LabeledBar extends StatelessWidget {
  final _BarRow row;
  final int total;
  final bool asPercent;
  const _LabeledBar({required this.row, required this.total, required this.asPercent});

  @override
  Widget build(BuildContext context) {
    final frac = total > 0 ? row.value / total : 0.0;
    final right = asPercent ? '${(frac * 100).toStringAsFixed(1)}%' : row.value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(row.label, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.chartGrid.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: frac.clamp(0.0, 1.0),
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(color: row.color, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(right,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final Map<String, int> counts;
  final Map<String, String> labels;
  final Color Function(String) colorOf;
  const _StackedBar({required this.counts, required this.labels, required this.colorOf});

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, c) => a + c.value);
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Row(
            children: entries
                .map((e) => Expanded(
                      flex: e.value,
                      child: Container(height: 24, color: colorOf(e.key)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: entries.map((e) {
            final pct = (e.value / total * 100).toStringAsFixed(0);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: colorOf(e.key), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 5),
                Text('${labels[e.key] ?? e.key} ($pct%)', style: const TextStyle(fontSize: 11.5)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đây là dữ liệu theo dõi/sàng lọc nhiều ngày, không phải chẩn đoán y khoa. '
              'Các nhãn AF/ngoại tâm thu là nghi ngờ của mô hình, cần ECG chuẩn xác nhận.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang tổng hợp dữ liệu nhiều ngày…',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 48, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('Chưa đủ dữ liệu cho giai đoạn này', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Cần thêm ngày đo có tín hiệu tốt để tổng hợp báo cáo.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('Không tải được báo cáo', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(_levelText(level),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

Color _hrColor(double bpm) {
  if (bpm >= 130) return AppColors.critical;
  if (bpm >= 100) return AppColors.watchDark;
  return AppColors.safe;
}

Color _levelColor(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return AppColors.critical;
    case 'high':
      return AppColors.alert;
    case 'medium':
      return AppColors.watchDark;
    case 'low':
    case 'normal':
      return AppColors.safe;
    default:
      return AppColors.textSecondary;
  }
}

String _levelText(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return 'Cần hỗ trợ ngay';
    case 'high':
      return 'Cần kiểm tra';
    case 'medium':
      return 'Cần theo dõi';
    case 'low':
    case 'normal':
      return 'Ổn định';
    default:
      return 'Chưa đủ dữ liệu';
  }
}

String _findingTitleVi(String type) {
  switch (type) {
    case 'long_term_afib_suspicion':
      return 'Nhịp không đều (nghi AF) lặp lại';
    case 'long_term_ectopy_activity':
      return 'Ngoại tâm thu lặp lại';
    case 'long_term_heart_rate_abnormality':
      return 'Nhịp tim bất thường lặp lại';
    case 'long_term_fall_risk':
      return 'Có dấu hiệu nghi ngã';
    case 'long_term_poor_signal':
      return 'Chất lượng tín hiệu thấp';
    default:
      return type;
  }
}
