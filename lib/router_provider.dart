import 'package:calendar_app/calendar/calendar_page.dart';
import 'package:calendar_app/creta/creta_page.dart';
import 'package:calendar_app/device/device_page.dart';
import 'package:calendar_app/mycalendar/my_calendar_page.dart';
import 'package:calendar_app/plan/plan_list_page.dart';
import 'package:calendar_app/plan/plan_new_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider(
  (ref) => GoRouter(
    initialLocation: '/plans',
    redirect: (context, state) {
      if (state.matchedLocation == '/') return '/plans';
      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) =>
            _MainScaffold(currentLocation: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/plans',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: PlanListPage()),
            routes: <RouteBase>[
              GoRoute(
                path: 'new',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: PlanNewPage()),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id']!;
                  final planId = int.tryParse(id) ?? 1;
                  return NoTransitionPage(child: CalendarPage(planId: planId));
                },
              ),
            ],
          ),
          GoRoute(
            path: '/creta',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CretaPage()),
          ),
          GoRoute(
            path: '/devices',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DevicePage()),
          ),
          GoRoute(
            path: '/mycalendar',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MyCalendarPage()),
          ),
        ],
      ),
    ],
  ),
);

class _MainScaffold extends StatelessWidget {
  const _MainScaffold({required this.currentLocation, required this.child});

  final String currentLocation;
  final Widget child;

  int get _currentIndex {
    if (currentLocation.startsWith('/creta')) return 1;
    if (currentLocation.startsWith('/devices')) return 2;
    if (currentLocation.startsWith('/mycalendar')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (int index) {
          final path = switch (index) {
            0 => '/plans',
            1 => '/creta',
            2 => '/devices',
            3 => '/mycalendar',
            _ => '/plans',
          };
          if (currentLocation != path) context.go(path);
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '방송계획',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush_outlined),
            label: '크레타북',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: '디바이스'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '내 캘린더',
          ),
        ],
      ),
    );
  }
}
