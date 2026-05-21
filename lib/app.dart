import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/helpers.dart';
import 'core/widgets/animated_brand_loader.dart';
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
      child: const _HandyMarketAppView(),
    );
  }
}

class _HandyMarketAppView extends StatefulWidget {
  const _HandyMarketAppView();

  @override
  State<_HandyMarketAppView> createState() => _HandyMarketAppViewState();
}

class _HandyMarketAppViewState extends State<_HandyMarketAppView>
    with WidgetsBindingObserver {
  static const Duration _sessionTimeout = Duration(minutes: 1);
  static const String _lastInactiveAtKey = 'session_last_inactive_at';
  static const String _logoutOnNextLaunchKey = 'session_logout_on_next_launch';

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  SharedPreferences? _preferences;
  Timer? _inactivityTimer;
  AuthStatus _lastKnownStatus = AuthStatus.unknown;
  bool _isHandlingSessionExpiration = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPreferences());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authState = context.read<AuthBloc>().state;
    if (authState.status != AuthStatus.authenticated) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_restoreOrStartSession(authState));
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _inactivityTimer?.cancel();
        unawaited(_persistBackgroundState(logoutOnNextLaunch: false));
        break;
      case AppLifecycleState.detached:
        _inactivityTimer?.cancel();
        unawaited(_persistBackgroundState(logoutOnNextLaunch: true));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.message != current.message ||
          previous.feedbackType != current.feedbackType,
      listener: _handleAuthStateChanged,
      child: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (previous, current) =>
            previous.user?.themeMode != current.user?.themeMode,
        builder: (context, state) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.user?.themeMode.themeMode ?? ThemeMode.system,
            themeAnimationDuration: AppTheme.motionDuration,
            themeAnimationCurve: AppTheme.motionCurve,
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) {
              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _markUserInteraction(),
                onPointerMove: (_) => _markUserInteraction(),
                onPointerSignal: (_) => _markUserInteraction(),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _AuthGate(),
          );
        },
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    _preferences = preferences;
    await _restoreOrStartSession(context.read<AuthBloc>().state);
  }

  void _handleAuthStateChanged(BuildContext context, AuthState state) {
    final previousStatus = _lastKnownStatus;
    _lastKnownStatus = state.status;

    if (state.status == AuthStatus.authenticated) {
      _isHandlingSessionExpiration = false;
      unawaited(_restoreOrStartSession(state));
      return;
    }

    _inactivityTimer?.cancel();

    if (previousStatus == AuthStatus.authenticated) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);

      if (state.message != null && state.feedbackType != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentContext = _navigatorKey.currentContext;
          if (currentContext == null) {
            return;
          }

          Helpers.showSnackBar(
            currentContext,
            state.message!,
            isError: state.feedbackType == AuthFeedbackType.error,
          );
        });
      }
    }
  }

  Future<void> _restoreOrStartSession(AuthState state) async {
    if (!mounted || state.status != AuthStatus.authenticated) {
      return;
    }

    final preferences = _preferences;
    if (preferences == null) {
      _resetInactivityTimer();
      return;
    }

    final logoutOnNextLaunch =
        preferences.getBool(_logoutOnNextLaunchKey) ?? false;
    final lastInactiveAtMillis = preferences.getInt(_lastInactiveAtKey);
    final lastInactiveAt = lastInactiveAtMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastInactiveAtMillis);
    final expiredInBackground =
        lastInactiveAt != null &&
        DateTime.now().difference(lastInactiveAt) >= _sessionTimeout;

    await _clearPersistedSessionState();

    if (logoutOnNextLaunch) {
      _expireSession(
        'Session ended when the app was closed. Please sign in again.',
      );
      return;
    }

    if (expiredInBackground) {
      _expireSession(
        'Session expired after 1 minute away from the app. Please sign in again.',
      );
      return;
    }

    _resetInactivityTimer();
  }

  void _markUserInteraction() {
    final authState = context.read<AuthBloc>().state;
    if (authState.status != AuthStatus.authenticated) {
      return;
    }

    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_sessionTimeout, () {
      _expireSession(
        'Session expired after 1 minute of inactivity. Please sign in again.',
      );
    });
  }

  void _expireSession(String message) {
    final authState = context.read<AuthBloc>().state;
    if (authState.status != AuthStatus.authenticated ||
        _isHandlingSessionExpiration) {
      return;
    }

    _isHandlingSessionExpiration = true;
    _inactivityTimer?.cancel();
    unawaited(_clearPersistedSessionState());
    context.read<AuthBloc>().add(
      AuthSignOutRequested(
        message: message,
        feedbackType: AuthFeedbackType.error,
      ),
    );
  }

  Future<void> _persistBackgroundState({
    required bool logoutOnNextLaunch,
  }) async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }

    await preferences.setInt(
      _lastInactiveAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    if (logoutOnNextLaunch) {
      await preferences.setBool(_logoutOnNextLaunchKey, true);
      return;
    }

    await preferences.remove(_logoutOnNextLaunchKey);
  }

  Future<void> _clearPersistedSessionState() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }

    await preferences.remove(_lastInactiveAtKey);
    await preferences.remove(_logoutOnNextLaunchKey);
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  static const Duration _loaderSettleDuration = Duration(milliseconds: 220);

  AuthStatus? _displayStatus;
  Timer? _loaderSettleTimer;
  bool _loaderSpinning = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_displayStatus != null) {
      return;
    }

    final initialStatus = context.read<AuthBloc>().state.status;
    _displayStatus = initialStatus;
    _loaderSpinning = initialStatus == AuthStatus.unknown;
  }

  @override
  void dispose() {
    _loaderSettleTimer?.cancel();
    super.dispose();
  }

  void _showStatus(AuthStatus status) {
    _loaderSettleTimer?.cancel();

    if (_displayStatus == AuthStatus.unknown && status != AuthStatus.unknown) {
      setState(() {
        _loaderSpinning = false;
      });

      _loaderSettleTimer = Timer(_loaderSettleDuration, () {
        if (!mounted) {
          return;
        }

        final currentStatus = context.read<AuthBloc>().state.status;
        setState(() {
          _displayStatus = currentStatus;
          _loaderSpinning = currentStatus == AuthStatus.unknown;
        });
      });
      return;
    }

    setState(() {
      _displayStatus = status;
      _loaderSpinning = status == AuthStatus.unknown;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) => _showStatus(state.status),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final status = _displayStatus ?? state.status;
          final Widget page;
          if (status == AuthStatus.unknown) {
            page = AnimatedBrandLoader(
              message: 'Preparing ${AppStrings.appName}...',
              spinning: _loaderSpinning,
            );
          } else if (status == AuthStatus.authenticated &&
              state.status == AuthStatus.authenticated &&
              state.user != null) {
            page = const HomePage();
          } else {
            page = const LoginPage();
          }

          return AnimatedSwitcher(
            duration: AppTheme.motionDuration,
            reverseDuration: AppTheme.motionReverseDuration,
            switchInCurve: AppTheme.motionCurve,
            switchOutCurve: AppTheme.motionCurve,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: KeyedSubtree(key: ValueKey(status), child: page),
          );
        },
      ),
    );
  }
}
