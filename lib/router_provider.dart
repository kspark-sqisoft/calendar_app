import 'package:calendar_app/getting_started.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider(
  (ref) => GoRouter(
    initialLocation: '/getting_started',
    routes: <RouteBase>[
      GoRoute(
        path: '/getting_started',
        builder: (context, state) => GettingStarted(),
      ),
    ],
  ),
);
