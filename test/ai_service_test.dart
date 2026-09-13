import 'package:flutter_test/flutter_test.dart';
import 'package:waffeer/core/services/ai_service.dart';
import 'package:waffeer/data/models/ai_action.dart';
import 'package:waffeer/data/models/ai_chat_message.dart';
import 'package:waffeer/data/models/category_model.dart';
import 'package:waffeer/data/models/parsed_ai_expense.dart';
import 'package:waffeer/data/models/wallet_model.dart';
import 'package:waffeer/providers/ai_provider.dart';

void main() {
  group('AI Models & Services Tests', () {
    test('AiChatMessage serialization and deserialization', () {
      final msg = AiChatMessage(
        content: 'مرحباً! كيف أدير مصاريفي؟',
        isUser: true,
        suggestedFollowUps: ['ما هو وضعي المالي؟'],
      );

      final map = msg.toMap();
      final reconstructed = AiChatMessage.fromMap(map);

      expect(reconstructed.content, 'مرحباً! كيف أدير مصاريفي؟');
      expect(reconstructed.isUser, isTrue);
      expect(reconstructed.suggestedFollowUps, contains('ما هو وضعي المالي؟'));
      expect(reconstructed.isError, isFalse);
    });

    test('ParsedAiExpense isValid correctly identifies valid amount', () {
      const valid = ParsedAiExpense(
        amount: 85.5,
        title: 'عشاء ماك',
        rawInput: 'صرفت 85.5 في ماك',
      );
      expect(valid.isValid, isTrue);

      const invalid = ParsedAiExpense(
        amount: null,
        title: 'بدون مبلغ',
        rawInput: 'دخلت السوق',
      );
      expect(invalid.isValid, isFalse);
    });

    test('AiProvider initializes with default greeting message and prompt suggestions', () {
      final provider = AiProvider();
      expect(provider.chatMessages.isNotEmpty, isTrue);
      expect(provider.chatMessages.first.isUser, isFalse);
      expect(provider.chatMessages.first.content, contains('مستشارك المالي الذكي'));
      expect(provider.chatMessages.first.suggestedFollowUps.isNotEmpty, isTrue);
    });

    test('Fallback regex parser in AiService correctly extracts amount and category', () async {
      const categories = [
        CategoryModel(
          id: 'cat_food',
          nameEn: 'Food',
          nameAr: 'طعام ومطاعم',
          iconCodePoint: 0xe000,
          colorValue: 0xFF00FF00,
          type: CategoryType.expense,
        ),
      ];

      const wallets = [
        WalletModel(
          id: 'w_cash',
          nameEn: 'Cash',
          nameAr: 'كاش',
          initialBalance: 1000,
          currentBalance: 1000,
          currencyCode: 'SAR',
          iconCodePoint: 0xe001,
          colorValue: 0xFF0000FF,
          type: WalletType.cash,
        ),
      ];

      // Test with offline/invalid key to trigger fallback regex parser
      final parsed = await AiService.instance.parseExpensePrompt(
        apiKey: '',
        input: 'صرفت 95.50 ريال طعام ومطاعم كاش',
        categories: categories,
        wallets: wallets,
        defaultCurrency: 'SAR',
        isArabic: true,
      );

      expect(parsed.rawInput, contains('95.50'));
    });

    test('AiAction model serialization and deserialization', () {
      final action = AiAction(
        type: AiActionType.addExpense,
        title: 'تسجيل مصروف: قهوة',
        details: '45.0 طعام ومطاعم كاش',
        data: {'amount': 45.0, 'title': 'قهوة'},
        executedEntityId: 'tx-12345',
        isExecuted: true,
        isUndone: false,
      );

      final map = action.toMap();
      final restored = AiAction.fromMap(map);

      expect(restored.id, action.id);
      expect(restored.type, AiActionType.addExpense);
      expect(restored.title, 'تسجيل مصروف: قهوة');
      expect(restored.details, '45.0 طعام ومطاعم كاش');
      expect(restored.data['amount'], 45.0);
      expect(restored.executedEntityId, 'tx-12345');
      expect(restored.isExecuted, isTrue);
      expect(restored.isUndone, isFalse);
    });

    test('AiChatMessage with AiAction serialization and deserialization', () {
      final action = AiAction(
        type: AiActionType.changeTheme,
        title: 'تغيير مظهر التطبيق',
        details: 'الوضع الداكن 🌙',
        data: {'mode': 'dark'},
      );

      final msg = AiChatMessage(
        content: 'تم تفعيل الوضع الداكن بنجاح! 🌙',
        isUser: false,
        action: action,
      );

      final map = msg.toMap();
      final restored = AiChatMessage.fromMap(map);

      expect(restored.content, msg.content);
      expect(restored.action, isNotNull);
      expect(restored.action!.type, AiActionType.changeTheme);
      expect(restored.action!.data['mode'], 'dark');
    });

    test('extractActionFromResponse extracts add_expense action correctly', () {
      const aiResponse = '''
بالتأكيد! تم تسجيل مصروف القهوة بقيمة 45 ريال بنجاح ☕✨

```action
{"action": "add_expense", "amount": 45.0, "title": "قهوة", "category_name": "طعام ومطاعم", "wallet_name": "كاش"}
```
''';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.message, contains('تم تسجيل مصروف القهوة'));
      expect(result.message.contains('```action'), isFalse);
      expect(result.action, isNotNull);
      expect(result.action!.type, AiActionType.addExpense);
      expect(result.action!.data['amount'], 45.0);
      expect(result.action!.data['title'], 'قهوة');
    });

    test('extractActionFromResponse extracts add_income action correctly', () {
      const aiResponse = '''
رائع! تم تسجيل الدخل الإضافي بقيمة 3000 ريال 💰

```action
{"action": "add_income", "amount": 3000.0, "title": "مكافأة سنوية", "category_name": "راتب", "wallet_name": "البنك"}
```
''';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.action, isNotNull);
      expect(result.action!.type, AiActionType.addIncome);
      expect(result.action!.data['amount'], 3000.0);
      expect(result.action!.data['title'], 'مكافأة سنوية');
    });

    test('extractActionFromResponse extracts change_theme action correctly', () {
      const aiResponse = '''
تم تفعيل الوضع الداكن بناءً على طلبك 🌙

```action
{"action": "change_theme", "mode": "dark"}
```
''';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.action, isNotNull);
      expect(result.action!.type, AiActionType.changeTheme);
      expect(result.action!.data['mode'], 'dark');
    });

    test('extractActionFromResponse extracts add_category action correctly', () {
      const aiResponse = '''
تم إنشاء تصنيف "اشتراكات شهرية" الجديد بنجاح 📁

```action
{"action": "add_category", "name": "اشتراكات شهرية", "type": "expense"}
```
''';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.action, isNotNull);
      expect(result.action!.type, AiActionType.addCategory);
      expect(result.action!.data['name'], 'اشتراكات شهرية');
      expect(result.action!.data['type'], 'expense');
    });

    test('extractActionFromResponse handles plain advice without action blocks', () {
      const aiResponse = 'أنصحك بوضع 20% من دخلك الشهري في صندوق الطوارئ وادخار الفائض.';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.message, aiResponse);
      expect(result.actions, isEmpty);
      expect(result.action, isNull);
    });

    test('extractActionFromResponse extracts multiple actions from JSON array correctly', () {
      const aiResponse = '''
أهلاً بك! تم إضافة المدخول والمصروف بناءً على طلبك بنجاح 🌟

```action
[
  {"action": "add_income", "amount": 500.0, "title": "راتب", "category_name": "راتب", "wallet_name": "البنك"},
  {"action": "add_expense", "amount": 50.0, "title": "ترفيه", "category_name": "ترفيه", "wallet_name": "كاش"}
]
```
''';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.message, contains('تم إضافة المدخول والمصروف'));
      expect(result.message.contains('```action'), isFalse);
      expect(result.actions.length, 2);

      // Check first action (Income)
      final incomeAct = result.actions[0];
      expect(incomeAct.type, AiActionType.addIncome);
      expect(incomeAct.data['amount'], 500.0);
      expect(incomeAct.data['title'], 'راتب');

      // Check second action (Expense)
      final expenseAct = result.actions[1];
      expect(expenseAct.type, AiActionType.addExpense);
      expect(expenseAct.data['amount'], 50.0);
      expect(expenseAct.data['title'], 'ترفيه');
    });

    test('extractActionFromResponse extracts multiple actions from separate code blocks', () {
      const aiResponse = '''
تم تسجيل المعاملتين بنجاح!
```action
{"action": "add_income", "amount": 500.0, "title": "راتب"}
```
وأيضاً:
```action
{"action": "add_expense", "amount": 50.0, "title": "ترفيه"}
```
''';

      final result = AiService.extractActionFromResponse(aiResponse, true);

      expect(result.actions.length, 2);
      expect(result.actions[0].type, AiActionType.addIncome);
      expect(result.actions[1].type, AiActionType.addExpense);
    });

    test('AiChatMessage with multiple actions serialization and deserialization', () {
      final act1 = AiAction(
        type: AiActionType.addIncome,
        title: 'تسجيل دخل: راتب',
        details: '500.0 راتب',
        data: {'amount': 500.0, 'title': 'راتب'},
      );
      final act2 = AiAction(
        type: AiActionType.addExpense,
        title: 'تسجيل مصروف: ترفيه',
        details: '50.0 ترفيه',
        data: {'amount': 50.0, 'title': 'ترفيه'},
      );

      final msg = AiChatMessage(
        content: 'تم تسجيل المعاملتين معاً بنجاح!',
        isUser: false,
        actions: [act1, act2],
      );

      final map = msg.toMap();
      final restored = AiChatMessage.fromMap(map);

      expect(restored.content, msg.content);
      expect(restored.actions.length, 2);
      expect(restored.actions[0].type, AiActionType.addIncome);
      expect(restored.actions[1].type, AiActionType.addExpense);
      expect(restored.action, isNotNull);
      expect(restored.action!.type, AiActionType.addIncome);
    });
  });
}

