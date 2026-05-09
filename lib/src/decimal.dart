import 'rational.dart';

/// Renders [value] as a decimal string with up to [maxDecimals] places.
///
/// Trailing zeros are trimmed. Rounds half-up; carries propagate (so
/// `0.999...` with maxDecimals=2 renders as `"1"`, not `"0.10"`).
String formatDecimal(Rational value, int maxDecimals) {
  if (value.isZero) return '0';
  final neg = value.isNegative;
  final abs = value.abs();
  var whole = abs.numerator ~/ abs.denominator;
  var remainder = abs.numerator % abs.denominator;

  if (remainder == BigInt.zero || maxDecimals == 0) {
    return (neg ? '-' : '') + whole.toString();
  }

  final digits = <int>[];
  for (var i = 0; i < maxDecimals; i++) {
    remainder *= BigInt.from(10);
    digits.add((remainder ~/ abs.denominator).toInt());
    remainder = remainder % abs.denominator;
    if (remainder == BigInt.zero) break;
  }

  if (remainder != BigInt.zero) {
    remainder *= BigInt.from(10);
    final next = (remainder ~/ abs.denominator).toInt();
    if (next >= 5) {
      var i = digits.length - 1;
      while (i >= 0) {
        if (digits[i] < 9) {
          digits[i]++;
          break;
        }
        digits[i] = 0;
        i--;
      }
      if (i < 0) {
        whole += BigInt.one;
      }
    }
  }

  while (digits.isNotEmpty && digits.last == 0) {
    digits.removeLast();
  }

  if (digits.isEmpty) {
    return (neg ? '-' : '') + whole.toString();
  }
  return '${neg ? '-' : ''}$whole.${digits.join()}';
}
