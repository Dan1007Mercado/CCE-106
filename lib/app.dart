import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/loading_indicator.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/auth/data/services/auth_service.dart';
import 'features/auth/ui/pages/login_page.dart';
import 'features/home/ui/pages/home_page.dart';
import 'routes/app_router.dart';

class HandyMarketApp extends StatelessWidget {
  const HandyMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AuthBloc(authRepository: AuthRepository(authService: AuthService()))
            ..add(const AuthStarted()),
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, current) =>
            previous.user?.themeMode != current.user?.themeMode,
        builder: (context, state) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.user?.themeMode.themeMode ?? ThemeMode.system,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.unknown) {
          return const Scaffold(
            body: Center(
              child: LoadingIndicator(message: 'Checking your account...'),
            ),
          );
        }

        if (state.status == AuthStatus.authenticated && state.user != null) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}
