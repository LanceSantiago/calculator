import 'package:flutter_test/flutter_test.dart';
import 'package:calculator/src/length.dart';
import 'package:calculator/src/rational.dart';

Rational _r(int n, [int d = 1]) => Rational.fromInts(n, d);

void main() {
  group('LengthUnit', () {
    test('millimetres-per-unit factors are exact', () {
      expect(LengthUnit.millimeter.mmPerUnit, _r(1));
      expect(LengthUnit.centimeter.mmPerUnit, _r(10));
      expect(LengthUnit.meter.mmPerUnit, _r(1000));
      expect(LengthUnit.inch.mmPerUnit, _r(127, 5)); // 25.4
      expect(LengthUnit.foot.mmPerUnit, _r(1524, 5)); // 304.8
      expect(LengthUnit.yard.mmPerUnit, _r(4572, 5)); // 914.4
    });

    test('symbols', () {
      expect(LengthUnit.millimeter.symbol, 'mm');
      expect(LengthUnit.centimeter.symbol, 'cm');
      expect(LengthUnit.meter.symbol, 'm');
      expect(LengthUnit.inch.symbol, 'in');
      expect(LengthUnit.foot.symbol, 'ft');
      expect(LengthUnit.yard.symbol, 'yd');
    });

    test('isMetric flag', () {
      expect(LengthUnit.millimeter.isMetric, isTrue);
      expect(LengthUnit.centimeter.isMetric, isTrue);
      expect(LengthUnit.meter.isMetric, isTrue);
      expect(LengthUnit.inch.isMetric, isFalse);
      expect(LengthUnit.foot.isMetric, isFalse);
      expect(LengthUnit.yard.isMetric, isFalse);
    });
  });

  group('Length construction and conversion', () {
    test('Length.of stores canonical millimetres', () {
      final a = Length.of(_r(1), LengthUnit.meter);
      expect(a.millimeters, _r(1000));
      expect(a.displayUnit, LengthUnit.meter);
    });

    test('1 m == 100 cm == 1000 mm', () {
      final m = Length.of(_r(1), LengthUnit.meter);
      final cm = Length.of(_r(100), LengthUnit.centimeter);
      final mm = Length.of(_r(1000), LengthUnit.millimeter);
      expect(m, cm);
      expect(cm, mm);
    });

    test('1 in == 25.4 mm exactly', () {
      final inch = Length.of(_r(1), LengthUnit.inch);
      expect(inch.millimeters, _r(127, 5));
    });

    test('1 ft == 12 in', () {
      final ft = Length.of(_r(1), LengthUnit.foot);
      final twelveIn = Length.of(_r(12), LengthUnit.inch);
      expect(ft, twelveIn);
    });

    test('1 yd == 3 ft == 36 in', () {
      final yd = Length.of(_r(1), LengthUnit.yard);
      final ft = Length.of(_r(3), LengthUnit.foot);
      final inch = Length.of(_r(36), LengthUnit.inch);
      expect(yd, ft);
      expect(ft, inch);
    });

    test('valueIn converts to target unit', () {
      final m = Length.of(_r(1), LengthUnit.meter);
      expect(m.valueIn(LengthUnit.millimeter), _r(1000));
      expect(m.valueIn(LengthUnit.centimeter), _r(100));
      expect(m.valueIn(LengthUnit.meter), _r(1));
    });

    test('toUnit changes display unit but preserves canonical value', () {
      final inMeters = Length.of(_r(1), LengthUnit.meter);
      final inCm = inMeters.toUnit(LengthUnit.centimeter);
      expect(inCm.displayUnit, LengthUnit.centimeter);
      expect(inCm.millimeters, _r(1000));
      expect(inCm, inMeters);
    });
  });

  group('Length arithmetic', () {
    test('addition preserves first display unit', () {
      final m = Length.of(_r(1), LengthUnit.meter);
      final inch = Length.of(_r(3), LengthUnit.inch);
      final sum = m + inch;
      expect(sum.displayUnit, LengthUnit.meter);
    });

    test('1 m + 3 in - 4 cm produces the expected canonical mm', () {
      final m = Length.of(_r(1), LengthUnit.meter);
      final inch = Length.of(_r(3), LengthUnit.inch);
      final cm = Length.of(_r(4), LengthUnit.centimeter);
      final result = m + inch - cm;
      // 1000 + 3*25.4 - 40 = 1036.2 mm = 5181/5
      expect(result.millimeters, _r(5181, 5));
      expect(result.displayUnit, LengthUnit.meter);
    });

    test('1/3 in + 1/3 in + 1/3 in == 1 in (no float drift)', () {
      final third = Length.of(_r(1, 3), LengthUnit.inch);
      final sum = third + third + third;
      expect(sum, Length.of(_r(1), LengthUnit.inch));
    });

    test('subtraction', () {
      final a = Length.of(_r(5), LengthUnit.meter);
      final b = Length.of(_r(2), LengthUnit.meter);
      expect(a - b, Length.of(_r(3), LengthUnit.meter));
    });

    test('multiplication by scalar', () {
      final a = Length.of(_r(3), LengthUnit.meter);
      expect(a * _r(2), Length.of(_r(6), LengthUnit.meter));
      expect(a * _r(1, 2), Length.of(_r(3, 2), LengthUnit.meter));
    });

    test('division by scalar', () {
      final a = Length.of(_r(6), LengthUnit.meter);
      expect(a / _r(2), Length.of(_r(3), LengthUnit.meter));
    });

    test('unary negation', () {
      final a = Length.of(_r(3), LengthUnit.meter);
      final neg = -a;
      expect(neg.millimeters, _r(-3000));
      expect(neg.displayUnit, LengthUnit.meter);
    });
  });

  group('Length equality', () {
    test('equality compares canonical mm not display unit', () {
      final a = Length.of(_r(100), LengthUnit.centimeter);
      final b = Length.of(_r(1), LengthUnit.meter);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different magnitudes are unequal', () {
      final a = Length.of(_r(1), LengthUnit.meter);
      final b = Length.of(_r(2), LengthUnit.meter);
      expect(a == b, isFalse);
    });
  });

  group('Length.parse', () {
    test('whole number with default unit', () {
      expect(
        Length.parse('5', defaultUnit: LengthUnit.meter),
        Length.of(_r(5), LengthUnit.meter),
      );
    });

    test('decimal with unit symbol', () {
      expect(Length.parse('1.5 m'), Length.of(_r(3, 2), LengthUnit.meter));
      expect(Length.parse('25.4 mm'), Length.of(_r(127, 5), LengthUnit.millimeter));
    });

    test('no space between number and unit', () {
      expect(Length.parse('5cm'), Length.of(_r(5), LengthUnit.centimeter));
    });

    test('simple fraction with unit', () {
      expect(Length.parse('1/2 in'), Length.of(_r(1, 2), LengthUnit.inch));
    });

    test('mixed number with unit', () {
      expect(Length.parse('5 3/4 in'), Length.of(_r(23, 4), LengthUnit.inch));
    });

    test('inch via double-quote shorthand', () {
      expect(Length.parse('7"'), Length.of(_r(7), LengthUnit.inch));
      expect(Length.parse('1/2"'), Length.of(_r(1, 2), LengthUnit.inch));
    });

    test('foot via apostrophe shorthand', () {
      expect(Length.parse("5'"), Length.of(_r(5), LengthUnit.foot));
    });

    test('feet-and-inches notation', () {
      // 5' 7 1/4" = 5*12 + 7.25 = 67.25 in = 269/4 in
      expect(
        Length.parse('5\' 7 1/4"'),
        Length.of(_r(269, 4), LengthUnit.inch),
      );
    });

    test('feet-and-inches notation without spaces', () {
      expect(
        Length.parse('5\'7"'),
        Length.of(_r(67), LengthUnit.inch),
      );
    });

    test('case-insensitive unit symbols', () {
      expect(Length.parse('5 IN'), Length.of(_r(5), LengthUnit.inch));
      expect(Length.parse('5 Ft'), Length.of(_r(5), LengthUnit.foot));
    });

    test('rejects malformed input', () {
      expect(() => Length.parse(''), throwsFormatException);
      expect(() => Length.parse('abc'), throwsFormatException);
      expect(() => Length.parse('5 parsecs'), throwsFormatException);
      expect(() => Length.parse('5//3 in'), throwsFormatException);
    });
  });

  group('Length.format — metric', () {
    test('whole number renders without decimals', () {
      expect(Length.of(_r(5), LengthUnit.meter).format(), '5 m');
    });

    test('decimal renders with trailing zeros trimmed', () {
      expect(Length.of(_r(3, 2), LengthUnit.meter).format(), '1.5 m');
    });

    test('rounds to default precision', () {
      // 1/3 m → 0.3333 m (4 decimals default)
      expect(Length.of(_r(1, 3), LengthUnit.meter).format(), '0.3333 m');
    });

    test('decimals override', () {
      expect(
        Length.of(_r(1, 3), LengthUnit.meter).format(decimals: 2),
        '0.33 m',
      );
    });

    test('negative metric', () {
      expect(
        Length.of(_r(-3, 2), LengthUnit.meter).format(),
        '-1.5 m',
      );
    });

    test('zero metric', () {
      expect(Length.of(Rational.zero, LengthUnit.meter).format(), '0 m');
    });
  });

  group('Length.format — imperial inches', () {
    test('whole inch', () {
      expect(Length.of(_r(7), LengthUnit.inch).format(), '7 in');
    });

    test('proper fraction only', () {
      expect(Length.of(_r(1, 2), LengthUnit.inch).format(), '1/2 in');
    });

    test('mixed number', () {
      expect(Length.of(_r(23, 4), LengthUnit.inch).format(), '5 3/4 in');
    });

    test('rounds to nearest 1/16 by default', () {
      // 0.3 in → 0.3 * 16 = 4.8 → rounds to 5/16
      expect(
        Length.of(_r(3, 10), LengthUnit.inch).format(),
        '5/16 in',
      );
    });

    test('maxDenominator override', () {
      expect(
        Length.of(_r(3, 10), LengthUnit.inch).format(maxDenominator: 8),
        '1/4 in', // 0.3 * 8 = 2.4 → rounds to 2/8 = 1/4
      );
    });

    test('reduces fractions to lowest terms', () {
      // 8/16 should display as 1/2
      expect(Length.of(_r(1, 2), LengthUnit.inch).format(), '1/2 in');
      // 4/16 should display as 1/4
      expect(Length.of(_r(1, 4), LengthUnit.inch).format(), '1/4 in');
    });

    test('rounds up across whole inch boundary', () {
      // 15.97 in with denom 16 → 15.97*16 = 255.52 → rounds to 256/16 = 16 in
      expect(
        Length.of(_r(1597, 100), LengthUnit.inch).format(),
        '16 in',
      );
    });

    test('negative inches', () {
      expect(
        Length.of(_r(-23, 4), LengthUnit.inch).format(),
        '-5 3/4 in',
      );
    });

    test('zero inches', () {
      expect(Length.of(Rational.zero, LengthUnit.inch).format(), '0 in');
    });
  });

  group("Length.format — feet-and-inches notation", () {
    test('whole feet show 0 inches', () {
      expect(Length.of(_r(1), LengthUnit.foot).format(), "1' 0\"");
    });

    test('feet with whole inches', () {
      // 5' 7" = 67 in
      expect(Length.of(_r(67), LengthUnit.inch).toUnit(LengthUnit.foot).format(), "5' 7\"");
    });

    test("feet with mixed inches: 5' 7 1/4\"", () {
      // 269/4 in
      expect(
        Length.of(_r(269, 4), LengthUnit.inch).toUnit(LengthUnit.foot).format(),
        "5' 7 1/4\"",
      );
    });

    test('rounds inches up across the foot boundary', () {
      // 11 15/16 in + a hair → should round to 1' 0"
      // Use 11.97 in: 11.97*16 = 191.52 → rounds to 192/16 = 12 in → 1' 0"
      expect(
        Length.of(_r(1197, 100), LengthUnit.inch).toUnit(LengthUnit.foot).format(),
        "1' 0\"",
      );
    });

    test('negative feet-inches', () {
      expect(
        Length.of(_r(-269, 4), LengthUnit.inch).toUnit(LengthUnit.foot).format(),
        "-5' 7 1/4\"",
      );
    });

    test('zero feet-inches', () {
      expect(
        Length.of(Rational.zero, LengthUnit.foot).format(),
        "0' 0\"",
      );
    });
  });

  group('Length.format — yards', () {
    test('decimal yards', () {
      expect(Length.of(_r(3, 2), LengthUnit.yard).format(), '1.5 yd');
    });
  });
}
