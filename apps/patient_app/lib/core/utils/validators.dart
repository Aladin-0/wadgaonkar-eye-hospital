/// Form validation utilities with strict hospital record requirements
class Validators {
  Validators._();

  /// Validates patient's full name (at least 2 characters, letters, spaces, and periods)
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters long';
    }

    if (trimmed.length > 70) {
      return 'Name must not exceed 70 characters';
    }

    // Name should only contain letters, spaces, hyphens, and apostrophes
    final nameRegex = RegExp(r"^[a-zA-Z\s\.\'\-]+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Please enter a valid name (alphabets only)';
    }

    return null;
  }

  /// Validates standard 10-digit Indian mobile number
  static String? validateMobileNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your 10-digit mobile number';
    }

    // Remove any spaces, dashes, or +91 prefix
    String cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }

    // Indian mobile numbers start with 6, 7, 8, or 9
    final mobileRegex = RegExp(r'^[6-9]\d{9}$');
    if (!mobileRegex.hasMatch(cleaned)) {
      return 'Please enter a valid 10-digit Indian mobile number';
    }

    return null;
  }

  /// Cleans and formats phone number to standard 10 digits
  static String cleanMobileNumber(String raw) {
    String cleaned = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  /// Validates patient's age (must be an integer between 1 and 120)
  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your age';
    }

    final trimmed = value.trim();
    final age = int.tryParse(trimmed);

    if (age == null) {
      return 'Please enter a valid numeric age';
    }

    if (age < 1) {
      return 'Age must be at least 1 year';
    }

    if (age > 120) {
      return 'Please enter a realistic age (maximum 120)';
    }

    return null;
  }

  /// Validates email address (optional or required)
  static String? validateEmail(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) {
        return 'Please enter an email address';
      }
      return null;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }
}
