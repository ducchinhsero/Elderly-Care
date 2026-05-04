import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/user_provider.dart';
import 'pdf_generator.dart';

class ClinicalReportScreen extends ConsumerWidget {
  final int days; // Số ngày (1, 7, 30)

  const ClinicalReportScreen({super.key, required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProvider).profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Báo cáo lâm sàng')),
        body: const Center(child: Text('Không tìm thấy hồ sơ người dùng.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem trước báo cáo'),
      ),
      body: PdfPreview(
        build: (format) => generateClinicalReportPdf(format, profile, days),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'Bao_Cao_Y_Te_${profile.uid}_${days}_ngay.pdf',
        previewPageMargin: const EdgeInsets.all(8),
      ),
    );
  }
}
