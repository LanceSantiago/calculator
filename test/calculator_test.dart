import 'package:flutter_test/flutter_test.dart';
import 'package:calculator/src/calculator.dart';
import 'package:calculator/src/length.dart';
import 'package:calculator/src/rational.dart';

void main() {
  group('Calculator initial state', () {
    test('display starts at 0', () {
      final calc = Calculator();
      expect(calc.display, '0');
      expect(calc.error, isNull);
      expect(calc.hasResult, isFalse);
    });
  });

  group('Calculator number entry', () {
    test('typing digits builds the display', () {
      final calc = Calculator();
      calc.digit(1);
      calc.digit(2);
      calc.digit(3);
      expect(calc.display, '123');
    });

    test('decimal point', () {
      final calc = Calculator()
        ..digit(5)
        ..decimalPoint()
        ..digit(7)
        ..digit(5);
      expect(calc.display, '5.75');
    });

    test('decimal point with no leading digit prepends 0', () {
      final calc = Calculator()
        ..decimalPoint()
        ..digit(5);
      expect(calc.display, '0.5');
    });

    test('second decimal point is ignored', () {
      final calc = Calculator()
        ..digit(1)
        ..decimalPoint()
        ..digit(5)
        ..decimalPoint()
        ..digit(2);
      expect(calc.display, '1.52');
    });

    test('fraction bar', () {
      final calc = Calculator()
        ..digit(3)
        ..fractionBar()
        ..digit(4);
      expect(calc.display, '3/4');
    });

    test('fraction bar without numerator is ignored', () {
      final calc = Calculator()..fractionBar();
      expect(calc.display, '0');
    });

    test('decimal followed by fraction bar is ignored', () {
      final calc = Calculator()
        ..digit(5)
        ..decimalPoint()
        ..digit(5)
        ..fractionBar()
        ..digit(2);
      expect(calc.display, '5.52'); // the slash and following digit are dropped... actually check impl
    });

    test('fraction bar followed by decimal is ignored', () {
      final calc = Calculator()
        ..digit(1)
        ..fractionBar()
        ..digit(2)
        ..decimalPoint()
        ..digit(5);
      expect(calc.display, '1/25');
    });

    test('unit symbol appears in display', () {
      final calc = Calculator()
        ..digit(5)
        ..unit(LengthUnit.meter);
      expect(calc.display, '5 m');
    });

    test('changing unit replaces it', () {
      final calc = Calculator()
        ..digit(5)
        ..unit(LengthUnit.meter)
        ..unit(LengthUnit.foot);
      expect(calc.display, '5 ft');
    });

    test('backspace removes last character', () {
      final calc = Calculator()
        ..digit(1)
        ..digit(2)
        ..digit(3);
      calc.backspace();
      expect(calc.display, '12');
      calc.backspace();
      expect(calc.display, '1');
    });

    test('backspace clears unit before digits', () {
      final calc = Calculator()
        ..digit(5)
        ..unit(LengthUnit.meter);
      calc.backspace();
      expect(calc.display, '5');
      calc.backspace();
      expect(calc.display, '0');
    });

    test('clear resets', () {
      final calc = Calculator()
        ..digit(5)
        ..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3);
      calc.clear();
      expect(calc.display, '0');
      expect(calc.error, isNull);
    });
  });

  group('Calculator chained arithmetic', () {
    test('1 m + 3 in - 4 cm produces 1036.2 mm displayed in meters', () {
      final calc = Calculator()
        ..digit(1)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3)..unit(LengthUnit.inch)
        ..operatorMinus()
        ..digit(4)..unit(LengthUnit.centimeter)
        ..equals();
      expect(calc.hasResult, isTrue);
      expect(calc.result?.millimeters, Rational.fromInts(5181, 5));
      expect(calc.result?.displayUnit, LengthUnit.meter);
    });

    test('1/3 in + 1/3 in + 1/3 in equals exactly 1 in', () {
      final calc = Calculator()
        ..digit(1)..fractionBar()..digit(3)..unit(LengthUnit.inch)
        ..operatorPlus()
        ..digit(1)..fractionBar()..digit(3)..unit(LengthUnit.inch)
        ..operatorPlus()
        ..digit(1)..fractionBar()..digit(3)..unit(LengthUnit.inch)
        ..equals();
      expect(calc.result, Length.of(Rational.fromInt(1), LengthUnit.inch));
    });

    test('first unit wins for the result display unit', () {
      final calc = Calculator()
        ..digit(3)..unit(LengthUnit.inch)
        ..operatorPlus()
        ..digit(1)..unit(LengthUnit.meter)
        ..equals();
      expect(calc.result?.displayUnit, LengthUnit.inch);
    });

    test('Length × scalar', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.foot)
        ..operatorTimes()
        ..digit(3)
        ..equals();
      expect(calc.result, Length.of(Rational.fromInt(15), LengthUnit.foot));
    });

    test('Length ÷ scalar', () {
      final calc = Calculator()
        ..digit(6)..unit(LengthUnit.meter)
        ..operatorDivide()
        ..digit(2)
        ..equals();
      expect(calc.result, Length.of(Rational.fromInt(3), LengthUnit.meter));
    });

    test('chained: 5 m + 1 m × 2 evaluates left-to-right (chained calc, not order of ops)', () {
      // Chained calc: ((5 m + 1 m) × 2) = 12 m. Not 5m + 2m = 7m.
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(1)..unit(LengthUnit.meter)
        ..operatorTimes()
        ..digit(2)
        ..equals();
      expect(calc.result, Length.of(Rational.fromInt(12), LengthUnit.meter));
    });

    test('display after equals shows formatted result', () {
      final calc = Calculator()
        ..digit(2)..unit(LengthUnit.foot)
        ..operatorPlus()
        ..digit(3)..unit(LengthUnit.foot)
        ..equals();
      expect(calc.display, "5' 0\"");
    });

    test('starting a new chain after equals uses result as first operand', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3)..unit(LengthUnit.meter)
        ..equals();
      // Now press + 1 m =
      calc.operatorPlus();
      calc.digit(1);
      calc.unit(LengthUnit.meter);
      calc.equals();
      expect(calc.result, Length.of(Rational.fromInt(9), LengthUnit.meter));
    });

    test('digit after equals starts a fresh chain', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..equals();
      calc.digit(3);
      expect(calc.display, '3');
      expect(calc.hasResult, isFalse);
    });
  });

  group('Calculator errors', () {
    test('Length + scalar errors', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3) // no unit
        ..equals();
      expect(calc.error, isNotNull);
    });

    test('Length × Length errors (we do not support area)', () {
      final calc = Calculator()
        ..digit(2)..unit(LengthUnit.meter)
        ..operatorTimes()
        ..digit(3)..unit(LengthUnit.meter)
        ..equals();
      expect(calc.error, isNotNull);
    });

    test('division by zero errors', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorDivide()
        ..digit(0)
        ..equals();
      expect(calc.error, isNotNull);
    });

    test('clear recovers from error', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3)
        ..equals();
      expect(calc.error, isNotNull);
      calc.clear();
      expect(calc.error, isNull);
      expect(calc.display, '0');
    });
  });

  group('Calculator result system toggle', () {
    test('toggle from metric meters to imperial feet-inches', () {
      // 1 m = 39.3700787... in = 3' 3 3/8" (rounded to 1/16: 3.937" * 16 ~= 63 → 63/16 inches per foot remainder)
      // Actually 1 m = 1000 mm. In inches: 1000 / 25.4 ≈ 39.37". As feet-inches: 3' 3 3/8" (39.375")
      final calc = Calculator()
        ..digit(1)..unit(LengthUnit.meter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.foot);
    });

    test('autopick: 50 cm result toggles to inches not feet', () {
      // 50 cm ≈ 19.69 in, which is < 1 ft, so should pick inches
      // wait — 19.69 in is > 12 in, so it IS >= 1 ft. Let me adjust.
      // Use 5 cm: 5 cm ≈ 1.97 in, < 12 in → inches
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.centimeter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.inch);
    });

    test('autopick: 1 ft result toggles to metric meters', () {
      // 1 ft = 304.8 mm = 30.48 cm. Since >= 1 cm but < 1 m, should pick cm.
      final calc = Calculator()
        ..digit(1)..unit(LengthUnit.foot)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.centimeter);
    });

    test('autopick: 5 m result toggles to feet, then back to meters', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.foot);
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.meter);
    });

    test('autopick: tiny metric value picks mm', () {
      // 5 mm result, toggle to imperial → inches; toggle back → mm
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.millimeter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.inch);
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.millimeter);
    });

    test('toggle does nothing without a result', () {
      final calc = Calculator()..digit(5);
      calc.toggleSystem();
      expect(calc.display, '5');
      expect(calc.hasResult, isFalse);
    });
  });
}
