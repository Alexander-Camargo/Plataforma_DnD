import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_frontend/widgets/password_requirements_view.dart';

void main() {
  group('Password security validation rules', () {
    test('isPasswordSecure validates all 5 requirements', () {
      // Empty
      expect(PasswordRequirementsView.isPasswordSecure(''), isFalse);
      // Missing length
      expect(PasswordRequirementsView.isPasswordSecure('Ab1!'), isFalse);
      // Missing uppercase
      expect(
          PasswordRequirementsView.isPasswordSecure('password123!'), isFalse);
      // Missing lowercase
      expect(
          PasswordRequirementsView.isPasswordSecure('PASSWORD123!'), isFalse);
      // Missing number
      expect(PasswordRequirementsView.isPasswordSecure('Password!@#'), isFalse);
      // Missing special char
      expect(PasswordRequirementsView.isPasswordSecure('Password123'), isFalse);
      // Valid password
      expect(PasswordRequirementsView.isPasswordSecure('Password123!'), isTrue);
      expect(
          PasswordRequirementsView.isPasswordSecure('D&dRules2026#'), isTrue);
    });

    testWidgets('PasswordRequirementsView renders live checkboxes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordRequirementsView(
              password: 'Pass',
              confirmPassword: '',
            ),
          ),
        ),
      );

      // Verify that the requirements view rendered
      expect(find.text('Requisitos de seguridad'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
      expect(find.text('Una mayúscula (A-Z)'), findsOneWidget);
      expect(find.text('Una minúscula (a-z)'), findsOneWidget);
      expect(find.text('Un número (0-9)'), findsOneWidget);
      expect(find.text(r'Un carácter especial (!@#$...)'), findsOneWidget);

      // 'Pass' has uppercase and lowercase, but not 8 chars, number, or special
      // Check that checkboxes are present
      expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(2));
      expect(
          find.byIcon(Icons.check_box_outline_blank_rounded), findsNWidgets(3));
    });

    testWidgets(
        'PasswordRequirementsView marks all fulfilled when password is secure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PasswordRequirementsView(
              password: 'Password123!',
              confirmPassword: 'Password123!',
            ),
          ),
        ),
      );

      // All 5 rules + confirm match = 6 fulfilled checkboxes
      expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(6));
      expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsNothing);
      expect(find.text('¡Excelente y segura!'), findsOneWidget);
    });
  });
}
