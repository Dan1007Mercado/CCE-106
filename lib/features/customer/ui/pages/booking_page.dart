import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/service_listing_model.dart';
import '../../data/services/booking_service.dart';

class BookingPageArgs {
  const BookingPageArgs({required this.service, this.jobId, this.difficulty});

  final ServiceListingModel service;
  final String? jobId;
  final String? difficulty;
}

class BookingPage extends StatefulWidget {
  const BookingPage({
    required this.service,
    super.key,
    this.jobId,
    this.difficulty,
  });

  final ServiceListingModel? service;
  final String? jobId;
  final String? difficulty;

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
  static const int _serviceStartMinute = 6 * 60;
  static const int _serviceEndMinute = 18 * 60;

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
    final difficulty = _bookingDifficulty;
    final minimumDuration = _minimumDurationMinutes;

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
                      const SizedBox(height: 10),
                      _DifficultySummary(
                        difficulty: difficulty,
                        minimumDurationMinutes: minimumDuration,
                        hasJobContext: _jobId.isNotEmpty,
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
                      const SizedBox(height: 6),
                      Text(
                        'Minimum duration for $difficulty jobs: ${_formatDuration(minimumDuration)}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
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
                        Text(
                          'Service visit hours: 6:00 AM - 6:00 PM',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                            'Selected: $_resolvedSelectedTimeSlot (${_formatDuration(_resolvedScheduleRange?.durationMinutes ?? 0)})',
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
                        hintText:
                            'House No. optional, street, barangay, city, region',
                        prefixIcon: Icons.location_on_outlined,
                        validator: _addressValidator,
                      ),
                      const SizedBox(height: AppSizes.fieldGap),
                      CustomTextField(
                        controller: _notesController,
                        label: 'Notes',
                        hintText: 'Optional instructions',
                        prefixIcon: Icons.notes_rounded,
                        minLines: 1,
                        maxLines: 3,
                        alignPrefixIconToTop: true,
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
                        'Payment will stay pending until the provider marks the service as done. If you cancel before completion, a 3% provider fee and 1% platform fee may apply.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.72,
                          ),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AmountRow(
                        label: 'Payment status',
                        value: 'Pending until completed',
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
                onPressed: () => _confirm(user, service),
              ),
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
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedTimeSlot = _resolvedSelectedTimeSlot;
    final scheduleRange = _resolvedScheduleRange;
    if (selectedTimeSlot.isEmpty || scheduleRange == null) {
      Helpers.showSnackBar(
        context,
        'Choose an available time slot.',
        isError: true,
      );
      return;
    }

    final scheduleError = _validateScheduleRange(scheduleRange);
    if (scheduleError != null) {
      Helpers.showSnackBar(context, scheduleError, isError: true);
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
        startAt: scheduleRange.startAt,
        endAt: scheduleRange.endAt,
        durationMinutes: scheduleRange.durationMinutes,
        serviceAddress: _addressController.text,
        notes: _notesController.text,
        paymentMethod: _selectedPaymentMethod,
        jobId: _jobId.isEmpty ? null : _jobId,
        difficulty: _bookingDifficulty,
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

  String? _addressValidator(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter the service address.';
    }

    final parts = text
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 4) {
      return 'Include street, barangay, city, and region.';
    }

    return null;
  }

  String get _resolvedSelectedTimeSlot {
    final range = _resolvedScheduleRange;
    return range?.label ?? '';
  }

  _ScheduleRange? get _resolvedScheduleRange {
    if (_selectedTimeSlot != _customTimeSlotOption) {
      return _scheduleRangeFromSlot(_selectedTimeSlot);
    }

    final startTime = _customStartTime;
    final endTime = _customEndTime;
    if (startTime == null || endTime == null) {
      return null;
    }

    final startMinutes = _timeOfDayToMinutes(startTime);
    final endMinutes = _timeOfDayToMinutes(endTime);
    return _scheduleRangeFromMinutes(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      label: '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}',
    );
  }

  String get _jobId => widget.jobId?.trim() ?? '';

  String get _bookingDifficulty {
    final cleaned = widget.difficulty?.trim() ?? '';
    switch (cleaned.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'hard':
        return 'Hard';
      case 'expert':
        return 'Expert';
      case 'moderate':
      default:
        return 'Moderate';
    }
  }

  int get _minimumDurationMinutes =>
      BookingService.minimumDurationForDifficulty(_bookingDifficulty);

  _ScheduleRange? _scheduleRangeFromSlot(String slot) {
    final parts = slot.split(' - ');
    if (parts.length != 2) {
      return null;
    }

    final startMinutes = _parseClockMinutes(parts[0]);
    final endMinutes = _parseClockMinutes(parts[1]);
    if (startMinutes == null || endMinutes == null) {
      return null;
    }

    return _scheduleRangeFromMinutes(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      label: slot,
    );
  }

  _ScheduleRange _scheduleRangeFromMinutes({
    required int startMinutes,
    required int endMinutes,
    required String label,
  }) {
    final startAt = _dateAtMinutes(_selectedDate, startMinutes);
    final endAt = _dateAtMinutes(_selectedDate, endMinutes);
    return _ScheduleRange(
      startAt: startAt,
      endAt: endAt,
      durationMinutes: endMinutes - startMinutes,
      label: label,
    );
  }

  String? _validateScheduleRange(_ScheduleRange range) {
    final startMinutes = range.startAt.hour * 60 + range.startAt.minute;
    final endMinutes = range.endAt.hour * 60 + range.endAt.minute;

    if (range.durationMinutes <= 0) {
      return 'End time must be later than start time.';
    }

    if (startMinutes < _serviceStartMinute || endMinutes > _serviceEndMinute) {
      return 'Service visits are only allowed from 6:00 AM to 6:00 PM.';
    }

    if (range.durationMinutes < _minimumDurationMinutes) {
      return '$_bookingDifficulty bookings must be at least ${_formatDuration(_minimumDurationMinutes)}.';
    }

    return null;
  }

  int _timeOfDayToMinutes(TimeOfDay value) => value.hour * 60 + value.minute;

  int? _parseClockMinutes(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) {
      return null;
    }

    final rawHour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final period = match.group(3)?.toUpperCase();
    if (rawHour == null ||
        minute == null ||
        rawHour < 1 ||
        rawHour > 12 ||
        minute < 0 ||
        minute > 59 ||
        period == null) {
      return null;
    }

    var hour = rawHour % 12;
    if (period == 'PM') {
      hour += 12;
    }

    return hour * 60 + minute;
  }

  DateTime _dateAtMinutes(DateTime date, int minutes) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }
}

class _ScheduleRange {
  const _ScheduleRange({
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.label,
  });

  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final String label;
}

class _DifficultySummary extends StatelessWidget {
  const _DifficultySummary({
    required this.difficulty,
    required this.minimumDurationMinutes,
    required this.hasJobContext,
  });

  final String difficulty;
  final int minimumDurationMinutes;
  final bool hasJobContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        hasJobContext
            ? 'Difficulty: $difficulty. Minimum visit duration is ${_formatDuration(minimumDurationMinutes)}.'
            : 'Difficulty defaults to $difficulty. Minimum visit duration is ${_formatDuration(minimumDurationMinutes)}.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
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

String _formatDuration(int minutes) {
  if (minutes <= 0) {
    return '0 minutes';
  }

  if (minutes % 60 == 0) {
    final hours = minutes ~/ 60;
    return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) {
    return '$remainingMinutes minutes';
  }

  return '$hours hr $remainingMinutes min';
}

String _formatCurrency(double value) => 'PHP ${value.toStringAsFixed(2)}';
