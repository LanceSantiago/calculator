/// Exact rational arithmetic so that imperial fractions and metric decimals
/// can be combined without floating-point drift.
class Rational implements Comparable<Rational> {
  final BigInt numerator;
  final BigInt denominator;

  const Rational._(this.numerator, this.denominator);

  static final Rational zero = Rational._(BigInt.zero, BigInt.one);
  static final Rational one = Rational._(BigInt.one, BigInt.one);

  factory Rational(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.zero) {
      throw ArgumentError.value(denominator, 'denominator', 'must be non-zero');
    }
    if (numerator == BigInt.zero) {
      return zero;
    }
    var n = numerator;
    var d = denominator;
    if (d.isNegative) {
      n = -n;
      d = -d;
    }
    final g = n.abs().gcd(d);
    if (g != BigInt.one) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return Rational._(n, d);
  }

  factory Rational.fromInts(int numerator, int denominator) =>
      Rational(BigInt.from(numerator), BigInt.from(denominator));

  factory Rational.fromInt(int value) =>
      Rational._(BigInt.from(value), BigInt.one);

  factory Rational.parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('empty input');
    }

    // Mixed number: "2 1/2", "-3 5/8"
    final mixed = RegExp(r'^(-?\d+)\s+(\d+)/(\d+)$').firstMatch(trimmed);
    if (mixed != null) {
      final whole = BigInt.parse(mixed.group(1)!);
      final num = BigInt.parse(mixed.group(2)!);
      final den = BigInt.parse(mixed.group(3)!);
      final wholeAbs = whole.abs();
      final combined = wholeAbs * den + num;
      return Rational(whole.isNegative ? -combined : combined, den);
    }

    // Simple fraction: "1/2", "-3/4"
    final fraction = RegExp(r'^(-?\d+)/(-?\d+)$').firstMatch(trimmed);
    if (fraction != null) {
      return Rational(
        BigInt.parse(fraction.group(1)!),
        BigInt.parse(fraction.group(2)!),
      );
    }

    // Decimal: "1.5", "-0.25", "25.4"
    final decimal = RegExp(r'^(-?)(\d+)\.(\d+)$').firstMatch(trimmed);
    if (decimal != null) {
      final sign = decimal.group(1)! == '-' ? -BigInt.one : BigInt.one;
      final whole = BigInt.parse(decimal.group(2)!);
      final fracStr = decimal.group(3)!;
      final fracPart = BigInt.parse(fracStr);
      final scale = BigInt.from(10).pow(fracStr.length);
      return Rational(sign * (whole * scale + fracPart), scale);
    }

    // Whole number: "5", "-3"
    final whole = RegExp(r'^-?\d+$').firstMatch(trimmed);
    if (whole != null) {
      return Rational(BigInt.parse(trimmed), BigInt.one);
    }

    throw FormatException('not a rational number: "$input"');
  }

  Rational operator +(Rational other) => Rational(
        numerator * other.denominator + other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator -(Rational other) => Rational(
        numerator * other.denominator - other.numerator * denominator,
        denominator * other.denominator,
      );

  Rational operator *(Rational other) => Rational(
        numerator * other.numerator,
        denominator * other.denominator,
      );

  Rational operator /(Rational other) {
    if (other.isZero) {
      throw UnsupportedError('division by zero');
    }
    return Rational(
      numerator * other.denominator,
      denominator * other.numerator,
    );
  }

  Rational operator -() => Rational._(-numerator, denominator);

  @override
  int compareTo(Rational other) =>
      (numerator * other.denominator).compareTo(other.numerator * denominator);

  bool operator <(Rational other) => compareTo(other) < 0;
  bool operator <=(Rational other) => compareTo(other) <= 0;
  bool operator >(Rational other) => compareTo(other) > 0;
  bool operator >=(Rational other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator.isNegative;
  bool get isInteger => denominator == BigInt.one;

  Rational abs() => isNegative ? -this : this;

  double toDouble() => numerator / denominator;

  @override
  String toString() =>
      isInteger ? numerator.toString() : '$numerator/$denominator';
}
