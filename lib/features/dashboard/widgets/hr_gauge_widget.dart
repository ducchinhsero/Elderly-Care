import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// Widget vòng tròn HR lớn ở giữa dashboard
/// Có animation nhịp đập và đổi màu theo alert level
class HrGaugeWidget extends StatefulWidget {
  final double hr;
  final String alertLevel;

  const HrGaugeWidget({
    super.key,
    required this.hr,
    required this.alertLevel,
  });

  @override
  State<HrGaugeWidget> createState() => _HrGaugeWidgetState();
}

class _HrGaugeWidgetState extends State<HrGaugeWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Heartbeat pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Blink animation cho CRITICAL
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  @override
  void didUpdateWidget(covariant HrGaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alertLevel != widget.alertLevel ||
        oldWidget.hr != widget.hr) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    // Pulse animation tốc độ phụ thuộc HR
    if (widget.hr > 0) {
      final durationMs = (60000 / widget.hr).clamp(400, 2000).toInt();
      _pulseController.duration = Duration(milliseconds: durationMs);
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }

    // Blink cho CRITICAL
    if (widget.alertLevel.toUpperCase() == 'CRITICAL') {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromAlertLevel(widget.alertLevel);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _blinkAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Opacity(
              opacity: _blinkAnimation.value,
              child: _buildGauge(context, color, isDark),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGauge(BuildContext context, Color color, bool isDark) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.5, 0.8, 1.0],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          border: Border.all(color: color.withOpacity(0.4), width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _ArcPainter(
            color: color,
            progress: (widget.hr / 200).clamp(0, 1),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite,
                  color: color,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.hr > 0
                      ? widget.hr.toStringAsFixed(0)
                      : '--',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                  ),
                ),
                Text(
                  AppStrings.bpm,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.7),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppStrings.alertLevelText(widget.alertLevel),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vẽ arc xung quanh gauge
class _ArcPainter extends CustomPainter {
  final Color color;
  final double progress;

  _ArcPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
