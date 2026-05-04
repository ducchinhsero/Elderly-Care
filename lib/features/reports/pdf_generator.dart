import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/models/user_profile.dart';

Future<Uint8List> generateClinicalReportPdf(PdfPageFormat format, UserProfile profile, int days) async {
  final pdf = pw.Document();

  // Load font hỗ trợ tiếng Việt
  final fontRegular = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();

  final theme = pw.ThemeData.withFont(
    base: fontRegular,
    bold: fontBold,
  );

  // Sinh dữ liệu giả lập cho báo cáo
  final startDate = DateTime.now().subtract(Duration(days: days));
  final endDate = DateTime.now();

  final avgHr = 72;
  final avgRmssd = 28;
  final normalPercent = 95.5;
  final abnormalPercent = 4.5;

  final events = [
    {'time': DateTime.now().subtract(const Duration(hours: 2)), 'event': 'Ngoại tâm thu thất (PVC) đơn lẻ', 'hr': '85'},
    {'time': DateTime.now().subtract(const Duration(days: 1, hours: 5)), 'event': 'Rung nhĩ đáp ứng thất nhanh kéo dài 2 phút', 'hr': '135'},
    {'time': DateTime.now().subtract(const Duration(days: 2, hours: 10)), 'event': 'Nhịp chậm sinh lý khi ngủ', 'hr': '45'},
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: format,
      theme: theme,
      header: (context) => _buildHeader(profile, days, startDate, endDate),
      footer: (context) => _buildFooter(context),
      build: (context) => [
        pw.SizedBox(height: 20),
        _buildPatientInfo(profile),
        pw.SizedBox(height: 20),
        _buildSummary(avgHr, avgRmssd, normalPercent, abnormalPercent),
        pw.SizedBox(height: 20),
        _buildEventsList(events),
        pw.SizedBox(height: 20),
        _buildConclusion(),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _buildHeader(UserProfile profile, int days, DateTime start, DateTime end) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('BÁO CÁO LÂM SÀNG NHỊP TIM', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Text('Elder Health Monitor', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Text('Thời gian: ${dateFormat.format(start)} - ${dateFormat.format(end)} ($days ngày)', style: const pw.TextStyle(fontSize: 12)),
      pw.Divider(thickness: 2, color: PdfColors.blue800),
    ],
  );
}

pw.Widget _buildFooter(pw.Context context) {
  return pw.Column(
    children: [
      pw.Divider(color: PdfColors.grey),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Được tạo tự động bởi Elder Health Monitor AI', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text('Trang ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    ],
  );
}

pw.Widget _buildPatientInfo(UserProfile profile) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      border: pw.Border.all(color: PdfColors.grey300),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('THÔNG TIN BỆNH NHÂN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Họ và tên: ${profile.fullName}'),
                  pw.Text('Tuổi: ${profile.age} | Giới tính: ${profile.gender == 'male' ? 'Nam' : 'Nữ'}'),
                  pw.Text('Cân nặng: ${profile.weightKg ?? '--'} kg | Chiều cao: ${profile.heightCm ?? '--'} cm'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bệnh nền: ${profile.comorbidities.isNotEmpty ? profile.comorbidities.length : 'Không'}'),
                  pw.Text('Thuốc đang dùng: ${profile.medications.isNotEmpty ? profile.medications.length : 'Không'}'),
                  pw.Text('Bác sĩ ĐT: ${profile.primaryPhysician ?? 'Chưa cập nhật'}'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildSummary(int avgHr, int avgRmssd, double normal, double abnormal) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('TỔNG QUAN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryBox('HR Trung bình', '$avgHr BPM', PdfColors.blue100),
          _buildSummaryBox('RMSSD Trung bình', '$avgRmssd ms', PdfColors.green100),
          _buildSummaryBox('Nhịp bình thường', '$normal%', PdfColors.teal100),
          _buildSummaryBox('Nhịp bất thường', '$abnormal%', PdfColors.red100),
        ],
      ),
    ],
  );
}

pw.Widget _buildSummaryBox(String title, String value, PdfColor bgColor) {
  return pw.Container(
    width: 110,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: bgColor,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _buildEventsList(List<Map<String, dynamic>> events) {
  final dateFormat = DateFormat('dd/MM HH:mm');
  
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('CÁC SỰ KIỆN ĐÁNG CHÚ Ý (CLINICAL ALERTS)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(5),
          2: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Thời gian', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Sự kiện / Dấu hiệu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Nhịp tim', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ],
          ),
          ...events.map((e) {
            return pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dateFormat.format(e['time'] as DateTime))),
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e['event'] as String)),
                pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${e['hr']} BPM')),
              ],
            );
          }),
        ],
      ),
    ],
  );
}

pw.Widget _buildConclusion() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('KẾT LUẬN & ĐỀ XUẤT TỪ AI', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Text('- Bệnh nhân có dấu hiệu đáp ứng thất nhanh trong cơn rung nhĩ. Cần theo dõi sát.'),
      pw.Text('- Biến thiên nhịp tim (RMSSD) ở mức ổn định so với độ tuổi.'),
      pw.Text('- Đề xuất: Khám lại chuyên khoa tim mạch để điều chỉnh liều lượng thuốc chẹn beta.'),
    ]
  );
}
