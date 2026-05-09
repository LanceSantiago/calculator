import 'decimal.dart';
import 'length.dart';
import 'rational.dart';

enum AreaUnit {
  squareMillimeter,
  squareCentimeter,
  squareMeter,
  squareInch,
  squareFoot,
  squareYard;

  /// Length unit whose square produces this area unit.
  LengthUnit get baseUnit {
    switch (this) {
      case AreaUnit.squareMillimeter:
        return LengthUnit.millimeter;
      case AreaUnit.squareCentimeter:
        return LengthUnit.centimeter;
      case AreaUnit.squareMeter:
        return LengthUnit.meter;
      case AreaUnit.squareInch:
        return LengthUnit.inch;
      case AreaUnit.squareFoot:
        return LengthUnit.foot;
      case AreaUnit.squareYard:
        return LengthUnit.yard;
    }
  }

  Rational get sqMmPerUnit => baseUnit.mmPerUnit * baseUnit.mmPerUnit;

  String get symbol => '${baseUnit.symbol}²';

  bool get isMetric => baseUnit.isMetric;

  /// The area unit corresponding to a given length unit.
  static AreaUnit forLength(LengthUnit unit) {
    switch (unit) {
      case LengthUnit.millimeter:
        return AreaUnit.squareMillimeter;
      case LengthUnit.centimeter:
        return AreaUnit.squareCentimeter;
      case LengthUnit.meter:
        return AreaUnit.squareMeter;
      case LengthUnit.inch:
        return AreaUnit.squareInch;
      case LengthUnit.foot:
        return AreaUnit.squareFoot;
      case LengthUnit.yard:
        return AreaUnit.squareYard;
    }
  }
}

class Area {
  final Rational squareMillimeters;
  final AreaUnit displayUnit;

  const Area._(this.squareMillimeters, this.displayUnit);

  factory Area.of(Rational value, AreaUnit unit) =>
      Area._(value * unit.sqMmPerUnit, unit);

  /// Construct an area as the product of two lengths.
  factory Area.fromLengths(Length a, Length b) => Area._(
        a.millimeters * b.millimeters,
        AreaUnit.forLength(a.displayUnit),
      );

  Rational valueIn(AreaUnit unit) => squareMillimeters / unit.sqMmPerUnit;

  Area toUnit(AreaUnit unit) => Area._(squareMillimeters, unit);

  Area operator +(Area other) =>
      Area._(squareMillimeters + other.squareMillimeters, displayUnit);

  Area operator -(Area other) =>
      Area._(squareMillimeters - other.squareMillimeters, displayUnit);

  Area operator *(Rational scalar) =>
      Area._(squareMillimeters * scalar, displayUnit);

  Area operator /(Rational scalar) =>
      Area._(squareMillimeters / scalar, displayUnit);

  Area operator -() => Area._(-squareMillimeters, displayUnit);

  @override
  bool operator ==(Object other) =>
      other is Area && squareMillimeters == other.squareMillimeters;

  @override
  int get hashCode => squareMillimeters.hashCode;

  String format({int? decimals}) {
    final value = valueIn(displayUnit);
    return '${formatDecimal(value, decimals ?? 4)} ${displayUnit.symbol}';
  }
}
