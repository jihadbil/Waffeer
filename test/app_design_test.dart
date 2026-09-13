import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waffeer/core/database/db_helper.dart';
import 'package:waffeer/core/theme/app_theme.dart';
import 'package:waffeer/data/models/routine_expense_model.dart';
import 'package:waffeer/providers/budget_provider.dart';
import 'package:waffeer/providers/category_provider.dart';
import 'package:waffeer/providers/debt_provider.dart';
import 'package:waffeer/providers/goal_provider.dart';
import 'package:waffeer/providers/routine_provider.dart';
import 'package:waffeer/providers/security_provider.dart';
import 'package:waffeer/providers/settings_provider.dart';
import 'package:waffeer/providers/transaction_provider.dart';
import 'package:waffeer/providers/wallet_provider.dart';
import 'package:waffeer/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:waffeer/presentation/screens/analytics/analytics_screen.dart';
import 'package:waffeer/presentation/screens/budgets/budgets_screen.dart';
import 'package:waffeer/presentation/screens/categories/categories_screen.dart';
import 'package:waffeer/presentation/screens/debts/debts_screen.dart';
import 'package:waffeer/presentation/screens/goals/goals_screen.dart';
import 'package:waffeer/presentation/screens/plan/plan_screen.dart';
import 'package:waffeer/presentation/screens/routine/routine_expenses_screen.dart';
import 'package:waffeer/presentation/screens/routine/add_edit_routine_screen.dart';
import 'package:waffeer/presentation/screens/settings/settings_screen.dart';
import 'package:waffeer/presentation/screens/transactions/transactions_list_screen.dart';
import 'package:waffeer/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:waffeer/presentation/screens/wallets/wallets_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseHelper db;
  late WalletProvider wallets;
  late CategoryProvider categories;
  late TransactionProvider transactions;
  late RoutineProvider routines;
  late BudgetProvider budgets;
  late GoalProvider goals;
  late DebtProvider debts;
  late SettingsProvider settings;
  late SecurityProvider security;
  setUpAll(() async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'selected_locale': 'ar',
      'selected_currency': 'USD',
      'is_first_launch': false,
    });
    db = await DatabaseHelper.openAt(databaseFactoryFfi, inMemoryDatabasePath);
    wallets = WalletProvider(database: db);
    categories = CategoryProvider(database: db);
    transactions = TransactionProvider(database: db);
    routines = RoutineProvider(database: db);
    budgets = BudgetProvider(database: db);
    goals = GoalProvider(database: db);
    debts = DebtProvider(database: db);
    settings = SettingsProvider();
    security = SecurityProvider();
    await wallets.loadWallets('USD');
    await categories.loadCategories();
    await budgets.loadBudgets();
    await goals.loadGoals();
    await debts.loadDebts();
    final wallet = wallets.wallets.first;
    await wallets.updateWallet(
      wallet.copyWith(initialBalance: 1250, currentBalance: 1250),
    );
    await routines.addRoutine(
      title: 'قهوة الصباح',
      amount: 15,
      categoryId: 'cat_food',
      walletId: wallet.id,
      currencyCode: 'USD',
    );
    await routines.addRoutine(
      title: 'وقود السيارة',
      amount: 80,
      categoryId: 'cat_transport',
      walletId: wallet.id,
      currencyCode: 'USD',
    );
    await routines.addRoutine(
      title: 'إيجار المنزل',
      amount: 750,
      categoryId: 'cat_housing',
      walletId: wallet.id,
      currencyCode: 'USD',
      mode: RecordingMode.reminder,
      frequency: RoutineFrequency.monthly,
      nextDueDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    await routines.addRoutine(
      title: 'اشتراك الإنترنت',
      amount: 60,
      categoryId: 'cat_bills',
      walletId: wallet.id,
      currencyCode: 'USD',
      mode: RecordingMode.automatic,
      frequency: RoutineFrequency.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 20)),
    );
    await transactions.loadTransactions();
  });
  tearDown(() async {
    for (final provider in [
      wallets,
      categories,
      transactions,
      routines,
      budgets,
      goals,
      debts,
      settings,
      security,
    ]) {
      provider.dispose();
    }
    await db.close();
  });
  Widget app(Widget home, bool dark, GlobalKey key) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: security),
      ChangeNotifierProvider.value(value: wallets),
      ChangeNotifierProvider.value(value: categories),
      ChangeNotifierProvider.value(value: transactions),
      ChangeNotifierProvider.value(value: routines),
      ChangeNotifierProvider.value(value: budgets),
      ChangeNotifierProvider.value(value: goals),
      ChangeNotifierProvider.value(value: debts),
    ],
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui_previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Arabic app screens fit a 360px phone in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final screens = <String, Widget>{
          'home': const DashboardScreen(),
          'routines': const RoutineExpensesScreen(),
          'editor': const AddEditRoutineScreen(),
          'transactions': const TransactionsListScreen(),
          'add-transaction': const AddEditTransactionScreen(),
          'plan': const PlanScreen(),
          'analytics': const AnalyticsScreen(),
          'wallets': const WalletsScreen(),
          'budgets': const BudgetsScreen(),
          'goals': const GoalsScreen(),
          'debts': const DebtsScreen(),
          'categories': const CategoriesScreen(),
          'settings': const SettingsScreen(),
        };
        for (final entry in screens.entries) {
          final key = GlobalKey();
          await tester.pumpWidget(app(entry.value, dark, key));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: entry.key);
          if ([
            'home',
            'editor',
            'plan',
            'settings',
            'analytics',
          ].contains(entry.key)) {
            await capture(
              tester,
              key,
              '${entry.key}-${dark ? 'dark' : 'light'}',
            );
          }
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }

  testWidgets(
    'new recurring form saves the selected category without charging',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(const AddEditRoutineScreen(), false, GlobalKey()),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'الاسم'),
        'مصروف اختبار',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'المبلغ'),
        '12',
      );
      await tester.tap(find.text('التصنيف'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(categories.expenseCategories.first.localizedName(true)).last,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('حفظ الإعدادات'));
        for (
          var i = 0;
          i < 100 && !routines.routines.any((r) => r.title == 'مصروف اختبار');
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect(routines.routines.any((r) => r.title == 'مصروف اختبار'), isTrue);
      expect(wallets.totalBalance, 1250);
    },
  );

  testWidgets(
    'new presets default to manual and scheduled controls are optional',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          AddEditRoutineScreen(
            initialTemplate: RoutineProvider.presetTemplates.first,
          ),
          false,
          GlobalKey(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<RecordingMode>>(
              find.byType(RadioGroup<RecordingMode>),
            )
            .groupValue,
        RecordingMode.manual,
      );
      expect(find.text('التكرار'), findsNothing);
      await tester.ensureVisible(find.text('تسجيل تلقائي'));
      await tester.tap(find.text('تسجيل تلقائي'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('التكرار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
