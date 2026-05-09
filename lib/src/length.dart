import 'rational.dart';

enum LengthUnit {
  millimeter,
  centimeter,
  meter,
  inch,
  foot,
  yard;

  Rational get mmPerUnit {
    switch (this) {
      case LengthUnit.millimeter:
        return Rational.fromInt(1);
      case LengthUnit.centimeter:
        return Rational.fromInt(10);
      case LengthUnit.meter:
        return Rational.fromInt(1000);
      case LengthUnit.inch:
        return Rational.fromInts(127, 5); // 25.4 mm
      case LengthUnit.foot:
        return Rational.fromInts(1524, 5); // 304.8 mm
      case LengthUnit.yard:
        return Rational.fromInts(4572, 5); // 914.4 mm
    }
  }

  String get symbol {
    switch (this) {
      case LengthUnit.millimeter:
        return 'mm';
      case LengthUnit.centimeter:
        return 'cm';
      case LengthUnit.meter:
        return 'm';
      case LengthUnit.inch:
        return 'in';
      case LengthUnit.foot:
        return 'ft';
      case LengthUnit.yard:
        return 'yd';
    }
  }

  bool get isMetric =>
      this == LengthUnit.millimeter ||
      this == LengthUnit.centimeter ||
      this == LengthUnit.meter;
}

class Length {
  final Rational millimeters;
  final LengthUnit displayUnit;

  const Length._(this.millimeters, this.displayUnit);

  factory Length.of(Rational value, LengthUnit unit) =>
      Length._(value * unit.mmPerUnit, unit);

  factory Length.parse(String input, {LengthUnit defaultUnit = LengthUnit.meter}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('empty input');
    }

    // Feet-and-inches: "5'", "5' 7\"", "5' 7 1/4\"", "5'7\""
    if (trimmed.contains("'")) {
      final aposIdx = trimmed.indexOf("'");
      final feetPart = trimmed.substring(0, aposIdx).trim();
      if (feetPart.isEmpty) {
        throw FormatException('missing feet value: "$input"');
      }
      final feet = Rational.parse(feetPart);
      final feetMm = feet * LengthUnit.foot.mmPerUnit;

      final afterApos = trimmed.substring(aposIdx + 1).trim();
      if (afterApos.isEmpty) {
        return Length._(feetMm, LengthUnit.foot);
      }
      if (!afterApos.endsWith('"')) {
        throw FormatException('expected closing " on inches: "$input"');
      }
      final inchPart = afterApos.substring(0, afterApos.length - 1).trim();
      final inches = inchPart.isEmpty ? Rational.zero : Rational.parse(inchPart);
      final inchMm = inches * LengthUnit.inch.mmPerUnit;

      return Length._(feetMm + inchMm, LengthUnit.foot);
    }

    // Inch via " shorthand
    if (trimmed.endsWith('"')) {
      final numPart = trimmed.substring(0, trimmed.length - 1).trim();
      final inches = Rational.parse(numPart);
      return Length.of(inches, LengthUnit.inch);
    }

    // Look for a recognized unit symbol at the end. Multi-char units first
    // so that 'mm' isn't mis-matched as 'm'.
    final lower = trimmed.toLowerCase();
    const orderedUnits = [
      LengthUnit.millimeter,
      LengthUnit.centimeter,
      LengthUnit.inch,
      LengthUnit.foot,
      LengthUnit.yard,
      LengthUnit.meter,
    ];
    for (final unit in orderedUnits) {
      final symbol = unit.symbol;
      if (lower.endsWith(symbol)) {
        final cutoff = trimmed.length - symbol.length;
        if (cutoff == 0) {
          throw FormatException('missing number: "$input"');
        }
        final numPart = trimmed.substring(0, cutoff).trim();
        final value = Rational.parse(numPart);
        return Length.of(value, unit);
      }
    }

    // No unit found — interpret as bare number in defaultUnit
    final value = Rational.parse(trimmed);
    return Length.of(value, defaultUnit);
  }

  Rational valueIn(LengthUnit unit) => millimeters / unit.mmPerUnit;

  Length toUnit(LengthUnit unit) => Length._(millimeters, unit);

  Length operator +(Length other) =>
      Length._(millimeters + other.millimeters, displayUnit);

  Length operator -(Length other) =>
      Length._(millimeters - other.millimeters, displayUnit);

  Length operator *(Rational scalar) =>
      Length._(millimeters * scalar, displayUnit);

  Length operator /(Rational scalar) =>
      Length._(millimeters / scalar, displayUnit);

  Length operator -() => Length._(-millimeters, displayUnit);

  @override
  bool operator ==(Object other) =>
      other is Length && millimeters == other.millimeters;

  @override
  int get hashCode => millimeters.hashCode;

  String format({int? decimals, int? maxDenominator}) {
    switch (displayUnit) {
      case LengthUnit.millimeter:
      case LengthUnit.centimeter:
      case LengthUnit.meter:
      case LengthUnit.yard:
        final value = valueIn(displayUnit);
        return '${_toDecimalString(value, decimals ?? 4)} ${displayUnit.symbol}';
      case LengthUnit.inch:
        final value = valueIn(displayUnit);
        return '${_toMixedFraction(value, maxDenominator ?? 16)} ${displayUnit.symbol}';
      case LengthUnit.foot:
        return _toFeetInches(valueIn(LengthUnit.inch), maxDenominator ?? 16);
    }
  }
}

String _toDecimalString(Rational value, int maxDecimals) {
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

  // Round half-up using the next digit if we still have remainder.
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

/// Returns "5 3/4", "1/2", "7", or "0" — caller appends the unit symbol.
String _toMixedFraction(Rational value, int maxDenominator) {
  if (value.isZero) return '0';
  final neg = value.isNegative;
  final abs = value.abs();
  final maxDen = BigInt.from(maxDenominator);

  // Round (abs * maxDen) to nearest BigInt, half-up.
  final scaled = abs.numerator * maxDen;
  final twiceDen = BigInt.two * abs.denominator;
  final rounded = (BigInt.two * scaled + abs.denominator) ~/ twiceDen;

  final whole = rounded ~/ maxDen;
  final fracNum = rounded % maxDen;

  String body;
  if (fracNum == BigInt.zero) {
    body = whole.toString();
  } else {
    final g = fracNum.gcd(maxDen);
    final reducedNum = fracNum ~/ g;
    final reducedDen = maxDen ~/ g;
    if (whole == BigInt.zero) {
      body = '$reducedNum/$reducedDen';
    } else {
      body = '$whole $reducedNum/$reducedDen';
    }
  }
  return neg ? '-$body' : body;
}

/// Returns "5' 7 1/4\"" style — already includes feet/inch markers.
String _toFeetInches(Rational totalInches, int maxDenominator) {
  if (totalInches.isZero) return "0' 0\"";
  final neg = totalInches.isNegative;
  final abs = totalInches.abs();
  final maxDen = BigInt.from(maxDenominator);
  final twelveDen = BigInt.from(12) * maxDen;

  final scaled = abs.numerator * maxDen;
  final twiceDen = BigInt.two * abs.denominator;
  final sixteenths = (BigInt.two * scaled + abs.denominator) ~/ twiceDen;

  final feet = sixteenths ~/ twelveDen;
  final remaining = sixteenths - feet * twelveDen;
  final inchWhole = remaining ~/ maxDen;
  final fracNum = remaining % maxDen;

  String inchPart;
  if (fracNum == BigInt.zero) {
    inchPart = '$inchWhole"';
  } else {
    final g = fracNum.gcd(maxDen);
    final reducedNum = fracNum ~/ g;
    final reducedDen = maxDen ~/ g;
    if (inchWhole == BigInt.zero) {
      inchPart = '$reducedNum/$reducedDen"';
    } else {
      inchPart = '$inchWhole $reducedNum/$reducedDen"';
    }
  }
  final result = "$feet' $inchPart";
  return neg ? '-$result' : result;
}
