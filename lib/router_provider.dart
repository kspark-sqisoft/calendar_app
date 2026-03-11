import 'package:calendar_app/calendar/calendar_page.dart';
import 'package:calendar_app/creta/creta_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider(
  (ref) => GoRouter(
    initialLocation: '/calendar',
    redirect: (context, state) {
      if (state.matchedLocation == '/') return '/calendar';
      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => _MainScaffold(
          currentLocation: state.matchedLocation,
          child: child,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CalendarPage(),
            ),
          ),
          GoRoute(
            path: '/creta',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CretaPage(),
            ),
          ),
        ],
      ),
    ],
  ),
);

class _MainScaffold extends StatelessWidget {
  const _MainScaffold({
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  int get _currentIndex => currentLocation == '/creta' ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          final path = index == 0 ? '/calendar' : '/creta';
          if (currentLocation != path) context.go(path);
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush_outlined),
            label: 'Creta',
          ),
        ],
      ),
    );
  }
}
