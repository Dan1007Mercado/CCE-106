import 'dart:convert';

import 'package:http/http.dart' as http;

class StripeCheckoutSession {
  const StripeCheckoutSession({
    required this.sessionId,
    required this.checkoutUrl,
  });

  final String sessionId;
  final String checkoutUrl;
}

class StripeCheckoutStatus {
  const StripeCheckoutStatus({
    required this.sessionId,
    required this.status,
    required this.paymentStatus,
    this.paymentIntent,
  });

  final String sessionId;
  final String status;
  final String paymentStatus;
  final String? paymentIntent;

  bool get isPaid => status == 'complete' && paymentStatus == 'paid';
}

class StripeCheckoutService {
  StripeCheckoutService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const String _workerUrl = 'https://api.handymarket-api.workers.dev';

  Future<StripeCheckoutSession> createCheckoutSession({
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

    final data = _readJsonMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'Failed to create Stripe checkout.',
      );
    }

    final sessionId = data['sessionId']?.toString();
    final checkoutUrl = data['checkoutUrl']?.toString();

    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('Stripe checkout session ID is missing.');
    }

    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('Stripe checkout URL is missing.');
    }

    return StripeCheckoutSession(
      sessionId: sessionId,
      checkoutUrl: checkoutUrl,
    );
  }

  Future<StripeCheckoutStatus> getSessionStatus({
    required String sessionId,
  }) async {
    final response = await _client.get(
      Uri.parse(_workerUrl).replace(
        path: '/session-status',
        queryParameters: {'session_id': sessionId},
      ),
    );

    final data = _readJsonMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['error']?.toString() ?? 'Failed to fetch Stripe session status.',
      );
    }

    final responseSessionId = data['sessionId']?.toString();
    final status = data['status']?.toString();
    final paymentStatus = data['paymentStatus']?.toString();
    final paymentIntent = data['paymentIntent']?.toString();

    if (responseSessionId == null || responseSessionId.isEmpty) {
      throw Exception('Stripe session status response is missing sessionId.');
    }

    if (status == null || status.isEmpty) {
      throw Exception('Stripe session status response is missing status.');
    }

    if (paymentStatus == null || paymentStatus.isEmpty) {
      throw Exception(
        'Stripe session status response is missing paymentStatus.',
      );
    }

    return StripeCheckoutStatus(
      sessionId: responseSessionId,
      status: status,
      paymentStatus: paymentStatus,
      paymentIntent: paymentIntent,
    );
  }

  Map<String, dynamic> _readJsonMap(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {
      throw Exception('Stripe API response was not valid JSON.');
    }

    throw Exception('Stripe API response was not a JSON object.');
  }
}
