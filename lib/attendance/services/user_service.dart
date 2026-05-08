import 'package:flutter/services.dart';
import '../models/user_model.dart';

/// INPUT FORMATTERS

class AppInputFormatters {
  static final TextInputFormatter max100 = LengthLimitingTextInputFormatter(
    100,
  );

  static final TextInputFormatter digitsOnly =
      FilteringTextInputFormatter.digitsOnly;

  static final TextInputFormatter pan = FilteringTextInputFormatter.allow(
    RegExp(r'[A-Z0-9]'),
  );

  static final TextInputFormatter ifsc = FilteringTextInputFormatter.allow(
    RegExp(r'[A-Za-z0-9]'),
  );
}

/// VALIDATORS

class AppValidators {
  static String? required(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.length != 10) {
      return 'Enter valid 10 digit number';
    }
    return null;
  }

  static String? aadhaar(String? v) {
    if (v == null || v.length != 12) {
      return 'Enter valid 12 digit Aadhaar';
    }
    return null;
  }

  static String? pan(String? v) {
    if (v == null || v.isEmpty) return 'PAN required';
    final reg = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
    if (!reg.hasMatch(v.toUpperCase())) {
      return 'Invalid PAN'; // Display error if format doesn't match
    }
    return null; // No error if valid
  }

  static String? ifsc(String? v) {
    if (v == null) return 'IFSC required';
    final reg = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!reg.hasMatch(v.toUpperCase())) {
      return 'Invalid IFSC';
    }
    return null;
  }
}

/// TEMP USER STORE

class UserStore {
  static final List<UserModel> users = [];
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
