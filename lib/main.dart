import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/calculator.dart';
import 'src/length.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final Calculator _calc = Calculator();

  void _act(VoidCallback action) {
    HapticFeedback.selectionClick();
    setState(action);
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Calculator',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.calculate, size: 48),
      applicationLegalese:
          '© 2026 Joseph Lance Santiago\nLicensed under the Apache License 2.0',
      children: const [
        SizedBox(height: 12),
        Text('Construction calculator with mixed-unit arithmetic.'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: _Display(
                text: _calc.display,
                expression: _calc.expression,
                hasResult: _calc.hasResult,
                hasError: _calc.error != null,
                onToggle: () => _act(_calc.toggleSystem),
                onAbout: _showAbout,
              ),
            ),
            Expanded(
              flex: 7,
              child: _Keypad(calc: _calc, act: _act),
            ),
          ],
        ),
      ),
    );
  }
}

class _Display extends StatelessWidget {
  final String text;
  final String expression;
  final bool hasResult;
  final bool hasError;
  final VoidCallback onToggle;
  final VoidCallback onAbout;

  const _Display({
    required this.text,
    required this.expression,
    required this.hasResult,
    required this.hasError,
    required this.onToggle,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              key: const Key('about_button'),
              icon: const Icon(Icons.info_outline),
              tooltip: 'About',
              onPressed: onAbout,
            ),
          ),
          if (hasResult)
            Align(
              alignment: Alignment.topRight,
              child: FilledButton.tonalIcon(
                key: const Key('toggle_system'),
                onPressed: onToggle,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Metric / Imperial'),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (expression.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    expression,
                    key: const Key('expression_text'),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomRight,
                child: Text(
                  text,
                  key: const Key('display_text'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w300,
                    color: hasError ? scheme.error : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _KeyKind { digit, op, fn, clear, equals, unit }

class _Keypad extends StatelessWidget {
  final Calculator calc;
  final void Function(VoidCallback) act;

  const _Keypad({required this.calc, required this.act});

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          // Unit row — 6 length units plus a ² modifier that squares the
          // current unit (turns 5 m into 5 m², for area arithmetic).
          _row([
            for (final u in LengthUnit.values)
              _Key(
                label: u.symbol,
                kind: _KeyKind.unit,
                onPressed: () => act(() => calc.unit(u)),
              ),
            _Key(
              label: '²',
              kind: _KeyKind.unit,
              onPressed: () => act(calc.square),
            ),
          ]),
          // Function/operator row
          _row([
            _Key(label: 'C', kind: _KeyKind.clear, onPressed: () => act(calc.clear)),
            _Key(label: '⌫', kind: _KeyKind.fn, onPressed: () => act(calc.backspace)),
            _Key(label: 'a/b', kind: _KeyKind.fn, onPressed: () => act(calc.fractionBar)),
            _Key(label: '÷', kind: _KeyKind.op, onPressed: () => act(calc.operatorDivide)),
          ]),
          _row([
            _Key(label: '7', onPressed: () => act(() => calc.digit(7))),
            _Key(label: '8', onPressed: () => act(() => calc.digit(8))),
            _Key(label: '9', onPressed: () => act(() => calc.digit(9))),
            _Key(label: '×', kind: _KeyKind.op, onPressed: () => act(calc.operatorTimes)),
          ]),
          _row([
            _Key(label: '4', onPressed: () => act(() => calc.digit(4))),
            _Key(label: '5', onPressed: () => act(() => calc.digit(5))),
            _Key(label: '6', onPressed: () => act(() => calc.digit(6))),
            _Key(label: '−', kind: _KeyKind.op, onPressed: () => act(calc.operatorMinus)),
          ]),
          _row([
            _Key(label: '1', onPressed: () => act(() => calc.digit(1))),
            _Key(label: '2', onPressed: () => act(() => calc.digit(2))),
            _Key(label: '3', onPressed: () => act(() => calc.digit(3))),
            _Key(label: '+', kind: _KeyKind.op, onPressed: () => act(calc.operatorPlus)),
          ]),
          _row([
            _Key(label: '_ _/_', kind: _KeyKind.fn, onPressed: () => act(calc.mixedSeparator)),
            _Key(label: '0', onPressed: () => act(() => calc.digit(0))),
            _Key(label: '.', onPressed: () => act(calc.decimalPoint)),
            _Key(label: '=', kind: _KeyKind.equals, onPressed: () => act(calc.equals)),
          ]),
        ],
      );
  }

  Widget _row(List<_Key> keys) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in keys) Expanded(child: k),
        ],
      ),
    );
  }

}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final _KeyKind kind;

  const _Key({
    required this.label,
    required this.onPressed,
    this.kind = _KeyKind.digit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (kind) {
      _KeyKind.digit => (scheme.surfaceContainerHigh, scheme.onSurface),
      _KeyKind.op => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _KeyKind.fn => (scheme.surfaceContainer, scheme.onSurfaceVariant),
      _KeyKind.clear => (scheme.errorContainer, scheme.onErrorContainer),
      _KeyKind.equals => (scheme.primary, scheme.onPrimary),
      _KeyKind.unit => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    };
    return FilledButton(
      key: Key('key_$label'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: TextStyle(
            fontSize: kind == _KeyKind.unit || label == 'a/b' ? 18 : 26,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
