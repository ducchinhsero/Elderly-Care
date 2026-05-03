import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/history_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/hr_chart_widget.dart';
import 'widgets/hrv_trend_widget.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedHours = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.history),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Time range selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _TimeChip(label: AppStrings.today, hours: 24, selected: _selectedHours == 24, onTap: () => _setHours(24)),
                    const SizedBox(width: 8),
                    _TimeChip(label: AppStrings.days7, hours: 168, selected: _selectedHours == 168, onTap: () => _setHours(168)),
                    const SizedBox(width: 8),
                    _TimeChip(label: AppStrings.days30, hours: 720, selected: _selectedHours == 720, onTap: () => _setHours(720)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: AppStrings.tabHeartRate),
                  Tab(text: 'Phân bố nhịp'),
                  Tab(text: AppStrings.tabHRV),
                  Tab(text: AppStrings.tabEmotion),
                  Tab(text: AppStrings.tabActivity),
                ],
              ),
            ],
          ),
        ),
      ),
      body: historyState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                HrChartWidget(history: historyState.historyData),
                _BeatDistributionTab(history: historyState.historyData),
                HrvTrendWidget(history: historyState.historyData),
                _EmotionTab(history: historyState.historyData),
                _ActivityTab(history: historyState.historyData),
              ],
            ),
    );
  }

  void _setHours(int hours) {
    setState(() => _selectedHours = hours);
    ref.read(historyProvider.notifier).setTimeRange(hours);
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final int hours;
  final bool selected;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.hours, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.primary)),
      ),
    );
  }
}

class _BeatDistributionTab extends StatelessWidget {
  final dynamic history;
  const _BeatDistributionTab({this.history});

  @override
  Widget build(BuildContext context) {
    if (history == null || history.isEmpty) {
      return Center(child: Text(AppStrings.noData, style: TextStyle(color: AppColors.textSecondary)));
    }

    // Mock data based on history points for demo
    // In reality, this should be parsed from history.stats
    final total = history.points.length.toDouble();
    double normal = 0, fast = 0, pvc = 0, slow = 0;
    
    if (total > 0) {
      for (final p in history.points) {
        if (p.hrBpm > 100) fast++;
        else if (p.hrBpm < 50) slow++;
        else if (p.anomalyScore > 0.5) pvc++;
        else normal++;
      }
    } else {
      normal = 85; fast = 10; pvc = 5;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tỷ lệ phân bố các loại nhịp tim', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        color: AppColors.safe,
                        value: normal,
                        title: '${(normal / (normal+fast+pvc+slow) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: AppColors.alert,
                        value: fast,
                        title: '${(fast / (normal+fast+pvc+slow) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: AppColors.watch,
                        value: pvc,
                        title: '${(pvc / (normal+fast+pvc+slow) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: AppColors.primary,
                        value: slow,
                        title: '${(slow / (normal+fast+pvc+slow) * 100).toStringAsFixed(1)}%',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildLegend('Nhịp bình thường', AppColors.safe),
              const SizedBox(height: 8),
              _buildLegend('Nhịp nhanh', AppColors.alert),
              const SizedBox(height: 8),
              _buildLegend('Nhịp chậm', AppColors.primary),
              const SizedBox(height: 8),
              _buildLegend('Ngoại tâm thu (PVC)', AppColors.watch),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Tab Cảm xúc - StackedBarChart
class _EmotionTab extends StatelessWidget {
  final dynamic history;
  const _EmotionTab({this.history});

  @override
  Widget build(BuildContext context) {
    if (history == null || history.isEmpty) {
      return Center(child: Text(AppStrings.noData, style: TextStyle(color: AppColors.textSecondary)));
    }
    final stats = history.stats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phân bố cảm xúc', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  if (stats != null) ...[
                    _EmotionBar(label: AppStrings.emotionCalm, percent: stats.emotionDistribution['calm'] ?? 0, color: AppColors.calm),
                    const SizedBox(height: 8),
                    _EmotionBar(label: AppStrings.emotionStressed, percent: stats.emotionDistribution['stressed'] ?? 0, color: AppColors.stressed),
                    const SizedBox(height: 8),
                    _EmotionBar(label: AppStrings.emotionPositive, percent: stats.emotionDistribution['positive'] ?? 0, color: AppColors.positive),
                  ],
                  const SizedBox(height: 12),
                  Text('* Chỉ hiển thị dữ liệu khi nghỉ ngơi', style: TextStyle(fontSize: 11, color: AppColors.textHint, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmotionBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  const _EmotionBar({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('${percent.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: percent / 100, backgroundColor: color.withValues(alpha: 0.15), color: color, minHeight: 8),
        ),
      ],
    );
  }
}

/// Tab Hoạt động - DonutChart equivalent
class _ActivityTab extends StatelessWidget {
  final dynamic history;
  const _ActivityTab({this.history});

  @override
  Widget build(BuildContext context) {
    if (history == null || history.isEmpty) {
      return Center(child: Text(AppStrings.noData, style: TextStyle(color: AppColors.textSecondary)));
    }
    final stats = history.stats;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phân bố hoạt động', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (stats != null) ...[
                _ActivityRow(label: AppStrings.activityRest, percent: stats.activityDistribution['rest'] ?? 0, color: AppColors.rest, icon: Icons.self_improvement),
                const Divider(height: 16),
                _ActivityRow(label: AppStrings.activitySlowWalk, percent: stats.activityDistribution['slow_walk'] ?? 0, color: AppColors.slowWalk, icon: Icons.directions_walk),
                const Divider(height: 16),
                _ActivityRow(label: AppStrings.activityWalk, percent: stats.activityDistribution['walk'] ?? 0, color: AppColors.walk, icon: Icons.directions_walk),
                const Divider(height: 16),
                _ActivityRow(label: AppStrings.activityActive, percent: stats.activityDistribution['active'] ?? 0, color: AppColors.active, icon: Icons.directions_run),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final IconData icon;
  const _ActivityRow({required this.label, required this.percent, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Text('${percent.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
