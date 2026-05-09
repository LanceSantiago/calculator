import 'length.dart';
import 'rational.dart';

enum CalcOp { add, subtract, multiply, divide }

sealed class _Operand {
  const _Operand();
}

class _LengthOperand extends _Operand {
  final Length value;
  const _LengthOperand(this.value);
}

class _ScalarOperand extends _Operand {
  final Rational value;
  const _ScalarOperand(this.value);
}

class _CalcError implements Exception {
  final String message;
  _CalcError(this.message);
}

/// Chained calculator with mixed-unit length arithmetic.
///
/// Semantics:
/// - `+` / `−` require both operands to be Lengths.
/// - `×` / `÷` allow Length×Scalar or Scalar×Scalar (no Length×Length).
/// - The first unit in a chain wins for the result's display unit.
class Calculator {
  final StringBuffer _buffer = StringBuffer();
  bool _hasDecimal = false;
  bool _hasSlash = false;
  LengthUnit? _entryUnit;

  _Operand? _accumulator;
  CalcOp? _pendingOp;
  bool _showingResult = false;
  Length? _result;
  String? _error;

  String get display {
    if (_error != null) return _error!;
    if (_showingResult && _result != null) return _result!.format();
    if (_buffer.isEmpty) return '0';
    final unitSuffix = _entryUnit != null ? ' ${_entryUnit!.symbol}' : '';
    return '$_buffer$unitSuffix';
  }

  String? get error => _error;
  bool get hasResult => _showingResult && _result != null && _error == null;
  Length? get result => _showingResult && _error == null ? _result : null;

  void digit(int d) {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    _buffer.write(d.toString());
  }

  void decimalPoint() {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    if (_hasDecimal || _hasSlash) return;
    if (_buffer.isEmpty) _buffer.write('0');
    _buffer.write('.');
    _hasDecimal = true;
  }

  void fractionBar() {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    if (_hasDecimal || _hasSlash) return;
    if (_buffer.isEmpty) return;
    _buffer.write('/');
    _hasSlash = true;
  }

  void unit(LengthUnit u) {
    if (_error != null) return;
    if (_showingResult) return; // use toggleSystem to retarget the result
    _entryUnit = u;
  }

  void operatorPlus() => _operator(CalcOp.add);
  void operatorMinus() => _operator(CalcOp.subtract);
  void operatorTimes() => _operator(CalcOp.multiply);
  void operatorDivide() => _operator(CalcOp.divide);

  void _operator(CalcOp op) {
    if (_error != null) return;
    if (_showingResult) {
      _accumulator = _LengthOperand(_result!);
      _showingResult = false;
      _result = null;
      _resetEntry();
      _pendingOp = op;
      return;
    }

    final entry = _commitEntry();
    if (entry != null) {
      if (_accumulator == null) {
        _accumulator = entry;
      } else if (_pendingOp != null) {
        try {
          _accumulator = _apply(_accumulator!, _pendingOp!, entry);
        } on _CalcError catch (e) {
          _error = e.message;
          return;
        }
      }
    }
    _pendingOp = op;
    _resetEntry();
  }

  void equals() {
    if (_error != null) return;
    if (_showingResult) return;

    final entry = _commitEntry();

    if (_accumulator == null) {
      _accumulator = entry;
    } else if (_pendingOp != null && entry != null) {
      try {
        _accumulator = _apply(_accumulator!, _pendingOp!, entry);
      } on _CalcError catch (e) {
        _error = e.message;
        return;
      }
    }

    if (_accumulator is _LengthOperand) {
      _result = (_accumulator as _LengthOperand).value;
      _showingResult = true;
    } else if (_accumulator is _ScalarOperand) {
      _error = 'no unit';
    }
  }

  void clear() => _resetAll();

  void backspace() {
    if (_error != null) return;
    if (_showingResult) return;
    if (_entryUnit != null) {
      _entryUnit = null;
      return;
    }
    if (_buffer.isEmpty) return;
    final s = _buffer.toString();
    final last = s[s.length - 1];
    _buffer
      ..clear()
      ..write(s.substring(0, s.length - 1));
    if (last == '.') _hasDecimal = false;
    if (last == '/') _hasSlash = false;
  }

  void toggleSystem() {
    if (!hasResult) return;
    final newUnit = _autoPickUnit(_result!);
    _result = _result!.toUnit(newUnit);
  }

  LengthUnit _autoPickUnit(Length value) {
    final mm = value.millimeters.abs();
    if (value.displayUnit.isMetric) {
      // metric → imperial: ft if at least 1 ft, else in
      return mm >= LengthUnit.foot.mmPerUnit ? LengthUnit.foot : LengthUnit.inch;
    }
    // imperial → metric: m if >= 1 m, cm if >= 1 cm, else mm
    if (mm >= LengthUnit.meter.mmPerUnit) return LengthUnit.meter;
    if (mm >= LengthUnit.centimeter.mmPerUnit) return LengthUnit.centimeter;
    return LengthUnit.millimeter;
  }

  _Operand? _commitEntry() {
    if (_buffer.isEmpty) return null;
    final Rational value;
    try {
      value = Rational.parse(_buffer.toString());
    } on FormatException {
      _error = 'invalid number';
      return null;
    } on ArgumentError {
      _error = 'invalid number';
      return null;
    }
    return _entryUnit != null
        ? _LengthOperand(Length.of(value, _entryUnit!))
        : _ScalarOperand(value);
  }

  void _resetEntry() {
    _buffer.clear();
    _hasDecimal = false;
    _hasSlash = false;
    _entryUnit = null;
  }

  void _resetAll() {
    _resetEntry();
    _accumulator = null;
    _pendingOp = null;
    _showingResult = false;
    _result = null;
    _error = null;
  }

  _Operand _apply(_Operand a, CalcOp op, _Operand b) {
    switch (op) {
      case CalcOp.add:
      case CalcOp.subtract:
        if (a is _LengthOperand && b is _LengthOperand) {
          return _LengthOperand(
            op == CalcOp.add ? a.value + b.value : a.value - b.value,
          );
        }
        throw _CalcError('+/− require units on both sides');
      case CalcOp.multiply:
        if (a is _LengthOperand && b is _ScalarOperand) {
          return _LengthOperand(a.value * b.value);
        }
        if (a is _ScalarOperand && b is _LengthOperand) {
          return _LengthOperand(b.value * a.value);
        }
        if (a is _ScalarOperand && b is _ScalarOperand) {
          return _ScalarOperand(a.value * b.value);
        }
        throw _CalcError('cannot multiply two lengths');
      case CalcOp.divide:
        if (b is _ScalarOperand && b.value.isZero) {
          throw _CalcError('divide by zero');
        }
        if (a is _LengthOperand && b is _ScalarOperand) {
          return _LengthOperand(a.value / b.value);
        }
        if (a is _ScalarOperand && b is _ScalarOperand) {
          return _ScalarOperand(a.value / b.value);
        }
        throw _CalcError('unsupported division');
    }
  }
}
