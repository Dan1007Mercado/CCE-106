import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../routes/app_router.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/service_listing_model.dart';
import '../../data/services/booking_service.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({required this.service, super.key});

  final ServiceListingModel? service;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  static const List<String> _timeSlots = [
    '08:00 AM - 10:00 AM',
    '10:00 AM - 12:00 PM',
    '01:00 PM - 03:00 PM',
    '03:00 PM - 05:00 PM',
  ];

  static const String _customTimeSlotOption = 'Custom time';

  static const List<String> _paymentMethods = [
    'Mock Wallet',
    'Test Card',
    'Cash on service',
  ];

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final BookingService _bookingService = BookingService();

  DateTime _selectedDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  String _selectedTimeSlot = _timeSlots.first;
  TimeOfDay? _customStartTime;
  TimeOfDay? _customEndTime;
  String _selectedPaymentMethod = _paymentMethods.first;
  bool _isSubmitting = false;
  bool _didPrefillAddress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthBloc>().state.user;
    if (!_didPrefillAddress && user != null) {
      _addressController.text = user.locationLabel;
      _didPrefillAddress = true;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final user = context.select((AuthBloc bloc) => bloc.state.user);
    final theme = Theme.of(context);

    if (service == null) {
      return const Scaffold(
        body: Center(child: Text('Booking details are unavailable right now.')),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: LoadingIndicator(message: 'Loading booking...')),
      );
    }

    final commission = service.price * BookingService.platformCommissionRate;
    final total = service.price + commission;
    final canBook = user.isReadyForBooking;

    return Scaffold(
      appBar: AppBar(title: const Text('Book service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BookingHero(service: service),
              const SizedBox(height: AppSizes.sectionGap),
              if (!canBook) ...[
                _ProfileRequirementCard(user: user),
                const SizedBox(height: AppSizes.sectionGap),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule and address',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(_formatDate(_selectedDate)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Available slots',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._timeSlots.map(
                            (slot) => ChoiceChip(
                              label: Text(slot),
                              selected: _selectedTimeSlot == slot,
                              onSelected: _isSubmitting
                                  ? null
                                  : (_) {
                                      setState(() {
                                        _selectedTimeSlot = slot;
                                      });
                                    },
                            ),
                          ),
                          ChoiceChip(
                            label: const Text(_customTimeSlotOption),
                            selected:
                                _selectedTimeSlot == _customTimeSlotOption,
                            onSelected: _isSubmitting
                                ? null
                                : (_) {
                                    setState(() {
                                      _selectedTimeSlot = _customTimeSlotOption;
                                    });
                                  },
                          ),
                        ],
                      ),
                      if (_selectedTimeSlot == _customTimeSlotOption) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _pickCustomTime(isStart: true),
                              icon: const Icon(Icons.schedule_rounded),
                              label: Text(
                                _customStartTime == null
                                    ? 'Start time'
                                    : 'Start ${_formatTimeOfDay(_customStartTime!)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _pickCustomTime(isStart: false),
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(
                                _customEndTime == null
                                    ? 'End time'
                                    : 'End ${_formatTimeOfDay(_customEndTime!)}',
                              ),
                            ),
                          ],
                        ),
                        if (_resolvedSelectedTimeSlot.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Selected: $_resolvedSelectedTimeSlot',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _addressController,
                        label: 'Service address',
                        hintText: 'House number, street, barangay, city',
                        prefixIcon: Icons.location_on_outlined,
                        maxLines: 2,
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hintText:
                            'Gate instructions, issue details, or tools needed',
                        prefixIcon: Icons.notes_rounded,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sectionGap),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment summary',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPaymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment method',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        items: _paymentMethods
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
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
                                  _selectedPaymentMethod = value;
                                });
                              },
                      ),
                      const SizedBox(height: 18),
                      _AmountRow(
                        label: 'Service price',
                        value: _formatCurrency(service.price),
                      ),
                      _AmountRow(
                        label: 'Platform commission (10%)',
                        value: _formatCurrency(commission),
                      ),
                      const Divider(height: 24),
                      _AmountRow(
                        label: 'Total amount',
                        value: _formatCurrency(total),
                        isTotal: true,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Mock Wallet and Test Card create a paid test payment. Cash on service records a pending payment.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sectionGap),
              CustomButton(
                label: 'Confirm & Pay',
                icon: Icons.lock_rounded,
                isLoading: _isSubmitting,
                onPressed: canBook ? () => _confirm(user, service) : null,
              ),
              if (!canBook) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          Navigator.of(
                            context,
                          ).pushNamed(AppRouter.editProfileRoute);
                        },
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Complete profile first'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateUtils.dateOnly(now.add(const Duration(days: 60))),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = DateUtils.dateOnly(picked);
    });
  }

  Future<void> _pickCustomTime({required bool isStart}) async {
    final initialTime = isStart
        ? _customStartTime ?? const TimeOfDay(hour: 8, minute: 0)
        : _customEndTime ?? const TimeOfDay(hour: 10, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _customStartTime = picked;
      } else {
        _customEndTime = picked;
      }
    });
  }

  Future<void> _confirm(UserModel user, ServiceListingModel service) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedTimeSlot = _resolvedSelectedTimeSlot;
    if (selectedTimeSlot.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Choose an available time slot.',
        isError: true,
      );
      return;
    }

    if (_selectedTimeSlot == _customTimeSlotOption && !_isCustomEndAfterStart) {
      Helpers.showSnackBar(
        context,
        'Choose a custom end time after the start time.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _bookingService.createBookingWithMockPayment(
        customer: user,
        service: service,
        selectedDate: _selectedDate,
        selectedTimeSlot: selectedTimeSlot,
        serviceAddress: _addressController.text,
        notes: _notesController.text,
        paymentMethod: _selectedPaymentMethod,
      );

      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        'Booking ${result.bookingId.substring(0, 6)} confirmed.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String get _resolvedSelectedTimeSlot {
    if (_selectedTimeSlot != _customTimeSlotOption) {
      return _selectedTimeSlot;
    }

    final startTime = _customStartTime;
    final endTime = _customEndTime;
    if (startTime == null || endTime == null) {
      return '';
    }

    return '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}';
  }

  bool get _isCustomEndAfterStart {
    final startTime = _customStartTime;
    final endTime = _customEndTime;
    if (startTime == null || endTime == null) {
      return false;
    }

    return _timeOfDayToMinutes(endTime) > _timeOfDayToMinutes(startTime);
  }

  int _timeOfDayToMinutes(TimeOfDay value) => value.hour * 60 + value.minute;
}

class _BookingHero extends StatelessWidget {
  const _BookingHero({required this.service});

  final ServiceListingModel service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              service.category,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            service.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            service.providerName,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRequirementCard extends StatelessWidget {
  const _ProfileRequirementCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking requirements',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _RequirementLine(
              isComplete: user.hasContactNumber,
              label: user.hasContactNumber
                  ? 'Phone number saved'
                  : 'Add a Philippine mobile number',
            ),
            _RequirementLine(
              isComplete: user.hasBookingLocation,
              label: user.hasBookingLocation
                  ? 'GPS location captured'
                  : 'Capture your GPS booking location',
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementLine extends StatelessWidget {
  const _RequirementLine({required this.isComplete, required this.label});

  final bool isComplete;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isComplete
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              color: isTotal ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _formatTimeOfDay(TimeOfDay value) {
  final hourOfPeriod = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hourOfPeriod:$minute $period';
}

String _formatCurrency(double value) => 'PHP ${value.toStringAsFixed(2)}';
