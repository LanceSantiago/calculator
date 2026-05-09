import 'package:flutter_test/flutter_test.dart';
import 'package:calculator/src/rational.dart';

void main() {
  group('Rational construction and reduction', () {
    test('reduces to lowest terms', () {
      expect(Rational.fromInts(4, 8), Rational.fromInts(1, 2));
      expect(Rational.fromInts(15, 25), Rational.fromInts(3, 5));
      expect(Rational.fromInts(100, 10), Rational.fromInts(10, 1));
    });

    test('sign always lives on the numerator', () {
      expect(Rational.fromInts(1, -2), Rational.fromInts(-1, 2));
      expect(Rational.fromInts(-1, -2), Rational.fromInts(1, 2));
    });

    test('zero numerator yields canonical zero', () {
      expect(Rational.fromInts(0, 5), Rational.zero);
      expect(Rational.fromInts(0, -5), Rational.zero);
    });

    test('zero denominator throws', () {
      expect(() => Rational.fromInts(1, 0), throwsArgumentError);
    });

    test('fromInt produces an integer rational', () {
      expect(Rational.fromInt(7).numerator, BigInt.from(7));
      expect(Rational.fromInt(7).denominator, BigInt.one);
      expect(Rational.fromInt(-3), Rational.fromInts(-3, 1));
    });
  });

  group('Rational equality and hashing', () {
    test('equal rationals compare equal regardless of input form', () {
      expect(Rational.fromInts(1, 2) == Rational.fromInts(2, 4), isTrue);
      expect(Rational.fromInts(-3, 6) == Rational.fromInts(1, -2), isTrue);
    });

    test('equal rationals hash to the same value', () {
      expect(
        Rational.fromInts(1, 2).hashCode,
        Rational.fromInts(2, 4).hashCode,
      );
    });

    test('different rationals are not equal', () {
      expect(Rational.fromInts(1, 2) == Rational.fromInts(1, 3), isFalse);
    });
  });

  group('Rational arithmetic', () {
    test('addition with common and unlike denominators', () {
      expect(
        Rational.fromInts(1, 2) + Rational.fromInts(1, 2),
        Rational.fromInt(1),
      );
      expect(
        Rational.fromInts(1, 3) + Rational.fromInts(1, 6),
        Rational.fromInts(1, 2),
      );
      expect(
        Rational.fromInts(1, 3) + Rational.fromInts(1, 3) + Rational.fromInts(1, 3),
        Rational.fromInt(1),
        reason: 'classic decimal-float trap; rationals must hit 1 exactly',
      );
    });

    test('subtraction', () {
      expect(
        Rational.fromInts(3, 4) - Rational.fromInts(1, 4),
        Rational.fromInts(1, 2),
      );
      expect(
        Rational.fromInts(1, 4) - Rational.fromInts(3, 4),
        Rational.fromInts(-1, 2),
      );
    });

    test('multiplication', () {
      expect(
        Rational.fromInts(2, 3) * Rational.fromInts(3, 4),
        Rational.fromInts(1, 2),
      );
      expect(Rational.fromInt(0) * Rational.fromInts(7, 8), Rational.zero);
    });

    test('division', () {
      expect(
        Rational.fromInts(1, 2) / Rational.fromInts(1, 4),
        Rational.fromInt(2),
      );
      expect(
        Rational.fromInts(-3, 4) / Rational.fromInts(1, 2),
        Rational.fromInts(-3, 2),
      );
    });

    test('division by zero throws', () {
      expect(
        () => Rational.fromInt(1) / Rational.zero,
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('unary negation', () {
      expect(-Rational.fromInts(3, 4), Rational.fromInts(-3, 4));
      expect(-Rational.zero, Rational.zero);
    });
  });

  group('Rational comparison', () {
    test('compareTo returns expected sign', () {
      expect(Rational.fromInts(1, 2).compareTo(Rational.fromInts(1, 3)), greaterThan(0));
      expect(Rational.fromInts(1, 3).compareTo(Rational.fromInts(1, 2)), lessThan(0));
      expect(Rational.fromInts(2, 4).compareTo(Rational.fromInts(1, 2)), 0);
    });

    test('comparison operators', () {
      final half = Rational.fromInts(1, 2);
      final third = Rational.fromInts(1, 3);
      expect(half > third, isTrue);
      expect(third < half, isTrue);
      expect(half >= Rational.fromInts(2, 4), isTrue);
      expect(half <= Rational.fromInts(2, 4), isTrue);
    });

    test('negative compares less than positive', () {
      expect(Rational.fromInts(-1, 2) < Rational.fromInts(1, 100), isTrue);
    });
  });

  group('Rational predicates and helpers', () {
    test('isZero, isNegative, isInteger', () {
      expect(Rational.zero.isZero, isTrue);
      expect(Rational.fromInt(5).isZero, isFalse);
      expect(Rational.fromInts(-1, 2).isNegative, isTrue);
      expect(Rational.fromInts(1, 2).isNegative, isFalse);
      expect(Rational.zero.isNegative, isFalse);
      expect(Rational.fromInt(7).isInteger, isTrue);
      expect(Rational.fromInts(7, 2).isInteger, isFalse);
    });

    test('abs', () {
      expect(Rational.fromInts(-3, 4).abs(), Rational.fromInts(3, 4));
      expect(Rational.fromInts(3, 4).abs(), Rational.fromInts(3, 4));
      expect(Rational.zero.abs(), Rational.zero);
    });

    test('toDouble', () {
      expect(Rational.fromInts(1, 2).toDouble(), 0.5);
      expect(Rational.fromInts(-3, 4).toDouble(), -0.75);
      expect(Rational.zero.toDouble(), 0.0);
    });
  });

  group('Rational.parse', () {
    test('parses whole numbers', () {
      expect(Rational.parse('5'), Rational.fromInt(5));
      expect(Rational.parse('-3'), Rational.fromInt(-3));
      expect(Rational.parse('  7  '), Rational.fromInt(7));
    });

    test('parses simple fractions', () {
      expect(Rational.parse('1/2'), Rational.fromInts(1, 2));
      expect(Rational.parse('-3/4'), Rational.fromInts(-3, 4));
      expect(Rational.parse('6/8'), Rational.fromInts(3, 4));
    });

    test('parses mixed numbers', () {
      expect(Rational.parse('2 1/2'), Rational.fromInts(5, 2));
      expect(Rational.parse('-2 1/2'), Rational.fromInts(-5, 2));
      expect(Rational.parse('5 3/4'), Rational.fromInts(23, 4));
    });

    test('parses decimals exactly', () {
      expect(Rational.parse('1.5'), Rational.fromInts(3, 2));
      expect(Rational.parse('0.25'), Rational.fromInts(1, 4));
      expect(Rational.parse('-0.1'), Rational.fromInts(-1, 10));
      expect(Rational.parse('25.4'), Rational.fromInts(127, 5));
    });

    test('rejects malformed input', () {
      expect(() => Rational.parse(''), throwsFormatException);
      expect(() => Rational.parse('abc'), throwsFormatException);
      expect(() => Rational.parse('1/'), throwsFormatException);
      expect(() => Rational.parse('1/0'), throwsArgumentError);
    });
  });

  group('Rational.toString', () {
    test('integers render without slash', () {
      expect(Rational.fromInt(5).toString(), '5');
      expect(Rational.fromInt(-3).toString(), '-3');
      expect(Rational.zero.toString(), '0');
    });

    test('non-integers render as numerator/denominator', () {
      expect(Rational.fromInts(1, 2).toString(), '1/2');
      expect(Rational.fromInts(-3, 4).toString(), '-3/4');
      expect(Rational.fromInts(5, 2).toString(), '5/2');
    });
  });
}
