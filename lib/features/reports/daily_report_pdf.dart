import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/daily_report_model.dart';

/// Build a printable PDF of the per-day statistical report. Mirrors the
/// on-screen sections (KPIs, HR bands, hourly, events, rhythm/ectopy, stress,
/// critical events, 3-day trend) as text/tables — no charts.
Future<Uint8List> generateDailyReportPdf(
  PdfPageFormat format,
  DailyReportModel r,
) async {
  final pdf = pw.Document();
  final fontRegular = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();
  final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

  final hr = r.hrStats;
  final over120 =
      (r.hrBands['120-149'] ?? 0) + (r.hrBands['>=150'] ?? 0);
  final pctOver120 = (hr != null && hr.n > 0) ? over120 / hr.n * 100 : 0.0;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: format,
      theme: theme,
      header: (c) => _header(r),
      footer: (c) => _footer(c),
      build: (c) => [
        pw.SizedBox(height: 14),
        if (hr != null) ...[
          _summaryBoxes(r, hr, pctOver120),
          pw.SizedBox(height: 16),
        ],
        if (r.hrBands.isNotEmpty) ...[
          _bandsTable(r, hr?.n ?? 0),
          pw.SizedBox(height: 16),
        ],
        if (r.hourly.isNotEmpty) ...[
          _hourlyTable(r),
          pw.SizedBox(height: 16),
        ],
        if (r.eventTypes.isNotEmpty) ...[
          _eventsTable(r),
          pw.SizedBox(height: 16),
        ],
        if (r.rhythm.isNotEmpty || r.ectopy.isNotEmpty) ...[
          _rhythmSection(r),
          pw.SizedBox(height: 16),
        ],
        if (r.stress != null) ...[
          _stressSection(r),
          pw.SizedBox(height: 16),
        ],
        if (r.criticalEvents.isNotEmpty) ...[
          _criticalTable(r),
          pw.SizedBox(height: 16),
        ],
        if (r.days.length >= 2) ...[
          _trendTable(r),
          pw.SizedBox(height: 16),
        ],
        _disclaimer(),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _header(DailyReportModel r) {
  final range = (r.tStart != null && r.tEnd != null)
      ? '${r.tStart!.substring(11, 16)} – ${r.tEnd!.substring(11, 16)}'
      : '';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('BÁO CÁO SỨC KHỎE THEO NGÀY',
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800)),
          pw.Text('Elder Health Monitor',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        'Bệnh nhân: ${r.patientId}   |   Ngày: ${_fmtDate(r.date)}'
        '${range.isEmpty ? '' : '   |   Theo dõi: $range'}',
        style: const pw.TextStyle(fontSize: 11),
      ),
      pw.Text(
        '${r.totalWindows} cửa sổ phân tích · ${r.reliableWindows} cửa sổ tín hiệu tin cậy',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.Divider(thickness: 2, color: PdfColors.blue800),
    ],
  );
}

pw.Widget _footer(pw.Context c) {
  return pw.Column(children: [
    pw.Divider(color: PdfColors.grey),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Dữ liệu theo dõi/sàng lọc — không thay chẩn đoán y khoa',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text('Trang ${c.pageNumber}/${c.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    ),
  ]);
}

pw.Widget _summaryBoxes(DailyReportModel r, HrStats hr, double pctOver120) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle('TỔNG QUAN'),
      pw.SizedBox(height: 8),
      pw.Wrap(spacing: 8, runSpacing: 8, children: [
        _box('Nhịp TB', '${hr.mean.toStringAsFixed(0)} bpm', _hrBg(hr.mean)),
        _box('Cao nhất', '${hr.max.toStringAsFixed(0)} bpm', PdfColors.red100),
        _box('Thấp nhất', '${hr.min.toStringAsFixed(0)} bpm', PdfColors.green100),
        _box('Thời gian >120bpm', '${pctOver120.toStringAsFixed(0)}%',
            PdfColors.orange100),
        _box('Sự kiện nguy kịch', '${r.criticalCount}', PdfColors.red100),
        _box('Nghi rung nhĩ', '${r.eventTypes['af_suspicion'] ?? 0}',
            PdfColors.orange100),
        _box('Ngoại tâm thu', '${r.ectopyTotal}', PdfColors.amber100),
        if (r.stress != null)
          _box('Stress', '${r.stress!.pctStress.toStringAsFixed(0)}%',
              PdfColors.red50),
      ]),
    ],
  );
}

pw.Widget _bandsTable(DailyReportModel r, int total) {
  final rows = <List<String>>[];
  void add(String label, int v) {
    final pct = total > 0 ? (v / total * 100).toStringAsFixed(1) : '0';
    rows.add([label, '$v', '$pct%']);
  }

  if ((r.hrBands['<60'] ?? 0) > 0) add('<60 (chậm)', r.hrBands['<60']!);
  add('60–99 (bình thường)', r.hrBands['60-99'] ?? 0);
  add('100–119 (hơi nhanh)', r.hrBands['100-119'] ?? 0);
  add('120–149 (nhanh)', r.hrBands['120-149'] ?? 0);
  add('≥150 (rất nhanh)', r.hrBands['>=150'] ?? 0);

  return _titledTable(
    'PHÂN BỐ NHỊP TIM THEO DẢI',
    ['Dải nhịp (bpm)', 'Số cửa sổ', 'Tỷ lệ'],
    rows,
    const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2)},
  );
}

pw.Widget _hourlyTable(DailyReportModel r) {
  final rows = r.hourly
      .map((h) => [
            '${h.hour}h',
            '${h.n}',
            h.mean.toStringAsFixed(0),
            h.min.toStringAsFixed(0),
            h.max.toStringAsFixed(0),
          ])
      .toList();
  return _titledTable(
    'NHỊP TIM THEO GIỜ',
    ['Giờ', 'Số cửa sổ', 'TB', 'Thấp nhất', 'Cao nhất'],
    rows,
    const {
      0: pw.FlexColumnWidth(1.5),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(1.5),
      3: pw.FlexColumnWidth(2),
      4: pw.FlexColumnWidth(2),
    },
  );
}

const _eventLabels = {
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

pw.Widget _eventsTable(DailyReportModel r) {
  final entries = r.eventTypes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final rows = entries
      .map((e) => [_eventLabels[e.key] ?? e.key, '${e.value}'])
      .toList();
  return _titledTable(
    'SỰ KIỆN THEO LOẠI (tổng ${r.totalEvents})',
    ['Loại sự kiện', 'Số lần'],
    rows,
    const {0: pw.FlexColumnWidth(6), 1: pw.FlexColumnWidth(2)},
  );
}

pw.Widget _rhythmSection(DailyReportModel r) {
  String fmt(Map<String, int> m, Map<String, String> labels) {
    final total = m.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return '--';
    final entries = m.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) =>
            '${labels[e.key] ?? e.key}: ${(e.value / total * 100).toStringAsFixed(0)}%')
        .join('   ·   ');
  }

  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    _sectionTitle('PHÂN LOẠI NHỊP & NGOẠI TÂM THU'),
    pw.SizedBox(height: 6),
    pw.Text('Nhịp (rhythm): ${fmt(r.rhythm, const {
          'normal': 'Bình thường',
          'other_rhythm': 'Nhịp khác',
          'noise': 'Nhiễu',
          'possible_afib': 'Nghi AF',
        })}', style: const pw.TextStyle(fontSize: 11)),
    pw.SizedBox(height: 3),
    pw.Text('Ngoại tâm thu: ${fmt(r.ectopy, const {
          'normal': 'Bình thường',
          'pac': 'PAC (nhĩ)',
          'pvc': 'PVC (thất)',
          'mixed_ectopic': 'Hỗn hợp',
          'other': 'Khác',
        })}', style: const pw.TextStyle(fontSize: 11)),
    if (r.afibMax != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3),
        child: pw.Text(
          'Xác suất AF cao nhất: ${(r.afibMax! * 100).toStringAsFixed(0)}% · '
          '${r.afibOver03} cửa sổ có xác suất > 30%',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ),
  ]);
}

pw.Widget _stressSection(DailyReportModel r) {
  final s = r.stress!;
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    _sectionTitle('MỨC ĐỘ STRESS'),
    pw.SizedBox(height: 6),
    pw.Text(
      'Stress: ${s.pctStress.toStringAsFixed(1)}% (${s.stress}/${s.valid} cửa sổ hợp lệ).',
      style: const pw.TextStyle(fontSize: 11),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 3),
      child: pw.Text(
        'Lưu ý: nhãn "stress" suy từ nhịp tim/HRV — khi nhịp nhanh, tỷ lệ này '
        'phản ánh kích hoạt giao cảm hơn là stress tâm lý.',
        style: pw.TextStyle(
            fontSize: 9, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
      ),
    ),
  ]);
}

pw.Widget _criticalTable(DailyReportModel r) {
  final rows = r.criticalEvents.map((e) {
    final type = e.type == 'critical_hr_immobile'
        ? 'HR nguy kịch khi bất động'
        : e.type == 'fall_candidate'
            ? 'Nghi ngã'
            : e.type;
    return [e.t, type, e.hr != null ? '${e.hr!.toStringAsFixed(0)} bpm' : '—'];
  }).toList();
  return _titledTable(
    'SỰ KIỆN NGUY KỊCH (${r.criticalEvents.length})',
    ['Thời gian', 'Loại', 'Nhịp tim'],
    rows,
    const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(5), 2: pw.FlexColumnWidth(2)},
  );
}

pw.Widget _trendTable(DailyReportModel r) {
  final rows = r.days
      .map((d) => [
            _fmtDate(d.date),
            '${d.mean.toStringAsFixed(0)} bpm',
            '${d.pctOver100.toStringAsFixed(0)}%',
            '${d.max.toStringAsFixed(0)} bpm',
          ])
      .toList();
  return _titledTable(
    'XU HƯỚNG NHỊP TIM NGHỈ QUA CÁC NGÀY',
    ['Ngày', 'Nhịp nghỉ TB', '% >100bpm', 'Cao nhất'],
    rows,
    const {
      0: pw.FlexColumnWidth(3),
      1: pw.FlexColumnWidth(2),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(2),
    },
  );
}

pw.Widget _disclaimer() {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      border: pw.Border.all(color: PdfColors.grey300),
    ),
    child: pw.Text(
      'Đây là dữ liệu theo dõi/sàng lọc, không phải chẩn đoán y khoa. Các nhãn '
      'AF/ngoại tâm thu là nghi ngờ của mô hình AI, cần ECG chuẩn xác nhận. '
      'Nhịp nhanh có thể do nhiều nguyên nhân ngoài tim (sốt, thiếu máu, cường '
      'giáp, mất nước, lo âu, thuốc/caffeine).',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
    ),
  );
}

// ── small builders ──
pw.Widget _sectionTitle(String t) =>
    pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));

pw.Widget _box(String title, String value, PdfColor bg) {
  return pw.Container(
    width: 120,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
      pw.SizedBox(height: 3),
      pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
    ]),
  );
}

pw.Widget _titledTable(
  String title,
  List<String> headers,
  List<List<String>> rows,
  Map<int, pw.TableColumnWidth> widths,
) {
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    _sectionTitle(title),
    pw.SizedBox(height: 6),
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400),
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...rows.map((row) => pw.TableRow(
              children: row
                  .map((cell) => pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(cell, style: const pw.TextStyle(fontSize: 10)),
                      ))
                  .toList(),
            )),
      ],
    ),
  ]);
}

PdfColor _hrBg(double bpm) {
  if (bpm >= 130) return PdfColors.red100;
  if (bpm >= 100) return PdfColors.orange100;
  return PdfColors.green100;
}

String _fmtDate(String iso) {
  // iso "YYYY-MM-DD" -> "DD/MM/YYYY"
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
