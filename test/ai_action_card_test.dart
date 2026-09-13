import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffeer/data/models/ai_action.dart';
import 'package:waffeer/presentation/widgets/ai_action_card.dart';
import 'package:waffeer/providers/ai_provider.dart';
import 'package:waffeer/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );
  }

  group('AiActionCard Widget Tests', () {
    testWidgets('renders expense action details properly', (tester) async {
      final action = AiAction(
        type: AiActionType.addExpense,
        title: 'تسجيل مصروف: قهوة مختصة',
        details: '28.0 طعام ومطاعم كاش',
        data: {'amount': 28.0, 'title': 'قهوة مختصة'},
      );

      await tester.pumpWidget(buildTestableWidget(child: AiActionCard(action: action)));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل مصروف: قهوة مختصة'), findsOneWidget);
      expect(find.text('28.0 طعام ومطاعم كاش'), findsOneWidget);
      expect(find.text('تسجيل مصروف'), findsOneWidget);
      expect(find.text('تم التطبيق'), findsOneWidget);
      expect(find.text('تراجع عن الإجراء'), findsOneWidget);
    });

    testWidgets('renders undone state properly when action is undone', (tester) async {
      final action = AiAction(
        type: AiActionType.changeTheme,
        title: 'تغيير مظهر التطبيق',
        details: 'الوضع الداكن 🌙',
        data: {'mode': 'dark'},
        isUndone: true,
      );

      await tester.pumpWidget(buildTestableWidget(child: AiActionCard(action: action)));
      await tester.pumpAndSettle();

      expect(find.text('تغيير مظهر التطبيق'), findsOneWidget);
      expect(find.text('الوضع الداكن 🌙'), findsOneWidget);
      expect(find.text('تم التراجع'), findsOneWidget);
      // When undone, the undo button is hidden
      expect(find.text('تراجع عن الإجراء'), findsNothing);
    });
  });
}
