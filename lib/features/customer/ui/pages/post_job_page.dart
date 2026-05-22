import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/services/customer_service.dart';

class PostJobPage extends StatefulWidget {
  const PostJobPage({super.key});

  @override
  State<PostJobPage> createState() => _PostJobPageState();
}

class _PostJobPageState extends State<PostJobPage> {
  static const List<String> _categories = [
    'Electrician',
    'Masonry',
    'Plumbing',
    'Cleaning',
    'Carpentry',
  ];

  static const List<String> _difficulties = [
    'Easy',
    'Moderate',
    'Hard',
    'Expert',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final CustomerService _customerService = CustomerService();

  String _selectedCategory = _categories.first;
  String _selectedDifficulty = 'Moderate';
  double? _selectedRating;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthBloc>().state.user;
    if (user != null && _locationController.text.isEmpty) {
      _locationController.text = user.locationLabel;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    return Scaffold(
      appBar: AppBar(title: const Text('Post a job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _titleController,
                label: 'Job title',
                hintText: 'Electrician needed for kitchen outlets',
                prefixIcon: Icons.assignment_outlined,
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              CustomTextField(
                controller: _descriptionController,
                label: 'Description',
                hintText: 'Describe the work clearly for providers.',
                prefixIcon: Icons.notes_rounded,
                maxLines: 4,
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
              ),
              const SizedBox(height: AppSizes.fieldGap),
              CustomTextField(
                controller: _locationController,
                label: 'Location',
                hintText: 'Where should the provider go?',
                prefixIcon: Icons.location_on_outlined,
                maxLines: 2,
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              CustomTextField(
                controller: _budgetController,
                label: 'Budget / Offered price',
                hintText: '500',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icons.payments_outlined,
                validator: _budgetValidator,
              ),
              const SizedBox(height: AppSizes.fieldGap),
              DropdownButtonFormField<String>(
                initialValue: _selectedDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  prefixIcon: Icon(Icons.speed_rounded),
                ),
                items: _difficulties
                    .map(
                      (difficulty) => DropdownMenuItem(
                        value: difficulty,
                        child: Text(difficulty),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedDifficulty = value;
                        });
                      },
              ),
              const SizedBox(height: AppSizes.fieldGap),
              DropdownButtonFormField<double?>(
                initialValue: _selectedRating,
                decoration: const InputDecoration(
                  labelText: 'Preferred rating filter',
                  prefixIcon: Icon(Icons.star_outline_rounded),
                ),
                items: const [
                  DropdownMenuItem<double?>(
                    value: null,
                    child: Text('No preference'),
                  ),
                  DropdownMenuItem<double?>(
                    value: 3,
                    child: Text('3 stars and above'),
                  ),
                  DropdownMenuItem<double?>(
                    value: 4,
                    child: Text('4 stars and above'),
                  ),
                  DropdownMenuItem<double?>(
                    value: 4.5,
                    child: Text('4.5 stars and above'),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _selectedRating = value;
                        });
                      },
              ),
              const SizedBox(height: AppSizes.sectionGap),
              CustomButton(
                label: 'Post job',
                isLoading: _isSubmitting,
                icon: Icons.publish_rounded,
                onPressed: user == null ? null : () => _submit(user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _budgetValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a valid budget.';
    }

    return null;
  }

  Future<void> _submit(UserModel user) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _customerService.createJob(
        customer: user,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        location: _locationController.text,
        budget: double.parse(_budgetController.text.trim()),
        difficulty: _selectedDifficulty,
        ratingFilter: _selectedRating,
        photoUrl: '',
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(context, 'Successful');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      Helpers.showSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
