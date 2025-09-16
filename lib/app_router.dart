import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:subscription_manager/l10n/app_localizations.dart';

import 'package:subscription_manager/presentation/screens/home_screen.dart';
import 'package:subscription_manager/presentation/screens/add_edit_subscription_screen.dart';
import 'package:subscription_manager/presentation/screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'add',
          name: 'add',
          builder: (BuildContext context, GoRouterState state) =>
              const AddEditSubscriptionScreen(),
        ),
        GoRoute(
          path: 'settings',
          name: 'settings',
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
        GoRoute(
          path: 'edit/:id',
          name: 'edit',
          builder: (BuildContext context, GoRouterState state) {
            final id = state.pathParameters['id'];
            return AddEditSubscriptionScreen(editId: id);
          },
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context)!.navigationErrorTitle),
    ),
    body: Center(child: Text(state.error.toString())),
  ),
);
