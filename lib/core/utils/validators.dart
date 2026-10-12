class Validators {
  static String? requiredField(
    String? value, [
    String message = 'This field is required',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? positiveNumber(
    String? value, [
    String message = 'Enter a valid positive number',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    final num = double.tryParse(value.replaceAll(',', '').trim());
    if (num == null || num <= 0) {
      return message;
    }
    return null;
  }

  static String? nonNegativeNumber(
    String? value, [
    String message = 'Enter a valid non-negative number',
  ]) {
    if (value == null || value.trim().isEmpty) {
      return null; // allow empty if optional, or use requiredField first
    }
    final num = double.tryParse(value.replaceAll(',', '').trim());
    if (num == null || num < 0) {
      return message;
    }
    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // optional
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length < 10) {
      return 'Enter a valid phone number (at least 10 digits)';
    }
    return null;
  }
}
