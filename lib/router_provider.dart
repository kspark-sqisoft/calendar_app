import 'package:calendar_app/calendar/calendar_page.dart';
import 'package:calendar_app/creta/creta_page.dart';
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
                  return NoTransitionPage(
                    child: CalendarPage(planId: planId),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/creta',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CretaPage()),
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

  int get _currentIndex =>
      currentLocation.startsWith('/creta') ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          final path = index == 0 ? '/plans' : '/creta';
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
        ],
      ),
    );
  }
}
