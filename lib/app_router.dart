// lib/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/constants/route_constants.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/todos/todos_add_screen.dart';
import 'features/todos/todos_detail_screen.dart';
import 'features/todos/todos_edit_screen.dart';
import 'features/todos/todos_screen.dart';
import 'providers/auth_provider.dart';
import 'shared/shell_scaffold.dart';

class AppRouter {
  static final _rootKey  = GlobalKey<NavigatorState>();
  static final _shellKey = GlobalKey<NavigatorState>();

  static GoRouter createRouter(AuthProvider auth) => GoRouter(
    navigatorKey: _rootKey,
    initialLocation: RouteConstants.home,
    refreshListenable: auth,
    redirect: (context, state) {
      final isAuth = auth.isAuthenticated;
      final isInit = auth.status == AuthStatus.initial ||
          auth.status == AuthStatus.loading;
      if (isInit) return null;

      final loc    = state.matchedLocation;
      final public = [RouteConstants.login, RouteConstants.register];

      if (!isAuth && !public.contains(loc)) return RouteConstants.login;
      if (isAuth  &&  public.contains(loc)) return RouteConstants.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteConstants.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, __, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: RouteConstants.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: RouteConstants.todos,
            builder: (_, __) => const TodosScreen(),
          ),
          GoRoute(
            path: RouteConstants.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RouteConstants.todosAdd,
        builder: (_, __) => const TodosAddScreen(),
      ),
      GoRoute(
        path: '/todos/:id',
        builder: (_, state) => TodosDetailScreen(
          todoId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/todos/:id/edit',
        builder: (_, state) => TodosEditScreen(
          todoId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}