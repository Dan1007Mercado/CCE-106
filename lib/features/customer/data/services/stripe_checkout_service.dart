import 'dart:convert';

import 'package:http/http.dart' as http;

class StripeCheckoutService {
  StripeCheckoutService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _workerUrl = 'https://api.handymarket-api.workers.dev';

  Future<String> createCheckoutSession({
    required String bookingId,
    required String paymentId,
    required String serviceTitle,
    required String customerEmail,
    required double amount,
  }) async {
    final response = await _client.post(
      Uri.parse(_workerUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bookingId': bookingId,
        'paymentId': paymentId,
        'serviceTitle': serviceTitle,
        'customerEmail': customerEmail,
        'amount': amount,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'Failed to create Stripe checkout.',
      );
    }

    final checkoutUrl = data['checkoutUrl']?.toString();

    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('Stripe checkout URL is missing.');
    }

    return checkoutUrl;
  }
}
