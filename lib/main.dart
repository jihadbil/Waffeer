import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/screens/onboarding/currency_setup_screen.dart';
import 'presentation/screens/security/lock_screen.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/security_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/wallet_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => RoutineProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
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

class _WaffeerAppState extends State<WaffeerApp> with WidgetsBindingObserver {
  bool _isDataLoaded = false;
  bool _isInitializing = false;
  Object? _initializationError;
  Timer? _dueTimer;
  bool _foreground = true;
  bool _refreshingDue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dueTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshDue(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dueTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_refreshDue());
    if (state == AppLifecycleState.paused) {
      if (mounted) {
        context.read<SecurityProvider>().lockApp();
      }
    }
  }

  Future<void> _refreshDue() async {
    if (!mounted || !_foreground || !_isDataLoaded || _refreshingDue) return;
    _refreshingDue = true;
    final provider = context.read<RoutineProvider>();
    final tx = context.read<TransactionProvider>();
    final wallets = context.read<WalletProvider>();
    final ar = context.read<SettingsProvider>().isArabic;
    try {
      await provider.processAutoRecurringDue(
        txProvider: tx,
        walletProvider: wallets,
      );
      await provider.syncReminders(ar);
    } catch (error) {
      debugPrint('Recurring reconciliation will retry: $error');
    } finally {
      _refreshingDue = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initAppData();
  }

  Future<void> _initAppData() async {
    if (_isDataLoaded || _isInitializing) return;
    final settings = context.read<SettingsProvider>();

    if (!settings.isLoading && mounted) {
      final secProvider = context.read<SecurityProvider>();
      await secProvider.initSecurity();

      // The onboarding flow owns first-time database seeding. Avoid opening
      // the financial database before the user has selected a currency.
      if (settings.isFirstLaunch || !mounted) return;

      _isInitializing = true;
      _initializationError = null;
      setState(() {});

      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();
      final txProvider = context.read<TransactionProvider>();
      final routineProvider = context.read<RoutineProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final goalProvider = context.read<GoalProvider>();
      final debtProvider = context.read<DebtProvider>();

      try {
        await catProvider.loadCategories();
        await walletProvider.loadWallets(settings.currencyCode);
        await txProvider.loadTransactions();
        await routineProvider.loadRoutines();
        await routineProvider.processAutoRecurringDue(
          txProvider: txProvider,
          walletProvider: walletProvider,
        );
        await budgetProvider.loadBudgets();
        await goalProvider.loadGoals();
        await debtProvider.loadDebts();
        await routineProvider.syncReminders(settings.isArabic);
        _isDataLoaded = true;
      } catch (error) {
        _initializationError = error;
      } finally {
        _isInitializing = false;
        if (mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final secProvider = context.watch<SecurityProvider>();

    if (settings.isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'وفير - Waffeer',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: settings.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settings.isFirstLaunch
          ? const CurrencySetupScreen()
          : _initializationError != null
          ? _StartupErrorScreen(
              isArabic: settings.isArabic,
              onRetry: _initAppData,
            )
          : (!_isDataLoaded || _isInitializing)
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (secProvider.isLocked
                ? LockScreen(
                    mode: LockMode.unlock,
                    onUnlocked: () => secProvider.unlock(),
                  )
                : const MainNavigationScreen()),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final bool isArabic;
  final Future<void> Function() onRetry;

  const _StartupErrorScreen({required this.isArabic, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync_problem_rounded,
                  size: 54,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  isArabic
                      ? 'تعذر تحميل بياناتك بأمان'
                      : 'Your data could not be loaded safely',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'تحقق من مساحة التخزين ثم حاول مجددًا. ستُستكمل المستحقات دون تكرار المسجّل منها.'
                      : 'Check storage and retry. Due entries will resume without duplicating recorded occurrences.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
