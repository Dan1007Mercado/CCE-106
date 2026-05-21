import 'package:flutter_test/flutter_test.dart';
import 'package:handymarket/features/auth/data/models/user_model.dart';

void main() {
  test('maps plural services role values correctly', () {
    expect(AppUserRole.fromValue('services'), AppUserRole.service);
  });

  test('maps provider role values to service users', () {
    expect(AppUserRole.fromValue('provider'), AppUserRole.service);
  });

  test('defaults unknown role values to customer', () {
    expect(AppUserRole.fromValue('anything-else'), AppUserRole.customer);
  });
}
