import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/daily_report_model.dart';
import '../../core/providers/daily_report_provider.dart';
import 'daily_report_pdf.dart';

/// "Báo cáo theo ngày" — pick a calendar date and view the full statistical
/// report (HR trend, band distribution, events, rhythm/ectopy, stress) sourced
/// from the cloud archive. Mirrors the standalone HTML report.
class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  DateTime? _selected;

  // No locale passed to DateFormat — Vietnamese locale data isn't initialized
  // app-wide, so we format numerically and add the weekday name manually.
  static final _apiFmt = DateFormat('yyyy-MM-dd');
  static final _displayFmt = DateFormat('dd/MM/yyyy');

  static const _weekdaysVi = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm',
    'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
  ];

  String _displayText(DateTime d) =>
      '${_weekdaysVi[d.weekday - 1]}, ${_displayFmt.format(d)}';

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final availableAsync = ref.watch(availableReportDaysProvider);

    // Default the selected date to the most recent day with data.
    final available = availableAsync.maybeWhen(
      data: (days) => days,
      orElse: () => <AvailableDay>[],
    );
    DateTime? newest;
    if (available.isNotEmpty) {
      newest = DateTime.tryParse(available.first.date);
    }
    final effective = _selected ?? newest ?? _stripTime(DateTime.now());
    final dateStr = _apiFmt.format(effective);

    final reportAsync = ref.watch(dailyReportProvider(dateStr));
    final report = reportAsync.valueOrNull;
    final canExport = report != null && report.hasData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo theo ngày'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Xuất PDF',
            onPressed: canExport ? () => _exportPdf(report) : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: () {
              ref.invalidate(dailyReportProvider(dateStr));
              ref.invalidate(availableReportDaysProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _DateBar(
            date: effective,
            displayText: _displayText(effective),
            availableDates: available
                .map((d) => DateTime.tryParse(d.date))
                .whereType<DateTime>()
                .map(_stripTime)
                .toSet(),
            onPick: (d) => setState(() => _selected = _stripTime(d)),
            onPrev: () => setState(
                () => _selected = _stripTime(effective.subtract(const Duration(days: 1)))),
            onNext: () {
              final next = _stripTime(effective.add(const Duration(days: 1)));
              if (!next.isAfter(_stripTime(DateTime.now()))) {
                setState(() => _selected = next);
              }
            },
            canGoNext: _stripTime(effective)
                .isBefore(_stripTime(DateTime.now())),
          ),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(dailyReportProvider(dateStr)),
              ),
              data: (data) => data.hasData
                  ? _ReportBody(report: data)
                  : const _EmptyState(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(DailyReportModel report) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Đang tạo PDF...')),
    );
    try {
      final bytes = await generateDailyReportPdf(PdfPageFormat.a4, report);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'bao-cao-suc-khoe-${report.date}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không tạo được PDF: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────── Date selector ──
class _DateBar extends StatelessWidget {
  final DateTime date;
  final String displayText;
  final Set<DateTime> availableDates;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool canGoNext;

  const _DateBar({
    required this.date,
    required this.displayText,
    required this.availableDates,
    required this.onPick,
    required this.onPrev,
    required this.onNext,
    required this.canGoNext,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
              tooltip: 'Ngày trước',
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2025, 1, 1),
                    lastDate: DateTime.now(),
                    helpText: 'Chọn ngày xem báo cáo',
                    selectableDayPredicate: availableDates.isEmpty
                        ? null
                        : (d) => availableDates
                            .contains(DateTime(d.year, d.month, d.day)),
                  );
                  if (picked != null) onPick(picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: canGoNext ? onNext : null,
              tooltip: 'Ngày sau',
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── Report body ──
class _ReportBody extends StatelessWidget {
  final DailyReportModel report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AlertBanner(report: report),
          _KpiGrid(report: report),
          const SizedBox(height: 16),
          if (report.series.isNotEmpty) ...[
            _HrTimelineCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.hourly.isNotEmpty) ...[
            _HourlyCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.hrBands.isNotEmpty) ...[
            _BandsCard(report: report),
            const SizedBox(height: 16),
          ],
          if (report.days.length >= 2) ...[
            _TrendCard(report: report),
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
          if (report.stress != null) ...[
            _StressCard(report: report),
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

// ───────────────────────────────────────────────────────────── Alert banner ──
class _AlertBanner extends StatelessWidget {
  final DailyReportModel report;
  const _AlertBanner({required this.report});

  @override
  Widget build(BuildContext context) {
    final restMean = report.days.isNotEmpty
        ? report.days.lastWhere((d) => d.day == report.sessionId,
            orElse: () => report.days.last).mean
        : (report.hrStats?.mean ?? 0);
    final crit = report.criticalCount;
    final highRest = restMean >= 100;
    if (!highRest && crit == 0) return const SizedBox.shrink();

    final color = (crit > 0 || restMean >= 130)
        ? AppColors.critical
        : AppColors.watchDark;
    final parts = <String>[];
    if (highRest) {
      parts.add('Nhịp tim nghỉ trung bình ${restMean.toStringAsFixed(0)} bpm '
          '(bình thường 60–100).');
    }
    if (crit > 0) parts.add('$crit sự kiện nguy kịch trong ngày.');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Điểm cần chú ý',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(parts.join(' '), style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────── KPI grid ──
class _KpiGrid extends StatelessWidget {
  final DailyReportModel report;
  const _KpiGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final hr = report.hrStats;
    final reliable = report.reliableWindows;
    final over120 = (report.hrBands['120-149'] ?? 0) +
        (report.hrBands['>=150'] ?? 0);
    final pctOver120 =
        (hr != null && hr.n > 0) ? over120 / hr.n * 100 : 0.0;
    final goodRatio = report.totalWindows > 0
        ? ((report.signalQuality['good'] ?? 0) +
                (report.signalQuality['fair'] ?? 0)) /
            report.totalWindows *
            100
        : 0.0;

    final cards = <_Kpi>[
      _Kpi('Nhịp TB (ngày)', hr?.mean.toStringAsFixed(0) ?? '--', 'bpm',
          _hrColor(hr?.mean ?? 0)),
      _Kpi('Cao nhất', hr?.max.toStringAsFixed(0) ?? '--', 'bpm',
          AppColors.critical),
      _Kpi('Thấp nhất', hr?.min.toStringAsFixed(0) ?? '--', 'bpm',
          AppColors.safe),
      _Kpi('Thời gian >120bpm', pctOver120.toStringAsFixed(0), '%',
          AppColors.alert),
      _Kpi('Sự kiện nguy kịch', '${report.criticalCount}', '',
          AppColors.critical),
      _Kpi('Nghi rung nhĩ (AF)', '${report.eventTypes['af_suspicion'] ?? 0}',
          'lần', AppColors.watchDark),
      _Kpi('Ngoại tâm thu', '${report.ectopyTotal}', 'cửa sổ',
          AppColors.watchDark),
      _Kpi('Stress', report.stress != null
          ? report.stress!.pctStress.toStringAsFixed(0)
          : '--', '%', AppColors.stressed),
      _Kpi('Chất lượng tín hiệu', goodRatio.toStringAsFixed(0), '%',
          AppColors.safe),
      _Kpi('Cửa sổ tin cậy', '$reliable', '', AppColors.primary),
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
          Text(kpi.label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: kpi.value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: kpi.color,
              ),
              children: [
                TextSpan(
                  text: kpi.unit.isEmpty ? '' : ' ${kpi.unit}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── HR timeline ──
class _HrTimelineCard extends StatelessWidget {
  final DailyReportModel report;
  const _HrTimelineCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final series = report.series;
    // Break the line where there is a data gap > 8 minutes.
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];
    double? prev;
    for (final p in series) {
      final m = p.minuteOfDay;
      if (prev != null && m - prev > 8) {
        if (current.isNotEmpty) segments.add(current);
        current = <FlSpot>[];
      }
      current.add(FlSpot(m, p.hr));
      prev = m;
    }
    if (current.isNotEmpty) segments.add(current);

    final minX = series.first.minuteOfDay;
    final maxX = series.last.minuteOfDay;
    final maxY = ((report.hrStats?.max ?? 180) + 10).clamp(160, 220).toDouble();

    return _ChartCard(
      title: 'Diễn biến nhịp tim trong ngày',
      subtitle:
          'Trung vị mỗi phút (tín hiệu tốt). Vùng xanh 60–100 bình thường; '
          'đường đứt 100 & 130 bpm.',
      child: SizedBox(
        height: 240,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: 50,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 20,
              getDrawingHorizontalLine: (v) => FlLine(
                  color: AppColors.chartGrid.withValues(alpha: 0.3),
                  strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 20,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 120,
                  getTitlesWidget: (v, _) {
                    final h = (v / 60).round();
                    return Text('${h}h',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint));
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(
                  y1: 60, y2: 100, color: AppColors.chartNormalZone),
            ]),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: 100,
                  color: AppColors.watchDark.withValues(alpha: 0.7),
                  strokeWidth: 1.2,
                  dashArray: [5, 4]),
              HorizontalLine(
                  y: 130,
                  color: AppColors.critical.withValues(alpha: 0.7),
                  strokeWidth: 1.2,
                  dashArray: [5, 4]),
            ]),
            lineBarsData: segments
                .map((s) => LineChartBarData(
                      spots: s,
                      isCurved: false,
                      color: AppColors.chartLine,
                      barWidth: 1.8,
                      dotData: const FlDotData(show: false),
                    ))
                .toList(),
            lineTouchData: const LineTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── Hourly chart ──
class _HourlyCard extends StatelessWidget {
  final DailyReportModel report;
  const _HourlyCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final hh = report.hourly;
    final maxY =
        (hh.map((h) => h.max).fold<double>(0, (a, b) => a > b ? a : b) + 10)
            .clamp(120, 220)
            .toDouble();

    return _ChartCard(
      title: 'Phân bố nhịp tim theo giờ',
      subtitle: 'Thanh = khoảng thấp nhất–cao nhất, màu theo nhịp trung bình.',
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
              getDrawingHorizontalLine: (v) => FlLine(
                  color: AppColors.chartGrid.withValues(alpha: 0.3),
                  strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  interval: 30,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textHint)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= hh.length) return const SizedBox.shrink();
                    if (i % 2 != 0) return const SizedBox.shrink();
                    return Text('${hh[i].hour}h',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textHint));
                  },
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: 100,
                  color: AppColors.watchDark.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: [4, 3]),
              HorizontalLine(
                  y: 130,
                  color: AppColors.critical.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: [4, 3]),
            ]),
            barGroups: [
              for (var i = 0; i < hh.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    fromY: hh[i].min,
                    toY: hh[i].max,
                    width: 8,
                    color: _hrColor(hh[i].mean),
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
  final DailyReportModel report;
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
      subtitle: 'Trên ${total.toString()} cửa sổ tín hiệu tin cậy.',
      child: Column(
        children: rows
            .map((r) => _LabeledBar(row: r, total: total, asPercent: true))
            .toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── 3-day trend ──
class _TrendCard extends StatelessWidget {
  final DailyReportModel report;
  const _TrendCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final days = report.days;
    final maxMean =
        days.map((d) => d.mean).fold<double>(0, (a, b) => a > b ? a : b);
    final axisMax = (maxMean + 20).clamp(120, 220).toDouble();
    return _ChartCard(
      title: 'Xu hướng nhịp tim nghỉ qua các ngày',
      subtitle: 'Nhịp tim lúc nghỉ trung bình (REST, tín hiệu tốt).',
      child: Column(
        children: days.map((d) {
          final color = _hrColor(d.mean);
          final frac = (d.mean / axisMax).clamp(0.0, 1.0);
          final label = d.date.length >= 10 ? d.date.substring(5) : d.date;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 52,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.chartGrid.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: Text(
                    '${d.mean.toStringAsFixed(0)} bpm · ${d.pctOver100.toStringAsFixed(0)}%>100',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────── Events ──
class _EventsCard extends StatelessWidget {
  final DailyReportModel report;
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
    final maxVal =
        entries.fold<int>(0, (a, c) => c.value > a ? c.value : a);
    return _ChartCard(
      title: 'Sự kiện theo loại (tổng ${report.totalEvents})',
      subtitle: 'Hệ thống tự phát hiện trong ngày.',
      child: Column(
        children: entries
            .map((e) => _LabeledBar(
                  row: _BarRow(_labels[e.key] ?? e.key, e.value,
                      _eventColor(e.key)),
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
  final DailyReportModel report;
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
      subtitle: 'Trên tín hiệu tốt.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.rhythm.isNotEmpty) ...[
            const Text('Nhịp (rhythm)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            _StackedBar(
                counts: report.rhythm,
                labels: _rhythmLabels,
                colorOf: _rhythmColor),
            const SizedBox(height: 14),
          ],
          if (report.ectopy.isNotEmpty) ...[
            const Text('Ngoại tâm thu (ectopy)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            _StackedBar(
                counts: report.ectopy,
                labels: _ectopyLabels,
                colorOf: _ectopyColor),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────── Stress ──
class _StressCard extends StatelessWidget {
  final DailyReportModel report;
  const _StressCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final s = report.stress!;
    final total = s.stress + s.nonStress;
    final stressFrac = total > 0 ? s.stress / total : 0.0;
    return _ChartCard(
      title: 'Mức độ stress trong ngày',
      subtitle:
          'Lưu ý: nhãn "stress" suy từ nhịp tim/HRV — khi nhịp nhanh, tỷ lệ '
          'này phản ánh kích hoạt giao cảm hơn là stress tâm lý.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: (stressFrac * 1000).round().clamp(1, 1000),
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.stressed,
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(6)),
                  ),
                  child: Text('${s.pctStress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ),
              Expanded(
                flex: ((1 - stressFrac) * 1000).round().clamp(1, 1000),
                child: Container(
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.safe,
                    borderRadius:
                        BorderRadius.horizontal(right: Radius.circular(6)),
                  ),
                  child: Text('${(100 - s.pctStress).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stress: ${s.stress} cửa sổ · Không stress: ${s.nonStress} · '
            'Không xác định: ${s.unknown}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          if (s.hourly.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Tỷ lệ % stress theo giờ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  maxY: 100,
                  minY: 0,
                  alignment: BarChartAlignment.spaceBetween,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: AppColors.chartGrid.withValues(alpha: 0.3),
                        strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 25,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textHint)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 18,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= s.hourly.length) {
                            return const SizedBox.shrink();
                          }
                          if (i % 2 != 0) return const SizedBox.shrink();
                          return Text('${s.hourly[i].hour}h',
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textHint));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < s.hourly.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: s.hourly[i].pct,
                          width: 7,
                          color: s.hourly[i].pct >= 80
                              ? AppColors.critical
                              : s.hourly[i].pct >= 40
                                  ? AppColors.alert
                                  : AppColors.stressed,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── Critical events ──
class _CriticalCard extends StatelessWidget {
  final DailyReportModel report;
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
    return _ChartCard(
      title: 'Sự kiện nguy kịch (${report.criticalEvents.length})',
      subtitle: 'Thời điểm và nhịp tim ghi nhận.',
      child: Column(
        children: report.criticalEvents.map((e) {
          final hrText = e.hr != null ? '${e.hr!.toStringAsFixed(0)} bpm' : '—';
          final hrColor = (e.hr ?? 0) >= 150
              ? AppColors.critical
              : AppColors.alert;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                    width: 70,
                    child: Text(e.t,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600))),
                Expanded(child: Text(_typeLabel(e.type), style: const TextStyle(fontSize: 13))),
                Text(hrText,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hrColor)),
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
  const _ChartCard(
      {required this.title, required this.subtitle, required this.child});

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
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
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
  const _LabeledBar(
      {required this.row, required this.total, required this.asPercent});

  @override
  Widget build(BuildContext context) {
    final frac = total > 0 ? row.value / total : 0.0;
    final right = asPercent
        ? '${(frac * 100).toStringAsFixed(1)}%'
        : row.value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(row.label,
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis),
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
                    decoration: BoxDecoration(
                      color: row.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
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
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
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
  const _StackedBar(
      {required this.counts, required this.labels, required this.colorOf});

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
                    decoration: BoxDecoration(
                        color: colorOf(e.key),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 5),
                Text('${labels[e.key] ?? e.key} ($pct%)',
                    style: const TextStyle(fontSize: 11.5)),
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
              'Đây là dữ liệu theo dõi/sàng lọc, không phải chẩn đoán y khoa. '
              'Các nhãn AF/ngoại tâm thu là nghi ngờ của mô hình, cần ECG '
              'chuẩn xác nhận.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy,
                size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('Không có dữ liệu cho ngày này',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Hãy chọn một ngày khác có dữ liệu đo.',
                style: TextStyle(color: AppColors.textSecondary)),
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
            const Text('Không tải được báo cáo',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

Color _hrColor(double bpm) {
  if (bpm >= 130) return AppColors.critical;
  if (bpm >= 100) return AppColors.watchDark;
  return AppColors.safe;
}
