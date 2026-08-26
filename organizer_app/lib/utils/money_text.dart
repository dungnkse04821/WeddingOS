class MoneyTextException implements FormatException {
  const MoneyTextException(this.message);

  @override
  final String message;

  @override
  int? get offset => null;

  @override
  String? get source => null;

  @override
  String toString() => message;
}

class MoneyText {
  static const int _maxIntegerDigits = 13;

  static String normalize(String input, {bool allowZero = false}) {
    final value = input.trim();
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value);
    if (match == null) {
      throw const MoneyTextException(
        'Số tiền phải dùng dấu chấm và có tối đa 2 chữ số thập phân.',
      );
    }

    final integerPart = match.group(1)!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integerPart.length > _maxIntegerDigits) {
      throw const MoneyTextException('Số tiền vượt quá giới hạn cho phép.');
    }

    final fractionPart = (match.group(2) ?? '').padRight(2, '0');
    final isZero =
        RegExp(r'^0+$').hasMatch(integerPart) &&
        RegExp(r'^0+$').hasMatch(fractionPart);
    if (isZero && !allowZero) {
      throw const MoneyTextException('Số tiền phải lớn hơn 0.');
    }

    return '$integerPart.$fractionPart';
  }

  static String? normalizeOptional(String? input, {bool allowZero = false}) {
    if (input == null || input.trim().isEmpty) return null;
    return normalize(input, allowZero: allowZero);
  }

  static String? validate(
    String? input, {
    bool allowZero = false,
    bool optional = false,
  }) {
    if (input == null || input.trim().isEmpty) {
      return optional ? null : 'Bắt buộc nhập';
    }
    try {
      normalize(input, allowZero: allowZero);
      return null;
    } on MoneyTextException catch (error) {
      return error.message;
    }
  }
}
