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
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      return 'Enter a valid phone number (at least 10 digits)';
    }

    // Check Pakistani mobile format if starting with 03, 923, or 00923
    String pakMobile = '';
    if (digits.startsWith('03') && digits.length == 11) {
      pakMobile = digits;
    } else if (digits.startsWith('923') && digits.length == 12) {
      pakMobile = '0${digits.substring(2)}';
    } else if (digits.startsWith('00923') && digits.length == 14) {
      pakMobile = '0${digits.substring(4)}';
    }

    if (pakMobile.isNotEmpty) {
      final prefix = int.tryParse(pakMobile.substring(1, 4));
      final isValidPrefix = prefix != null &&
          ((prefix >= 300 && prefix <= 349) || prefix == 355);
      if (!isValidPrefix) {
        return 'موبائل کوڈ 0${prefix ?? ''} درست نہیں ہے (درست پاکستانی کوڈ: 0300 تا 0349 یا 0355)';
      }
    }

    return null;
  }
}
