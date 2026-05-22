import 'package:flutter/material.dart';

import '../../../customer/ui/pages/edit_profile_page.dart';

class EditProviderProfilePage extends StatelessWidget {
  const EditProviderProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EditProfilePage(
      title: 'Edit provider profile',
      locationDescription:
          'Provider location helps customers understand your service area. You can use GPS coordinates or enter a fallback address.',
      locationUpdatedMessage:
          'Profile updated. Add a provider location so customers can verify your coverage area.',
    );
  }
}
