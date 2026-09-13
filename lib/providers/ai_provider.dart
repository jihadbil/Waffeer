import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/services/ai_service.dart';
import '../core/utils/category_matcher.dart';
import '../data/models/ai_action.dart';
import '../data/models/ai_chat_message.dart';
import '../data/models/budget_model.dart';
import '../data/models/category_model.dart';
import '../data/models/debt_model.dart';
import '../data/models/parsed_ai_expense.dart';
import '../data/models/receipt_model.dart';
import '../data/models/transaction_model.dart';
import '../data/models/wallet_model.dart';
import 'budget_provider.dart';
import 'category_provider.dart';
import 'debt_provider.dart';
import 'goal_provider.dart';
import 'settings_provider.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

/// مزود حالة وتفاعل ميزات الذكاء الاصطناعي لتطبيق وفير
class AiProvider with ChangeNotifier {
  final AiService _aiService = AiService.instance;

  final List<AiChatMessage> _chatMessages = [];
  bool _isAdvisorThinking = false;
  bool _isParsingExpense = false;
  bool _isScanningVision = false;
  bool _isTestingKey = false;
  String? _dashboardInsight;
  bool _isLoadingInsight = false;

  List<AiChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  bool get isAdvisorThinking => _isAdvisorThinking;
  bool get isParsingExpense => _isParsingExpense;
  bool get isScanningVision => _isScanningVision;
  bool get isTestingKey => _isTestingKey;
  String? get dashboardInsight => _dashboardInsight;
  bool get isLoadingInsight => _isLoadingInsight;

  AiProvider() {
    _initializeDefaultChat();
  }

  void _initializeDefaultChat() {
    _chatMessages.add(
      AiChatMessage(
        content: 'أهلاً بك! أنا مستشارك المالي الذكي في "وفير" 🪙✨\n\nكيف يمكنني مساعدتك اليوم؟ يمكنك سؤالي عن تحليلاتك المالية أو أن تطلب مني مباشرة تنفيذ المهام نيابة عنك مثل: تسجيل المصاريف والدخل، ضبط الميزانيات، أو تغيير الإعدادات!',
        isUser: false,
        suggestedFollowUps: [
          'سجل مصروف 45 ريال قهوة كاش',
          'سجل دخل 2500 ريال مكافأة',
          'أضف تصنيف اشتراكات',
          'ما هو تقييمك لوضعي المالي هذا الشهر؟',
          'فعل الوضع الداكن',
        ],
      ),
    );
  }

  /// مسح المحادثة وإعادة تعيين الترحيب المبدئي
  void clearChat() {
    _chatMessages.clear();
    _initializeDefaultChat();
    notifyListeners();
  }

  /// اختبار صلاحية مفتاح الـ API
  Future<bool> testKey(String key) async {
    _isTestingKey = true;
    notifyListeners();
    try {
      final success = await _aiService.testConnection(key);
      _isTestingKey = false;
      notifyListeners();
      return success;
    } catch (_) {
      _isTestingKey = false;
      notifyListeners();
      return false;
    }
  }

  /// إرسال سؤال للمستشار المالي مع إرفاق السياق المالي المشفر وتنفيذ الأوامر إن وجدت
  Future<void> sendAdvisorMessage({
    required String question,
    required BuildContext context,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _isAdvisorThinking) return;

    final settings = context.read<SettingsProvider>();
    final catProvider = context.read<CategoryProvider>();
    final walletProvider = context.read<WalletProvider>();
    final apiKey = settings.aiApiKey;
    final isArabic = settings.isArabic;

    // أخذ لقطة من السجل التاريخي قبل إضافة رسالة المستخدم الجديدة
    final historySnapshot = List<AiChatMessage>.from(_chatMessages);

    // 1. إضافة رسالة المستخدم للواجهة فورا
    _chatMessages.add(
      AiChatMessage(
        content: trimmed,
        isUser: true,
      ),
    );
    _isAdvisorThinking = true;
    notifyListeners();

    // 2. بناء السياق المالي الرقمي
    final summary = buildFinancialSummary(context);

    // 3. طلب الإجابة من الذكاء الاصطناعي واستخراج أي أوامر تنفيذية
    final result = await _aiService.askFinancialAdvisor(
      apiKey: apiKey,
      userMessage: trimmed,
      financialContextSummary: summary,
      history: historySnapshot,
      isArabic: isArabic,
      categories: catProvider.categories,
      wallets: walletProvider.wallets,
    );

    // 4. تنفيذ جميع الأوامر تلقائياً إن وجدت في الرد
    if (result.actions.isNotEmpty && context.mounted) {
      for (final action in result.actions) {
        try {
          await _dispatchAction(action, context);
        } catch (e) {
          debugPrint('Failed to dispatch AI action: $e');
          action.isExecuted = false;
        }
      }
    }

    _chatMessages.add(
      AiChatMessage(
        content: result.message,
        isUser: false,
        actions: result.actions,
      ),
    );
    _isAdvisorThinking = false;
    notifyListeners();
  }

  /// تنفيذ الإجراءات المالية والإعدادية داخل التطبيق
  Future<void> _dispatchAction(AiAction action, BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final catProvider = context.read<CategoryProvider>();
    final walletProvider = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();
    final budgetProvider = context.read<BudgetProvider>();

    switch (action.type) {
      case AiActionType.addExpense:
      case AiActionType.addIncome:
        final isIncome = action.type == AiActionType.addIncome;
        final amount = (action.data['amount'] as num?)?.toDouble() ?? 0.0;
        final title = (action.data['title'] as String?)?.trim() ??
            (isIncome ? 'دخل جديد' : 'مصروف جديد');
        final categoryId = action.data['category_id'] as String?;
        final categoryName = (action.data['category_name'] as String?)?.trim();
        final walletId = action.data['wallet_id'] as String?;
        final walletName = (action.data['wallet_name'] as String?)?.trim();

        // 1. مطابقة التصنيف الذكية عبر CategoryMatcher
        final targetCategory = CategoryMatcher.findBestCategory(
          categories: catProvider.categories,
          targetType: isIncome ? CategoryType.income : CategoryType.expense,
          categoryId: categoryId,
          categoryName: categoryName,
          fallbackQuery: title,
        );

        // 2. مطابقة المحفظة
        WalletModel? targetWallet;
        if (walletId != null && walletId.isNotEmpty) {
          targetWallet = walletProvider.wallets.where((w) => w.id == walletId).firstOrNull;
        }
        if (targetWallet == null && walletName != null && walletName.isNotEmpty) {
          final q = CategoryMatcher.normalizeArabic(walletName);
          for (final w in walletProvider.wallets) {
            final nwAr = CategoryMatcher.normalizeArabic(w.nameAr);
            final nwEn = w.nameEn.toLowerCase();
            if (nwAr == q || nwEn == q || nwAr.contains(q) || q.contains(nwAr)) {
              targetWallet = w;
              break;
            }
          }
        }
        targetWallet ??= walletProvider.wallets.where((w) => w.isDefault).firstOrNull ??
            (walletProvider.wallets.isNotEmpty ? walletProvider.wallets.first : null);

        if (targetWallet == null) return;

        // 3. منع التكرار اللحظي (Idempotency Guard)
        final recentTxs = txProvider.transactions.take(5);
        final isDuplicateRecently = recentTxs.any((t) =>
            t.amount == amount &&
            t.type == (isIncome ? TransactionType.income : TransactionType.expense) &&
            t.categoryId == targetCategory.id &&
            t.walletId == targetWallet!.id &&
            DateTime.now().difference(t.dateTime).inSeconds < 4);

        if (isDuplicateRecently) {
          debugPrint('Prevented duplicate AI transaction execution for $title ($amount)');
          action.isExecuted = true;
          return;
        }

        // 4. إضافة المعاملة وحفظ معرفها لإمكانية التراجع
        final txId = const Uuid().v4();
        await txProvider.addTransaction(
          transactionId: txId,
          amount: amount,
          type: isIncome ? TransactionType.income : TransactionType.expense,
          categoryId: targetCategory.id,
          walletId: targetWallet.id,
          dateTime: DateTime.now(),
          title: title,
          currencyCode: settings.currencyCode,
          walletProvider: walletProvider,
        );

        action.executedEntityId = txId;
        action.isExecuted = true;
        break;

      case AiActionType.addCategory:
        final name = (action.data['name'] as String?)?.trim() ??
            (settings.isArabic ? 'تصنيف جديد' : 'New Category');
        final isIncome = action.data['type'] == 'income';
        final catType = isIncome ? CategoryType.income : CategoryType.expense;

        // التحقق من عدم وجود التصنيف مسبقاً بالتطبيع العربي
        final normName = CategoryMatcher.normalizeArabic(name);
        final existing = catProvider.categories.where(
          (c) =>
              CategoryMatcher.normalizeArabic(c.nameAr) == normName ||
              c.nameEn.toLowerCase() == name.toLowerCase(),
        );
        if (existing.isNotEmpty) {
          action.executedEntityId = existing.first.id;
          action.isExecuted = true;
          return;
        }

        await catProvider.addCategory(
          nameEn: name,
          nameAr: name,
          iconCodePoint: isIncome ? Icons.attach_money.codePoint : Icons.category.codePoint,
          colorValue: isIncome ? Colors.teal.toARGB32() : Colors.indigo.toARGB32(),
          type: catType,
        );

        final created = catProvider.categories.lastWhere(
          (c) => c.nameAr == name || c.nameEn == name,
          orElse: () => catProvider.categories.last,
        );
        action.executedEntityId = created.id;
        action.isExecuted = true;
        break;

      case AiActionType.changeTheme:
        final modeStr = (action.data['mode'] as String?)?.trim().toLowerCase();
        ThemeMode targetMode;
        if (modeStr == 'dark') {
          targetMode = ThemeMode.dark;
        } else if (modeStr == 'light') {
          targetMode = ThemeMode.light;
        } else {
          targetMode = ThemeMode.system;
        }

        action.data['previous_mode'] = settings.themeMode.name;
        await settings.setThemeMode(targetMode);
        action.isExecuted = true;
        break;

      case AiActionType.changeCurrency:
        final currencyCode = (action.data['currency_code'] as String?)?.trim().toUpperCase() ?? 'SAR';
        action.data['previous_currency'] = settings.currencyCode;
        await settings.setCurrency(currencyCode);
        action.isExecuted = true;
        break;

      case AiActionType.addBudget:
        final amount = (action.data['amount'] as num?)?.toDouble() ?? 0.0;
        final categoryName = (action.data['category_name'] as String?)?.trim();
        final categoryId = action.data['category_id'] as String?;
        CategoryModel? targetCategory;
        if (categoryName != null &&
            categoryName.isNotEmpty &&
            !categoryName.contains('شامل') &&
            !categoryName.toLowerCase().contains('overall')) {
          targetCategory = CategoryMatcher.findBestCategory(
            categories: catProvider.expenseCategories,
            targetType: CategoryType.expense,
            categoryId: categoryId,
            categoryName: categoryName,
          );
        }

        final now = DateTime.now();
        final startDate = DateTime(now.year, now.month, 1);
        final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        await budgetProvider.addBudget(
          categoryId: targetCategory?.id,
          limitAmount: amount,
          period: BudgetPeriod.monthly,
          startDate: startDate,
          endDate: endDate,
          currencyCode: settings.currencyCode,
        );

        if (budgetProvider.budgets.isNotEmpty) {
          action.executedEntityId = budgetProvider.budgets.last.id;
        }
        action.isExecuted = true;
        break;

      case AiActionType.unknown:
        break;
    }
  }

  /// التراجع عن الإجراء المنفذ بواسطة المستشار الذكي
  Future<bool> undoAction(AiAction action, BuildContext context) async {
    if (action.isUndone) return false;

    final settings = context.read<SettingsProvider>();
    final catProvider = context.read<CategoryProvider>();
    final walletProvider = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();
    final budgetProvider = context.read<BudgetProvider>();

    try {
      switch (action.type) {
        case AiActionType.addExpense:
        case AiActionType.addIncome:
          final txId = action.executedEntityId;
          if (txId != null) {
            final tx = txProvider.transactions.cast<TransactionModel?>().firstWhere(
              (t) => t?.id == txId,
              orElse: () => null,
            );
            if (tx != null) {
              await txProvider.deleteTransaction(tx, walletProvider: walletProvider);
            }
          }
          break;

        case AiActionType.addCategory:
          final catId = action.executedEntityId;
          if (catId != null) {
            await catProvider.deleteCategory(catId);
          }
          break;

        case AiActionType.changeTheme:
          final prevModeStr = action.data['previous_mode'] as String?;
          if (prevModeStr != null) {
            final prevMode = ThemeMode.values.firstWhere(
              (m) => m.name == prevModeStr,
              orElse: () => ThemeMode.system,
            );
            await settings.setThemeMode(prevMode);
          }
          break;

        case AiActionType.changeCurrency:
          final prevCurr = action.data['previous_currency'] as String?;
          if (prevCurr != null && prevCurr.isNotEmpty) {
            await settings.setCurrency(prevCurr);
          }
          break;

        case AiActionType.addBudget:
          final budgetId = action.executedEntityId;
          if (budgetId != null) {
            await budgetProvider.deleteBudget(budgetId);
          }
          break;

        case AiActionType.unknown:
          break;
      }

      action.isUndone = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to undo AI action: $e');
      return false;
    }
  }

  /// تحليل النصوص السريعة ورسائل البنوك (SMS)
  Future<ParsedAiExpense> parseExpenseText({
    required String input,
    required BuildContext context,
  }) async {
    _isParsingExpense = true;
    notifyListeners();

    try {
      final settings = context.read<SettingsProvider>();
      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();

      final result = await _aiService.parseExpensePrompt(
        apiKey: settings.aiApiKey,
        input: input,
        categories: catProvider.categories,
        wallets: walletProvider.wallets,
        defaultCurrency: settings.currencyCode,
        isArabic: settings.isArabic,
      );

      _isParsingExpense = false;
      notifyListeners();
      return result;
    } catch (_) {
      _isParsingExpense = false;
      notifyListeners();
      return ParsedAiExpense(
        title: input,
        rawInput: input,
        confidence: 0.0,
      );
    }
  }

  /// مسح الفاتورة عبر Gemini Vision
  Future<ParsedReceipt?> scanReceiptWithGemini({
    required File imageFile,
    required BuildContext context,
  }) async {
    _isScanningVision = true;
    notifyListeners();

    try {
      final settings = context.read<SettingsProvider>();
      final catProvider = context.read<CategoryProvider>();

      final result = await _aiService.scanReceiptWithVision(
        apiKey: settings.aiApiKey,
        imageFile: imageFile,
        categories: catProvider.categories,
        isArabic: settings.isArabic,
      );

      _isScanningVision = false;
      notifyListeners();
      return result;
    } catch (_) {
      _isScanningVision = false;
      notifyListeners();
      return null;
    }
  }

  /// تحديث النصيحة الذكية في لوحة التحكم
  Future<void> fetchDashboardInsight(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isAiEnabled || settings.aiApiKey.isEmpty) return;

    _isLoadingInsight = true;
    notifyListeners();

    try {
      final summary = buildFinancialSummary(context);
      final tip = await _aiService.generateDashboardTip(
        apiKey: settings.aiApiKey,
        financialContextSummary: summary,
        isArabic: settings.isArabic,
      );
      if (tip != null && tip.isNotEmpty) {
        _dashboardInsight = tip;
      }
    } catch (_) {}

    _isLoadingInsight = false;
    notifyListeners();
  }

  /// تجميع ملخص رقمي مجهول الهوية للسياق المالي
  static String buildFinancialSummary(BuildContext context) {
    try {
      final settings = context.read<SettingsProvider>();
      final wallets = context.read<WalletProvider>();
      final tx = context.read<TransactionProvider>();
      final budgets = context.read<BudgetProvider>();
      final goals = context.read<GoalProvider>();
      final debts = context.read<DebtProvider>();

      final buffer = StringBuffer();
      buffer.writeln('العملة: ${settings.currencyCode}');
      buffer.writeln('إجمالي الرصيد الحالي: ${wallets.totalBalance.toStringAsFixed(2)}');
      buffer.writeln('دخل الشهر الحالي: ${tx.monthlyIncome.toStringAsFixed(2)}');
      buffer.writeln('مصاريف الشهر الحالي: ${tx.monthlyExpense.toStringAsFixed(2)}');
      final net = tx.monthlyIncome - tx.monthlyExpense;
      buffer.writeln('صافي الوفر الشهري: ${net.toStringAsFixed(2)}');

      // تفاصيل الميزانيات
      final catProvider = context.read<CategoryProvider>();
      if (budgets.budgets.isNotEmpty) {
        buffer.writeln('\nالميزانيات:');
        for (final b in budgets.budgets) {
          final spent = budgets.getSpentAmount(b, tx.transactions);
          final ratio = b.limitAmount > 0 ? (spent / b.limitAmount) * 100 : 0.0;
          String budgetName = settings.isArabic ? 'الميزانية الشاملة' : 'Total Budget';
          if (b.categoryId != null) {
            final cat = catProvider.getById(b.categoryId!);
            if (cat != null) {
              budgetName = settings.isArabic ? cat.nameAr : cat.nameEn;
            }
          }
          buffer.writeln('- ميزانية $budgetName: المصروف ${spent.toStringAsFixed(1)} من ${b.limitAmount.toStringAsFixed(1)} (${ratio.toStringAsFixed(0)}%)');
        }
      }

      // الأهداف المالية
      if (goals.goals.isNotEmpty) {
        buffer.writeln('\nأهداف الادخار:');
        for (final g in goals.goals) {
          buffer.writeln('- هدف ${g.title}: تم تجميع ${g.savedAmount.toStringAsFixed(1)} من ${g.targetAmount.toStringAsFixed(1)}');
        }
      }

      // الديون والالتزامات (مع إخفاء هوية الأشخاص لحماية الخصوصية)
      if (debts.debts.isNotEmpty) {
        buffer.writeln('\nالديون والالتزامات:');
        int debtIndex = 1;
        for (final d in debts.debts) {
          final isLent = d.type == DebtType.lend;
          final typeLabel = isLent ? 'مستحق لك من طرف' : 'التزام عليك لطرف';
          buffer.writeln('- $typeLabel $debtIndex: المبلغ المتبقي ${d.remainingAmount.toStringAsFixed(1)}');
          debtIndex++;
        }
      }

      return buffer.toString();
    } catch (_) {
      return 'سياق مالي افتراضي';
    }
  }
}
