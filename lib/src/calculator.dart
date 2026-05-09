import 'area.dart';
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

class _AreaOperand extends _Operand {
  final Area value;
  const _AreaOperand(this.value);
}

class _ScalarOperand extends _Operand {
  final Rational value;
  const _ScalarOperand(this.value);
}

class _CalcError implements Exception {
  final String message;
  _CalcError(this.message);
}

sealed class _Result {
  const _Result();
}

class _LengthResult extends _Result {
  final Length value;
  const _LengthResult(this.value);
}

class _AreaResult extends _Result {
  final Area value;
  const _AreaResult(this.value);
}

/// Chained calculator with mixed-unit length + area arithmetic.
///
/// Semantics:
/// - The first operand in a chain MUST have a unit (Length or Area).
/// - Subsequent operands without a unit inherit the unit from the running
///   accumulator (length stays length, area stays area).
/// - `Length × Length = Area`, `Area / Length = Length`. Cross-dimensional
///   adds (Length + Area) and higher-dimensional products (Length × Area,
///   Area × Area) are errors.
class Calculator {
  final StringBuffer _buffer = StringBuffer();
  bool _hasDecimal = false;
  bool _hasSlash = false;
  bool _hasSpace = false;
  LengthUnit? _entryUnit;
  bool _isSquared = false;

  _Operand? _accumulator;
  CalcOp? _pendingOp;
  bool _showingResult = false;
  _Result? _result;
  String? _error;

  final List<String> _expressionParts = [];

  String get display {
    if (_error != null) return _error!;
    if (_showingResult && _result != null) return _formattedResult();
    if (_buffer.isEmpty) return '0';
    var body = _buffer.toString();
    if (body.endsWith(' ') || body.endsWith('/')) {
      body = '${body}_';
    }
    return '$body${_entryUnitSuffix()}';
  }

  String get expression => _expressionParts.join(' ');

  String? get error => _error;
  bool get hasResult => _showingResult && _result != null && _error == null;

  Length? get result {
    if (!hasResult) return null;
    return switch (_result) {
      _LengthResult(value: final v) => v,
      _ => null,
    };
  }

  Area? get resultArea {
    if (!hasResult) return null;
    return switch (_result) {
      _AreaResult(value: final v) => v,
      _ => null,
    };
  }

  void digit(int d) {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    _buffer.write(d.toString());
  }

  void decimalPoint() {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    if (_hasDecimal || _hasSlash || _hasSpace) return;
    if (_buffer.isEmpty) _buffer.write('0');
    _buffer.write('.');
    _hasDecimal = true;
  }

  void fractionBar() {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    if (_hasDecimal || _hasSlash) return;
    if (_buffer.isEmpty) return;
    if (_buffer.toString().endsWith(' ')) return;
    _buffer.write('/');
    _hasSlash = true;
  }

  void mixedSeparator() {
    if (_error != null) return;
    if (_showingResult) _resetAll();
    if (_hasDecimal || _hasSlash || _hasSpace) return;
    if (_buffer.isEmpty) return;
    _buffer.write(' ');
    _hasSpace = true;
  }

  void unit(LengthUnit u) {
    if (_error != null) return;
    if (_showingResult) return;
    _entryUnit = u;
  }

  /// Tagged the current entry as a squared unit (m → m², ft → ft², etc.).
  /// Toggle: pressing again removes the squared flag. No-op if no unit set.
  void square() {
    if (_error != null) return;
    if (_showingResult) return;
    if (_entryUnit == null) return;
    _isSquared = !_isSquared;
  }

  void operatorPlus() => _operator(CalcOp.add);
  void operatorMinus() => _operator(CalcOp.subtract);
  void operatorTimes() => _operator(CalcOp.multiply);
  void operatorDivide() => _operator(CalcOp.divide);

  void _operator(CalcOp op) {
    if (_error != null) return;
    if (_showingResult) {
      _accumulator = _operandFromResult();
      _expressionParts
        ..clear()
        ..add(_formattedResult())
        ..add(_opSymbol(op));
      _showingResult = false;
      _result = null;
      _resetEntry();
      _pendingOp = op;
      return;
    }

    final entryStr = _formatEntryForExpression();
    final entry = _commitEntry();

    if (entry != null) {
      if (_accumulator == null) {
        if (entry is _ScalarOperand) {
          _error = 'tap a unit first';
          return;
        }
        _accumulator = entry;
        _expressionParts.add(entryStr);
      } else if (_pendingOp != null) {
        try {
          _accumulator = _apply(_accumulator!, _pendingOp!, entry);
        } on _CalcError catch (e) {
          _error = e.message;
          return;
        }
        _expressionParts.add(entryStr);
      }
      _expressionParts.add(_opSymbol(op));
    } else {
      if (_expressionParts.isNotEmpty &&
          _isOperatorString(_expressionParts.last)) {
        _expressionParts[_expressionParts.length - 1] = _opSymbol(op);
      }
    }
    _pendingOp = op;
    _resetEntry();
  }

  void equals() {
    if (_error != null) return;
    if (_showingResult) return;

    final entryStr = _formatEntryForExpression();
    final entry = _commitEntry();

    if (_accumulator == null) {
      if (entry == null) return;
      if (entry is _ScalarOperand) {
        _error = 'tap a unit first';
        return;
      }
      _accumulator = entry;
      _expressionParts.add(entryStr);
    } else if (_pendingOp != null && entry != null) {
      try {
        _accumulator = _apply(_accumulator!, _pendingOp!, entry);
      } on _CalcError catch (e) {
        _error = e.message;
        return;
      }
      _expressionParts.add(entryStr);
    } else if (entry == null &&
        _expressionParts.isNotEmpty &&
        _isOperatorString(_expressionParts.last)) {
      _expressionParts.removeLast();
    }

    switch (_accumulator) {
      case _LengthOperand(value: final v):
        _result = _LengthResult(v);
        _showingResult = true;
      case _AreaOperand(value: final v):
        _result = _AreaResult(v);
        _showingResult = true;
      case _ScalarOperand():
        _error = 'no unit';
      case null:
        return;
    }
  }

  void clear() => _resetAll();

  void backspace() {
    if (_error != null) return;
    if (_showingResult) return;
    if (_isSquared) {
      _isSquared = false;
      return;
    }
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
    if (last == ' ') _hasSpace = false;
  }

  void toggleSystem() {
    if (!hasResult) return;
    switch (_result) {
      case _LengthResult(value: final v):
        _result = _LengthResult(v.toUnit(_autoPickLengthUnit(v)));
      case _AreaResult(value: final v):
        _result = _AreaResult(v.toUnit(_autoPickAreaUnit(v)));
      case _:
        return;
    }
  }

  LengthUnit _autoPickLengthUnit(Length value) {
    final mm = value.millimeters.abs();
    if (value.displayUnit.isMetric) {
      return mm >= LengthUnit.foot.mmPerUnit ? LengthUnit.foot : LengthUnit.inch;
    }
    if (mm >= LengthUnit.meter.mmPerUnit) return LengthUnit.meter;
    if (mm >= LengthUnit.centimeter.mmPerUnit) return LengthUnit.centimeter;
    return LengthUnit.millimeter;
  }

  AreaUnit _autoPickAreaUnit(Area value) {
    final mm2 = value.squareMillimeters.abs();
    if (value.displayUnit.isMetric) {
      return mm2 >= AreaUnit.squareFoot.sqMmPerUnit
          ? AreaUnit.squareFoot
          : AreaUnit.squareInch;
    }
    if (mm2 >= AreaUnit.squareMeter.sqMmPerUnit) return AreaUnit.squareMeter;
    if (mm2 >= AreaUnit.squareCentimeter.sqMmPerUnit) {
      return AreaUnit.squareCentimeter;
    }
    return AreaUnit.squareMillimeter;
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
    if (_entryUnit != null) {
      return _isSquared
          ? _AreaOperand(Area.of(value, AreaUnit.forLength(_entryUnit!)))
          : _LengthOperand(Length.of(value, _entryUnit!));
    }
    return _ScalarOperand(value);
  }

  String _entryUnitSuffix() {
    if (_entryUnit == null) return '';
    return ' ${_entryUnit!.symbol}${_isSquared ? "²" : ""}';
  }

  String _formatEntryForExpression() {
    if (_buffer.isEmpty) return '';
    return '$_buffer${_entryUnitSuffix()}';
  }

  String _formattedResult() {
    return switch (_result) {
      _LengthResult(value: final v) => v.format(),
      _AreaResult(value: final v) => v.format(),
      _ => '',
    };
  }

  _Operand _operandFromResult() {
    return switch (_result) {
      _LengthResult(value: final v) => _LengthOperand(v),
      _AreaResult(value: final v) => _AreaOperand(v),
      null => throw StateError('no result to continue from'),
    };
  }

  static String _opSymbol(CalcOp op) {
    switch (op) {
      case CalcOp.add:
        return '+';
      case CalcOp.subtract:
        return '−';
      case CalcOp.multiply:
        return '×';
      case CalcOp.divide:
        return '÷';
    }
  }

  static bool _isOperatorString(String s) =>
      s == '+' || s == '−' || s == '×' || s == '÷';

  void _resetEntry() {
    _buffer.clear();
    _hasDecimal = false;
    _hasSlash = false;
    _hasSpace = false;
    _entryUnit = null;
    _isSquared = false;
  }

  void _resetAll() {
    _resetEntry();
    _accumulator = null;
    _pendingOp = null;
    _showingResult = false;
    _result = null;
    _error = null;
    _expressionParts.clear();
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
        if (a is _AreaOperand && b is _AreaOperand) {
          return _AreaOperand(
            op == CalcOp.add ? a.value + b.value : a.value - b.value,
          );
        }
        if (a is _LengthOperand && b is _ScalarOperand) {
          final inferred = Length.of(b.value, a.value.displayUnit);
          return _LengthOperand(
            op == CalcOp.add ? a.value + inferred : a.value - inferred,
          );
        }
        if (a is _AreaOperand && b is _ScalarOperand) {
          final inferred = Area.of(b.value, a.value.displayUnit);
          return _AreaOperand(
            op == CalcOp.add ? a.value + inferred : a.value - inferred,
          );
        }
        // Cross-dimensional: length + area or area + length
        throw _CalcError('cannot add length and area');
      case CalcOp.multiply:
        if (a is _LengthOperand && b is _LengthOperand) {
          return _AreaOperand(Area.fromLengths(a.value, b.value));
        }
        if (a is _LengthOperand && b is _ScalarOperand) {
          return _LengthOperand(a.value * b.value);
        }
        if (a is _ScalarOperand && b is _LengthOperand) {
          return _LengthOperand(b.value * a.value);
        }
        if (a is _AreaOperand && b is _ScalarOperand) {
          return _AreaOperand(a.value * b.value);
        }
        if (a is _ScalarOperand && b is _AreaOperand) {
          return _AreaOperand(b.value * a.value);
        }
        if (a is _ScalarOperand && b is _ScalarOperand) {
          return _ScalarOperand(a.value * b.value);
        }
        throw _CalcError('cannot multiply at this dimension');
      case CalcOp.divide:
        if (b is _ScalarOperand && b.value.isZero) {
          throw _CalcError('divide by zero');
        }
        if (b is _LengthOperand && b.value.millimeters.isZero) {
          throw _CalcError('divide by zero');
        }
        if (b is _AreaOperand && b.value.squareMillimeters.isZero) {
          throw _CalcError('divide by zero');
        }
        if (a is _LengthOperand && b is _ScalarOperand) {
          return _LengthOperand(a.value / b.value);
        }
        if (a is _AreaOperand && b is _ScalarOperand) {
          return _AreaOperand(a.value / b.value);
        }
        if (a is _AreaOperand && b is _LengthOperand) {
          // Area ÷ Length = Length, taking the divisor's display unit.
          final mm = a.value.squareMillimeters / b.value.millimeters;
          final unit = b.value.displayUnit;
          return _LengthOperand(Length.of(mm / unit.mmPerUnit, unit));
        }
        if (a is _ScalarOperand && b is _ScalarOperand) {
          return _ScalarOperand(a.value / b.value);
        }
        throw _CalcError('unsupported division');
    }
  }
}
