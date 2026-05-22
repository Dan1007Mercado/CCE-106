import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/admin/ui/pages/admin_dashboard_page.dart';
import '../features/auth/ui/pages/forgot_password_page.dart';
import '../features/auth/ui/pages/login_page.dart';
import '../features/auth/ui/pages/register_page.dart';
import '../features/chat/ui/pages/chat_page.dart';
import '../features/customer/data/models/service_listing_model.dart';
import '../features/customer/ui/pages/booking_page.dart';
import '../features/customer/ui/pages/customer_profile_page.dart';
import '../features/customer/ui/pages/edit_profile_page.dart';
import '../features/customer/ui/pages/post_job_page.dart';
import '../features/customer/ui/pages/service_detail_page.dart';
import '../features/customer/ui/pages/settings_page.dart';
import '../features/provider/ui/pages/provider_dashboard_page.dart';
import '../features/provider/ui/pages/edit_provider_profile_page.dart';
import '../features/provider/ui/pages/provider_profile_page.dart';

class AppRouter {
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String customerProfileRoute = '/customer/profile';
  static const String editProfileRoute = '/customer/profile/edit';
  static const String postJobRoute = '/customer/jobs/create';
  static const String serviceDetailRoute = '/customer/service-detail';
  static const String bookingRoute = '/customer/booking';
  static const String settingsRoute = '/customer/settings';
  static const String chatRoute = '/chat';
  static const String providerDashboardRoute = '/provider/dashboard';
  static const String providerProfileRoute = '/provider/profile';
  static const String editProviderProfileRoute = '/provider/profile/edit';
  static const String adminDashboardRoute = '/admin/dashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case registerRoute:
        return _AppPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      case forgotPasswordRoute:
        return _AppPageRoute(
          builder: (_) => const ForgotPasswordPage(),
          settings: settings,
        );
      case customerProfileRoute:
        return _AppPageRoute(
          builder: (_) => const CustomerProfilePage(),
          settings: settings,
        );
      case editProfileRoute:
        return _AppPageRoute(
          builder: (_) => const EditProfilePage(),
          settings: settings,
        );
      case postJobRoute:
        return _AppPageRoute(
          builder: (_) => const PostJobPage(),
          settings: settings,
        );
      case serviceDetailRoute:
        final service = settings.arguments;
        return _AppPageRoute(
          builder: (_) => ServiceDetailPage(
            service: service is ServiceListingModel ? service : null,
          ),
          settings: settings,
        );
      case bookingRoute:
        final args = settings.arguments;
        final service = args is BookingPageArgs
            ? args.service
            : args is ServiceListingModel
            ? args
            : null;
        return _AppPageRoute(
          builder: (_) => BookingPage(
            service: service,
            jobId: args is BookingPageArgs ? args.jobId : null,
            difficulty: args is BookingPageArgs ? args.difficulty : null,
          ),
          settings: settings,
        );
      case settingsRoute:
        return _AppPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );
      case chatRoute:
        final args = settings.arguments;
        return _AppPageRoute(
          builder: (_) => ChatPage(args: args is ChatPageArgs ? args : null),
          settings: settings,
        );
      case providerDashboardRoute:
        return _AppPageRoute(
          builder: (_) => const ProviderDashboardPage(),
          settings: settings,
        );
      case providerProfileRoute:
        return _AppPageRoute(
          builder: (_) => const ProviderProfilePage(),
          settings: settings,
        );
      case editProviderProfileRoute:
        return _AppPageRoute(
          builder: (_) => const EditProviderProfilePage(),
          settings: settings,
        );
      case adminDashboardRoute:
        return _AppPageRoute(
          builder: (_) => const AdminDashboardPage(),
          settings: settings,
        );
      default:
        return _AppPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
    }
  }
}

class _AppPageRoute<T> extends PageRouteBuilder<T> {
  _AppPageRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) : super(
         settings: settings,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: AppTheme.motionDuration,
         reverseTransitionDuration: AppTheme.motionReverseDuration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final fade = CurvedAnimation(
             parent: animation,
             curve: AppTheme.motionCurve,
           );
           final slide = Tween<Offset>(
             begin: const Offset(0, 0.035),
             end: Offset.zero,
           ).animate(fade);

           return FadeTransition(
             opacity: fade,
             child: SlideTransition(position: slide, child: child),
           );
         },
       );
}
