import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HRGaugeWidget extends StatefulWidget {
  final double hrBpm;
  final String alertLevel;
  final String conditionNameVi;
  final double confidence;
  final double hrMin;
  final double hrMax;
  final VoidCallback? onTap;

  const HRGaugeWidget({
    super.key,
    required this.hrBpm,
    required this.alertLevel,
    required this.conditionNameVi,
    required this.confidence,
    required this.hrMin,
    required this.hrMax,
    this.onTap,
  });

  @override
  State<HRGaugeWidget> createState() => _HRGaugeWidgetState();
}

class _HRGaugeWidgetState extends State<HRGaugeWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startAnimations();
  }

  @override
  void didUpdateWidget(covariant HRGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hrBpm != widget.hrBpm || oldWidget.alertLevel != widget.alertLevel) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    // Sync heartbeat pulse with HR
    final hr = widget.hrBpm > 0 ? widget.hrBpm : 60.0;
    final durationMs = (60000 / hr).round();
    _pulseController.duration = Duration(milliseconds: durationMs);
    _pulseController.repeat(reverse: true);

    if (widget.alertLevel == 'CRITICAL') {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Color _getBaseColor() {
    switch (widget.alertLevel) {
      case 'WATCH': return AppColors.watch;
      case 'ALERT': return AppColors.alert;
      case 'CRITICAL': return AppColors.critical;
      case 'SAFE':
      default: return AppColors.safe;
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.alertLevel) {
      case 'WATCH': return [const Color(0xFFFFC107), const Color(0xFFFFD54F)];
      case 'ALERT': return [const Color(0xFFFF5722), const Color(0xFFFF8A65)];
      case 'CRITICAL': return [const Color(0xFFF44336), const Color(0xFFEF5350)];
      case 'SAFE':
      default: return [const Color(0xFF4CAF50), const Color(0xFF81C784)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final hrAvg = (widget.hrMin + widget.hrMax) / 2; // Simple avg for display

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vòng tròn chính
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _blinkController]),
            builder: (context, child) {
              final opacity = widget.alertLevel == 'CRITICAL' 
                  ? Tween<double>(begin: 1.0, end: 0.5).evaluate(_blinkController)
                  : 1.0;
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Opacity(
                  opacity: opacity,
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: _GaugePainter(
                        colors: _getGradientColors(),
                        value: widget.hrBpm,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  widget.hrBpm.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: _getBaseColor(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'BPM',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _getBaseColor().withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.conditionNameVi,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (widget.confidence < 0.80) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.textHint.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 10, height: 10,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.textHint)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('Đang phân tích', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Chỉ số phụ bên dưới
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniMetric('HR Min', widget.hrMin.toInt().toString()),
              Container(width: 1, height: 24, color: AppColors.border),
              _buildMiniMetric('HR TB', hrAvg.toInt().toString()),
              Container(width: 1, height: 24, color: AppColors.border),
              _buildMiniMetric('HR Max', widget.hrMax.toInt().toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final List<Color> colors;
  final double value;

  _GaugePainter({required this.colors, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Vòng giữa nền trong suốt
    final bgPaint = Paint()
      ..color = colors.first.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 16, bgPaint);

    // Vòng ngoài cùng gradient arc
    final rect = Rect.fromCircle(center: center, radius: radius - 8);
    final arcPaint = Paint()
      ..shader = SweepGradient(colors: colors).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    // Vẽ 3/4 vòng tròn (bắt đầu từ 135 độ, kéo dài 270 độ)
    final startAngle = 135 * (math.pi / 180);
    final sweepAngle = 270 * (math.pi / 180);

    // Vẽ nền xám nhạt cho arc
    final arcBgPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcBgPaint);

    // Tính toán góc vẽ theo value (giả sử max = 200 bpm)
    final normalized = (value / 200).clamp(0.0, 1.0);
    final currentSweep = sweepAngle * normalized;
    
    // Draw outer arc
    canvas.drawArc(rect, startAngle, currentSweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.value != value;
  }
}
