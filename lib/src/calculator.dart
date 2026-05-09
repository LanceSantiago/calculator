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
/// - The first operand in a chain MUST have a unit. The calculator errors
///   on the first operator press (or equals) if it doesn't.
/// - Subsequent operands without a unit inherit the unit from the running
///   accumulator, so `5m + 3 = 8m`.
/// - `×` / `÷` allow Length×Scalar but not Length×Length (no area).
class Calculator {
  final StringBuffer _buffer = StringBuffer();
  bool _hasDecimal = false;
  bool _hasSlash = false;
  bool _hasSpace = false;
  LengthUnit? _entryUnit;

  _Operand? _accumulator;
  CalcOp? _pendingOp;
  bool _showingResult = false;
  Length? _result;
  String? _error;

  /// Committed parts of the running expression, in order: operand, op, operand,
  /// op, ... Used to render the breadcrumb above the main display.
  final List<String> _expressionParts = [];

  String get display {
    if (_error != null) return _error!;
    if (_showingResult && _result != null) return _result!.format();
    if (_buffer.isEmpty) return '0';
    var body = _buffer.toString();
    // Surface placeholders when the user is mid-fraction so they can see what
    // the next digit will fill in.
    if (body.endsWith(' ')) {
      body = '${body}_/_';
    } else if (body.endsWith('/')) {
      body = '${body}_';
    }
    final unitSuffix = _entryUnit != null ? ' ${_entryUnit!.symbol}' : '';
    return '$body$unitSuffix';
  }

  String get expression => _expressionParts.join(' ');

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
    // After a Mix space, the buffer ends in a space — need a digit between
    // space and slash, otherwise we'd produce "5 /" which won't parse.
    if (_buffer.toString().endsWith(' ')) return;
    _buffer.write('/');
    _hasSlash = true;
  }

  /// Inserts the whole/numerator separator for mixed-number entry: tap after
  /// typing the whole part, then enter the fraction.
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
      _expressionParts
        ..clear()
        ..add(_result!.format())
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
      // No new entry — user changed their mind on the operator. Replace the
      // trailing op symbol if there is one.
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
      // Trailing operator with no second operand: drop it from the expression.
      _expressionParts.removeLast();
    }

    if (_accumulator is _LengthOperand) {
      _result = (_accumulator as _LengthOperand).value;
      _showingResult = true;
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
    if (last == ' ') _hasSpace = false;
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

  String _formatEntryForExpression() {
    if (_buffer.isEmpty) return '';
    final unit = _entryUnit != null ? ' ${_entryUnit!.symbol}' : '';
    return '$_buffer$unit';
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
        if (a is _LengthOperand && b is _ScalarOperand) {
          // Subsequent scalar inherits the running unit.
          final inferred = Length.of(b.value, a.value.displayUnit);
          return _LengthOperand(
            op == CalcOp.add ? a.value + inferred : a.value - inferred,
          );
        }
        // a is ScalarOperand shouldn't happen given the first-value check.
        throw _CalcError('+/− require units');
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
