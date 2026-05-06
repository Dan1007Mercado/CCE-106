import 'package:flutter/material.dart';

import '../features/auth/ui/pages/forgot_password_page.dart';
import '../features/auth/ui/pages/login_page.dart';
import '../features/auth/ui/pages/register_page.dart';
import '../features/customer/data/models/service_listing_model.dart';
import '../features/customer/ui/pages/customer_profile_page.dart';
import '../features/customer/ui/pages/edit_profile_page.dart';
import '../features/customer/ui/pages/post_job_page.dart';
import '../features/customer/ui/pages/service_detail_page.dart';
import '../features/customer/ui/pages/settings_page.dart';

class AppRouter {
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String customerProfileRoute = '/customer/profile';
  static const String editProfileRoute = '/customer/profile/edit';
  static const String postJobRoute = '/customer/jobs/create';
  static const String serviceDetailRoute = '/customer/service-detail';
  static const String settingsRoute = '/customer/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case registerRoute:
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      case forgotPasswordRoute:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordPage(),
          settings: settings,
        );
      case customerProfileRoute:
        return MaterialPageRoute(
          builder: (_) => const CustomerProfilePage(),
          settings: settings,
        );
      case editProfileRoute:
        return MaterialPageRoute(
          builder: (_) => const EditProfilePage(),
          settings: settings,
        );
      case postJobRoute:
        return MaterialPageRoute(
          builder: (_) => const PostJobPage(),
          settings: settings,
        );
      case serviceDetailRoute:
        final service = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => ServiceDetailPage(
            service: service is ServiceListingModel ? service : null,
          ),
          settings: settings,
        );
      case settingsRoute:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
    }
  }
}
