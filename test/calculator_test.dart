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
      expect(calc.expression, '');
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

    test('decimal then fraction bar drops the slash', () {
      final calc = Calculator()
        ..digit(5)
        ..decimalPoint()
        ..digit(5)
        ..fractionBar()
        ..digit(2);
      expect(calc.display, '5.52');
    });

    test('fraction bar then decimal point drops the dot', () {
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
      expect(calc.expression, '');
    });
  });

  group('Calculator mixed-number entry', () {
    test('Mix separator builds a mixed number', () {
      final calc = Calculator()
        ..digit(1)..digit(1)
        ..mixedSeparator()
        ..digit(3)
        ..fractionBar()
        ..digit(4)
        ..unit(LengthUnit.inch);
      expect(calc.display, '11 3/4 in');
    });

    test('Mix-built operand commits to a single Length', () {
      final calc = Calculator()
        ..digit(1)..digit(1)
        ..mixedSeparator()
        ..digit(3)..fractionBar()..digit(4)
        ..unit(LengthUnit.inch)
        ..equals();
      // 11 3/4 in = 47/4 in
      expect(calc.result, Length.of(Rational.fromInts(47, 4), LengthUnit.inch));
    });

    test('Mix is rejected after a decimal point', () {
      final calc = Calculator()
        ..digit(5)
        ..decimalPoint()
        ..digit(5)
        ..mixedSeparator()
        ..digit(3);
      expect(calc.display, '5.53');
    });

    test('Mix is rejected on an empty buffer', () {
      final calc = Calculator()..mixedSeparator();
      expect(calc.display, '0');
    });

    test('backspace clears the Mix space', () {
      final calc = Calculator()
        ..digit(1)..digit(1)
        ..mixedSeparator();
      expect(calc.display, '11 _/_');
      calc.backspace();
      expect(calc.display, '11');
    });

    test('display shows _/_ placeholder right after Mix tap', () {
      final calc = Calculator()
        ..digit(5)
        ..mixedSeparator();
      expect(calc.display, '5 _/_');
    });

    test('display shows _ placeholder after fraction bar awaiting denominator', () {
      final calc = Calculator()
        ..digit(1)
        ..fractionBar();
      expect(calc.display, '1/_');
    });

    test('placeholders disappear once digits are typed', () {
      final calc = Calculator()
        ..digit(5)
        ..mixedSeparator()
        ..digit(3);
      expect(calc.display, '5 3');
    });

    test('fraction bar is rejected immediately after Mix space', () {
      // Need a numerator digit between Mix space and slash, otherwise we'd
      // produce "11 /" which the parser would reject.
      final calc = Calculator()
        ..digit(1)..digit(1)
        ..mixedSeparator()
        ..fractionBar();
      expect(calc.display, '11 _/_');
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

    test('chained left-to-right (no order of ops): 5 m + 1 m × 2 = 12 m', () {
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

  group('Calculator unit inheritance', () {
    test('5 m + 3 (no unit) inherits m → 8 m', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3) // no unit on second
        ..equals();
      expect(calc.result, Length.of(Rational.fromInt(8), LengthUnit.meter));
    });

    test('5 ft + 1/2 (no unit) inherits ft → 5 1/2 ft = 66 in', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.foot)
        ..operatorPlus()
        ..digit(1)..fractionBar()..digit(2)
        ..equals();
      // 5 ft + 0.5 ft = 5.5 ft = 11/2 ft
      expect(calc.result, Length.of(Rational.fromInts(11, 2), LengthUnit.foot));
    });

    test('chained inheritance: 5 m × 3 + 2 = 17 m (2 inherits)', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorTimes()
        ..digit(3)
        ..operatorPlus()
        ..digit(2)
        ..equals();
      expect(calc.result, Length.of(Rational.fromInt(17), LengthUnit.meter));
    });
  });

  group('Calculator first-value-needs-unit rule', () {
    test('scalar first operand on operator press errors', () {
      final calc = Calculator()
        ..digit(5)
        ..operatorPlus();
      expect(calc.error, 'tap a unit first');
    });

    test('scalar first operand on equals errors', () {
      final calc = Calculator()
        ..digit(5)
        ..equals();
      expect(calc.error, 'tap a unit first');
    });

    test('scalar × scalar errors at first operator press', () {
      final calc = Calculator()
        ..digit(2)
        ..operatorTimes();
      expect(calc.error, 'tap a unit first');
    });

    test('Length × Length still errors (no area)', () {
      final calc = Calculator()
        ..digit(2)..unit(LengthUnit.meter)
        ..operatorTimes()
        ..digit(3)..unit(LengthUnit.meter)
        ..equals();
      expect(calc.error, 'cannot multiply two lengths');
    });

    test('division by zero errors', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorDivide()
        ..digit(0)
        ..equals();
      expect(calc.error, 'divide by zero');
    });

    test('clear recovers from error', () {
      final calc = Calculator()
        ..digit(5)
        ..operatorPlus(); // errors: scalar first
      expect(calc.error, isNotNull);
      calc.clear();
      expect(calc.error, isNull);
      expect(calc.display, '0');
    });
  });

  group('Calculator expression breadcrumb', () {
    test('empty until first operator', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter);
      expect(calc.expression, '');
    });

    test('after first operator: includes operand and op', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus();
      expect(calc.expression, '5 m +');
    });

    test('mid-chain: 5 m + 3 in − ', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3)..unit(LengthUnit.inch)
        ..operatorMinus();
      expect(calc.expression, '5 m + 3 in −');
    });

    test('after equals: full expression without trailing op', () {
      final calc = Calculator()
        ..digit(2)..unit(LengthUnit.foot)
        ..operatorPlus()
        ..digit(3)..unit(LengthUnit.foot)
        ..equals();
      expect(calc.expression, '2 ft + 3 ft');
    });

    test('changing operator replaces the trailing op symbol', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..operatorMinus();
      expect(calc.expression, '5 m −');
    });

    test('continuing chain after equals carries the result forward', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus()
        ..digit(3)..unit(LengthUnit.meter)
        ..equals();
      calc.operatorPlus();
      expect(calc.expression, '8 m +');
    });

    test('digit after equals clears the expression', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..equals();
      calc.digit(3);
      expect(calc.expression, '');
    });

    test('clear resets the expression', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..operatorPlus();
      calc.clear();
      expect(calc.expression, '');
    });
  });

  group('Calculator result system toggle', () {
    test('toggle from metric meters to imperial feet-inches', () {
      final calc = Calculator()
        ..digit(1)..unit(LengthUnit.meter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.foot);
    });

    test('autopick: 5 cm result toggles to inches not feet', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.centimeter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.inch);
    });

    test('autopick: 1 ft result toggles to centimeters', () {
      final calc = Calculator()
        ..digit(1)..unit(LengthUnit.foot)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.centimeter);
    });

    test('autopick: 5 m → ft → m round-trip', () {
      final calc = Calculator()
        ..digit(5)..unit(LengthUnit.meter)
        ..equals();
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.foot);
      calc.toggleSystem();
      expect(calc.result?.displayUnit, LengthUnit.meter);
    });

    test('autopick: tiny metric value picks mm', () {
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
