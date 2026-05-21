import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../admin/ui/pages/admin_dashboard_page.dart';
import '../../../customer/ui/pages/customer_dashboard_page.dart';
import '../../../provider/ui/pages/provider_dashboard_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: LoadingIndicator(message: 'Loading your dashboard...'),
        ),
      );
    }

    switch (user.role) {
      case AppUserRole.admin:
        return const AdminDashboardPage();
      case AppUserRole.service:
        return const ProviderDashboardPage();
      case AppUserRole.customer:
        return const CustomerDashboardPage();
    }
  }
}
