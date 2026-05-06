import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';
import '../../data/models/user_model.dart';
import '../widgets/auth_form.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AppUserRole _selectedRole = AppUserRole.customer;

  List<AppUserRole> get _publicRoles => const [
    AppUserRole.customer,
    AppUserRole.service,
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        firstName: _firstNameController.text,
        middleName: _middleNameController.text,
        lastName: _lastNameController.text,
        suffix: _suffixController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.message != current.message ||
          previous.status != current.status,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        final message = state.message;
        if (message == null || state.feedbackType == null) {
          return;
        }

        Helpers.showSnackBar(
          context,
          message,
          isError: state.feedbackType == AuthFeedbackType.error,
        );
      },
      builder: (context, state) {
        return AuthForm(
          title: AppStrings.registerTitle,
          subtitle: AppStrings.registerSubtitle,
          footer: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account?'),
                TextButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _firstNameController,
                    label: 'First name',
                    hintText: 'Juan',
                    prefixIcon: Icons.person_outline_rounded,
                    autofillHints: const [AutofillHints.givenName],
                    validator: Validators.name,
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  CustomTextField(
                    controller: _middleNameController,
                    label: 'Middle name',
                    hintText: 'Optional',
                    prefixIcon: Icons.badge_outlined,
                    autofillHints: const [AutofillHints.middleName],
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  CustomTextField(
                    controller: _lastNameController,
                    label: 'Last name',
                    hintText: 'Dela Cruz',
                    prefixIcon: Icons.person_pin_outlined,
                    autofillHints: const [AutofillHints.familyName],
                    validator: Validators.name,
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  CustomTextField(
                    controller: _suffixController,
                    label: 'Suffix',
                    hintText: 'Optional: Jr, Sr, II',
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
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
                  DropdownButtonFormField<AppUserRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: _publicRoles
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.label),
                          ),
                        )
                        .toList(),
                    onChanged: state.isSubmitting
                        ? null
                        : (role) {
                            if (role == null) {
                              return;
                            }
                            setState(() {
                              _selectedRole = role;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: const Text(
                      AppStrings.adminManagedNote,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.fieldGap),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Create a password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.password,
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
                  const SizedBox(height: AppSizes.fieldGap),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm password',
                    hintText: 'Re-enter your password',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: Icons.verified_user_outlined,
                    textInputAction: TextInputAction.done,
                    validator: (value) => Validators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.fieldGap),
            CustomButton(
              label: 'Create account',
              icon: Icons.person_add_alt_1_rounded,
              isLoading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
