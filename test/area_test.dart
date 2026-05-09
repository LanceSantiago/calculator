import 'package:flutter_test/flutter_test.dart';
import 'package:calculator/src/area.dart';
import 'package:calculator/src/length.dart';
import 'package:calculator/src/rational.dart';

Rational _r(int n, [int d = 1]) => Rational.fromInts(n, d);

void main() {
  group('AreaUnit', () {
    test('square-mm-per-unit factors are exact', () {
      expect(AreaUnit.squareMillimeter.sqMmPerUnit, _r(1));
      expect(AreaUnit.squareCentimeter.sqMmPerUnit, _r(100));
      expect(AreaUnit.squareMeter.sqMmPerUnit, _r(1000000));
      // (127/5)² = 16129/25
      expect(AreaUnit.squareInch.sqMmPerUnit, _r(16129, 25));
      // (1524/5)² = 2322576/25
      expect(AreaUnit.squareFoot.sqMmPerUnit, _r(2322576, 25));
      // (4572/5)² = 20903184/25
      expect(AreaUnit.squareYard.sqMmPerUnit, _r(20903184, 25));
    });

    test('symbols use the squared suffix', () {
      expect(AreaUnit.squareMillimeter.symbol, 'mm²');
      expect(AreaUnit.squareCentimeter.symbol, 'cm²');
      expect(AreaUnit.squareMeter.symbol, 'm²');
      expect(AreaUnit.squareInch.symbol, 'in²');
      expect(AreaUnit.squareFoot.symbol, 'ft²');
      expect(AreaUnit.squareYard.symbol, 'yd²');
    });

    test('isMetric mirrors the base length unit', () {
      expect(AreaUnit.squareMeter.isMetric, isTrue);
      expect(AreaUnit.squareFoot.isMetric, isFalse);
    });

    test('forLength maps each LengthUnit to its squared counterpart', () {
      expect(AreaUnit.forLength(LengthUnit.meter), AreaUnit.squareMeter);
      expect(AreaUnit.forLength(LengthUnit.foot), AreaUnit.squareFoot);
      expect(AreaUnit.forLength(LengthUnit.inch), AreaUnit.squareInch);
    });
  });

  group('Area construction and conversion', () {
    test('1 m² == 10 000 cm² == 1 000 000 mm²', () {
      final m2 = Area.of(_r(1), AreaUnit.squareMeter);
      final cm2 = Area.of(_r(10000), AreaUnit.squareCentimeter);
      final mm2 = Area.of(_r(1000000), AreaUnit.squareMillimeter);
      expect(m2, cm2);
      expect(cm2, mm2);
    });

    test('1 ft² == 144 in² (exact)', () {
      final ft2 = Area.of(_r(1), AreaUnit.squareFoot);
      final in2 = Area.of(_r(144), AreaUnit.squareInch);
      expect(ft2, in2);
    });

    test('valueIn converts to target unit', () {
      final a = Area.of(_r(1), AreaUnit.squareMeter);
      expect(a.valueIn(AreaUnit.squareCentimeter), _r(10000));
    });

    test('toUnit changes display unit but preserves canonical value', () {
      final a = Area.of(_r(1), AreaUnit.squareMeter);
      final b = a.toUnit(AreaUnit.squareCentimeter);
      expect(b.displayUnit, AreaUnit.squareCentimeter);
      expect(a, b);
    });
  });

  group('Area.fromLengths', () {
    test('5 m × 3 m → 15 m²', () {
      final a = Length.of(_r(5), LengthUnit.meter);
      final b = Length.of(_r(3), LengthUnit.meter);
      expect(
        Area.fromLengths(a, b),
        Area.of(_r(15), AreaUnit.squareMeter),
      );
    });

    test('10 ft × 12 ft → 120 ft²', () {
      final a = Length.of(_r(10), LengthUnit.foot);
      final b = Length.of(_r(12), LengthUnit.foot);
      expect(
        Area.fromLengths(a, b),
        Area.of(_r(120), AreaUnit.squareFoot),
      );
    });

    test('display unit follows the first operand', () {
      final a = Length.of(_r(5), LengthUnit.meter);
      final b = Length.of(_r(3), LengthUnit.foot);
      final result = Area.fromLengths(a, b);
      expect(result.displayUnit, AreaUnit.squareMeter);
    });

    test('1 m × 1 ft produces an exact rational mm²', () {
      // 1 m × 1 ft = 1000 mm × 304.8 mm = 304800 mm² = 304800/1
      final m = Length.of(_r(1), LengthUnit.meter);
      final ft = Length.of(_r(1), LengthUnit.foot);
      expect(Area.fromLengths(m, ft).squareMillimeters, _r(304800));
    });
  });

  group('Area arithmetic', () {
    test('addition preserves first display unit', () {
      final a = Area.of(_r(5), AreaUnit.squareMeter);
      final b = Area.of(_r(3), AreaUnit.squareFoot);
      final sum = a + b;
      expect(sum.displayUnit, AreaUnit.squareMeter);
    });

    test('200 ft² + 300 ft² = 500 ft²', () {
      final a = Area.of(_r(200), AreaUnit.squareFoot);
      final b = Area.of(_r(300), AreaUnit.squareFoot);
      expect(a + b, Area.of(_r(500), AreaUnit.squareFoot));
    });

    test('subtraction', () {
      final a = Area.of(_r(10), AreaUnit.squareMeter);
      final b = Area.of(_r(3), AreaUnit.squareMeter);
      expect(a - b, Area.of(_r(7), AreaUnit.squareMeter));
    });

    test('multiplication by scalar', () {
      final a = Area.of(_r(5), AreaUnit.squareMeter);
      expect(a * _r(2), Area.of(_r(10), AreaUnit.squareMeter));
    });

    test('division by scalar', () {
      final a = Area.of(_r(10), AreaUnit.squareMeter);
      expect(a / _r(2), Area.of(_r(5), AreaUnit.squareMeter));
    });

    test('unary negation', () {
      final a = Area.of(_r(5), AreaUnit.squareMeter);
      final neg = -a;
      expect(neg.squareMillimeters, _r(-5000000));
    });
  });

  group('Area equality', () {
    test('compares by canonical mm², not display unit', () {
      final a = Area.of(_r(1), AreaUnit.squareMeter);
      final b = Area.of(_r(10000), AreaUnit.squareCentimeter);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Area.format', () {
    test('whole metric area', () {
      expect(
        Area.of(_r(15), AreaUnit.squareMeter).format(),
        '15 m²',
      );
    });

    test('decimal metric area trims trailing zeros', () {
      expect(
        Area.of(_r(3, 2), AreaUnit.squareMeter).format(),
        '1.5 m²',
      );
    });

    test('imperial area renders as decimal', () {
      // 200 ft² = 200/1
      expect(
        Area.of(_r(200), AreaUnit.squareFoot).format(),
        '200 ft²',
      );
    });

    test('decimals override', () {
      // 1/3 m² ≈ 0.3333 m²
      expect(
        Area.of(_r(1, 3), AreaUnit.squareMeter).format(decimals: 2),
        '0.33 m²',
      );
    });

    test('zero', () {
      expect(
        Area.of(Rational.zero, AreaUnit.squareMeter).format(),
        '0 m²',
      );
    });

    test('negative', () {
      expect(
        Area.of(_r(-3, 2), AreaUnit.squareMeter).format(),
        '-1.5 m²',
      );
    });
  });
}
