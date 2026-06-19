import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/onboarding/role_selection_screen.dart';
import '../features/onboarding/remote_setup_screen.dart';
import '../features/onboarding/wifi_provisioning_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/alerts/alert_center_screen.dart';
import '../features/history/history_screen.dart';
import '../features/report/health_report_screen.dart';
import '../features/reports/daily_report_screen.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/settings/settings_screen.dart';

/// App shell với bottom navigation
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Cảnh báo',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment),
            label: 'Báo cáo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}

/// Tạo GoRouter — nhận initialLocation dựa vào onboarding state
GoRouter createAppRouter({required bool onboardingCompleted}) {
  return GoRouter(
    initialLocation: onboardingCompleted ? '/dashboard' : '/role-selection',
    routes: [
      // ── Onboarding routes ──
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/setup-remote',
        builder: (context, state) => const RemoteSetupScreen(),
      ),
      GoRoute(
        path: '/wifi-setup',
        builder: (context, state) => const WifiProvisioningScreen(),
      ),

      // ── Main app (bottom navigation shell) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Alerts
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                builder: (context, state) => const AlertCenterScreen(),
              ),
            ],
          ),
          // History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          // Report
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/report',
                builder: (context, state) => const HealthReportScreen(),
              ),
            ],
          ),
          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const UserProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Settings (full-screen, not in bottom nav)
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      // Daily statistical report (full-screen, opened from the Report tab)
      GoRoute(
        path: '/daily-report',
        builder: (context, state) => const DailyReportScreen(),
      ),
    ],
  );
}
