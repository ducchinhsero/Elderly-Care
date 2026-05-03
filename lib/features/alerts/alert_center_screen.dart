import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/alerts_provider.dart';
import '../../core/models/alert_model.dart';
import 'widgets/alert_item_widget.dart';

class AlertCenterScreen extends ConsumerStatefulWidget {
  const AlertCenterScreen({super.key});

  @override
  ConsumerState<AlertCenterScreen> createState() => _AlertCenterScreenState();
}

class _AlertCenterScreenState extends ConsumerState<AlertCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alertsState = ref.watch(alertsProvider);
    final notifier = ref.read(alertsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(AppStrings.alertCenter),
            if (alertsState.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.critical, borderRadius: BorderRadius.circular(12)),
                child: Text('${alertsState.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        actions: [
          if (alertsState.unreadCount > 0)
            TextButton(onPressed: () => notifier.markAllAsRead(), child: const Text('Đọc hết', style: TextStyle(fontSize: 13))),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: AppStrings.tabNew),
            Tab(text: AppStrings.tabToday),
            Tab(text: AppStrings.tab7Days),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertList(notifier.getNewAlerts(), alertsState.isLoading),
          _buildAlertList(notifier.getTodayAlerts(), alertsState.isLoading),
          _buildAlertList(notifier.getLast7DaysAlerts(), alertsState.isLoading),
        ],
      ),
    );
  }

  Widget _buildAlertList(List<AlertModel> alerts, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.safe.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(AppStrings.noAlerts, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(AppStrings.noAlertsDesc, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(alertsProvider.notifier).loadAlerts(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Dismissible(
            key: Key(alert.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: AppColors.safe,
              child: const Icon(Icons.check, color: Colors.white),
            ),
            onDismissed: (_) => ref.read(alertsProvider.notifier).markAsRead(alert.id),
            child: AlertItemWidget(alert: alert),
          );
        },
      ),
    );
  }
}
