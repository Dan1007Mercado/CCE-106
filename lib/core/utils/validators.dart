class Validators {
  static final RegExp _philippinePhoneRegex = RegExp(r'^09\d{9}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    if (value.trim().length < 2) {
      return 'Enter at least 2 characters.';
    }

    return null;
  }

  static String? confirmPassword(String? value, String originalPassword) {
    final passwordError = password(value);
    if (passwordError != null) {
      return passwordError;
    }

    if (value != originalPassword) {
      return 'Passwords do not match.';
    }

    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }

    if (!_philippinePhoneRegex.hasMatch(value.trim())) {
      return 'Use the Philippine format 09XXXXXXXXX.';
    }

    return null;
  }
}
