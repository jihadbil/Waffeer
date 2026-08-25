import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/onboarding/currency_setup_screen.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/wallet_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
      ],
      child: const WaffeerApp(),
    ),
  );
}

class WaffeerApp extends StatefulWidget {
  const WaffeerApp({super.key});

  @override
  State<WaffeerApp> createState() => _WaffeerAppState();
}

class _WaffeerAppState extends State<WaffeerApp> {
  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initAppData();
  }

  Future<void> _initAppData() async {
    if (_isDataLoaded) return;
    final settings = context.read<SettingsProvider>();

    if (!settings.isLoading && mounted) {
      _isDataLoaded = true;
      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();
      final txProvider = context.read<TransactionProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final goalProvider = context.read<GoalProvider>();
      final debtProvider = context.read<DebtProvider>();

      await catProvider.loadCategories();
      await walletProvider.loadWallets(settings.currencyCode);
      await txProvider.loadTransactions();
      await budgetProvider.loadBudgets();
      await goalProvider.loadGoals();
      await debtProvider.loadDebts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    if (settings.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'وفير - Waffeer',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: settings.locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settings.isFirstLaunch
          ? const CurrencySetupScreen()
          : const MainNavigationScreen(),
    );
  }
}
