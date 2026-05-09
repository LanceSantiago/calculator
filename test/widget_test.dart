import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calculator/main.dart';

String _displayText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('display_text'))).data!;

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(Key('key_$label')));
  await tester.pump();
}

void main() {
  testWidgets('initial display shows 0', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    expect(_displayText(tester), '0');
    expect(find.byKey(const Key('toggle_system')), findsNothing);
  });

  testWidgets('tapping digits builds the display', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '1');
    await _tap(tester, '2');
    await _tap(tester, '3');
    expect(_displayText(tester), '123');
  });

  testWidgets('tapping a unit button appears in display', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '5');
    await _tap(tester, 'm');
    expect(_displayText(tester), '5 m');
  });

  testWidgets("end-to-end: 2 ft + 3 ft = 5' 0\"", (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '2');
    await _tap(tester, 'ft');
    await _tap(tester, '+');
    await _tap(tester, '3');
    await _tap(tester, 'ft');
    await _tap(tester, '=');
    expect(_displayText(tester), "5' 0\"");
  });

  testWidgets('toggle button appears after equals and switches systems', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '1');
    await _tap(tester, 'm');
    await _tap(tester, '=');
    expect(_displayText(tester), '1 m');

    final toggle = find.byKey(const Key('toggle_system'));
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    // 1 m ≥ 1 ft so it should pick foot, formatted as feet-inches.
    expect(_displayText(tester).endsWith('"'), isTrue);
  });

  testWidgets('clear resets to 0', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '5');
    await _tap(tester, 'm');
    await _tap(tester, 'C');
    expect(_displayText(tester), '0');
  });

  testWidgets('breadcrumb shows the running expression', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    expect(find.byKey(const Key('expression_text')), findsNothing);

    await _tap(tester, '5');
    await _tap(tester, 'm');
    await _tap(tester, '+');

    final crumb = tester.widget<Text>(find.byKey(const Key('expression_text'))).data!;
    expect(crumb, '5 m +');
  });

  testWidgets('mixed-number button enters a mixed-number operand', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '1');
    await _tap(tester, '1');
    await _tap(tester, '_ _/_');
    await _tap(tester, '3');
    await _tap(tester, 'a/b');
    await _tap(tester, '4');
    await _tap(tester, 'in');
    expect(_displayText(tester), '11 3/4 in');
  });

  testWidgets('first value without a unit shows the error', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '5');
    await _tap(tester, '+');
    expect(_displayText(tester), 'tap a unit first');
  });

  testWidgets('5 m + 3 = inherits the unit → 8 m', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await _tap(tester, '5');
    await _tap(tester, 'm');
    await _tap(tester, '+');
    await _tap(tester, '3');
    await _tap(tester, '=');
    expect(_displayText(tester), '8 m');
  });

  testWidgets('About button opens the about dialog', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tester.tap(find.byKey(const Key('about_button')));
    await tester.pumpAndSettle();
    expect(find.text('Construction calculator with mixed-unit arithmetic.'),
        findsOneWidget);
    expect(find.textContaining('Apache License 2.0'), findsOneWidget);
  });
}
