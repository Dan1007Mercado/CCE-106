import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../routes/app_router.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';
import '../widgets/auth_form.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.feedbackType != current.feedbackType ||
          previous.message != current.message,
      listener: (context, state) {
        if (state.feedbackType == null) {
          return;
        }

        if (state.feedbackType == AuthFeedbackType.success) {
          return;
        }

        Helpers.showSnackBar(
          context,
          state.message ?? 'Incorrect email or password.',
          isError: true,
        );
      },
      builder: (context, state) {
        return AuthForm(
          title: AppStrings.loginTitle,
          subtitle: AppStrings.loginSubtitle,
          footer: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New to Local Services?'),
                TextButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.registerRoute);
                        },
                  child: const Text('Create account'),
                ),
              ],
            ),
          ],
          children: [
            AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                      autofillHints: const [AutofillHints.email],
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppSizes.fieldGap),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'Enter your password',
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_outline_rounded,
                      autofillHints: const [AutofillHints.password],
                      validator: Validators.password,
                      onFieldSubmitted: (_) => _submit(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: state.isSubmitting
                    ? null
                    : () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.forgotPasswordRoute);
                      },
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomButton(
              label: 'Log in',
              icon: Icons.login_rounded,
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
