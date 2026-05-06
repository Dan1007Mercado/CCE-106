import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';
import '../widgets/auth_form.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthBloc>().add(
      AuthPasswordResetRequested(_emailController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.message != current.message,
      listener: (context, state) {
        final message = state.message;
        if (message == null || state.feedbackType == null) {
          return;
        }

        Helpers.showSnackBar(
          context,
          message,
          isError: state.feedbackType == AuthFeedbackType.error,
        );

        if (state.feedbackType == AuthFeedbackType.success && mounted) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return AuthForm(
          title: AppStrings.forgotPasswordTitle,
          subtitle: AppStrings.forgotPasswordSubtitle,
          footer: [
            Center(
              child: TextButton(
                onPressed: state.isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text('Back to sign in'),
              ),
            ),
          ],
          children: [
            Form(
              key: _formKey,
              child: CustomTextField(
                controller: _emailController,
                label: 'Email',
                hintText: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.mark_email_read_outlined,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: AppSizes.sectionGap),
            CustomButton(
              label: 'Send reset link',
              icon: Icons.send_rounded,
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
