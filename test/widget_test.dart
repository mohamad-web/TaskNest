import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_nest/main.dart';

void main() {
  testWidgets('TaskNest app loads', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const TaskNestApp());

    // Verify app title
    expect(find.text('TaskNest'), findsOneWidget);

    // Verify input field exists
    expect(find.byType(TextField), findsOneWidget);

    // Verify Add button exists
    expect(find.text('Add'), findsOneWidget);
  });
}
