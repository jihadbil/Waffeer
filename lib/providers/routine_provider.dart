import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/database/db_helper.dart';
import '../core/services/notification_service.dart';
import '../data/models/routine_expense_model.dart';
import '../data/models/transaction_model.dart';
import 'transaction_provider.dart';
import 'wallet_provider.dart';

class RoutineTemplate {
  final String titleAr;
  final String titleEn;
  final double defaultAmount;
  final String defaultCategoryId;
  final int iconCodePoint;
  final int colorValue;
  final RoutineFrequency suggestedFrequency;
  final int suggestedIntervalDays;

  const RoutineTemplate({
    required this.titleAr,
    required this.titleEn,
    required this.defaultAmount,
    required this.defaultCategoryId,
    required this.iconCodePoint,
    required this.colorValue,
    this.suggestedFrequency = RoutineFrequency.manual,
    this.suggestedIntervalDays = 2,
  });

  String localizedTitle(bool isArabic) => isArabic ? titleAr : titleEn;
}

class RoutineProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  RoutineProvider({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper.instance;
  List<RoutineExpenseModel> _routines = [];
  bool _isLoading = false;
  Future<int>? _processing;
  String? _lastLoggedTransactionId;
  bool get isLoading => _isLoading;
  bool get canUndo => _lastLoggedTransactionId != null;
  List<RoutineExpenseModel> get routines => List.unmodifiable(_routines);
  List<RoutineExpenseModel> get activeRoutines =>
      _routines.where((r) => r.isActive).toList();
  List<RoutineExpenseModel> get quickRoutines =>
      activeRoutines.where((r) => r.mode == RecordingMode.manual).toList();
  List<RoutineExpenseModel> get autoRecurringRoutines =>
      activeRoutines.where((r) => r.isAutoRecurring).toList();
  List<RoutineExpenseModel> get dueAutoRoutines =>
      autoRecurringRoutines.where(_due).toList();
  List<RoutineExpenseModel> get dueReminders =>
      activeRoutines
          .where((r) => r.mode == RecordingMode.reminder && _due(r))
          .toList()
        ..sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
  bool _due(RoutineExpenseModel r) =>
      r.nextDueDate != null && !r.nextDueDate!.isAfter(DateTime.now());

  static List<RoutineTemplate> get presetTemplates => const [
    RoutineTemplate(
      titleAr: 'قهوة الصباح',
      titleEn: 'Morning Coffee',
      defaultAmount: 15.0,
      defaultCategoryId: 'cat_food',
      iconCodePoint: 0xe541, // local_cafe
      colorValue: 0xFF92400E, // Amber brown
      suggestedFrequency: RoutineFrequency.daily,
    ),
    RoutineTemplate(
      titleAr: 'مواصلات وتاكسي',
      titleEn: 'Taxi & Transit',
      defaultAmount: 25.0,
      defaultCategoryId: 'cat_transport',
      iconCodePoint: 0xe354, // local_taxi
      colorValue: 0xFF2563EB, // Blue
      suggestedFrequency: RoutineFrequency.everyXDays,
      suggestedIntervalDays: 2,
    ),
    RoutineTemplate(
      titleAr: 'وجبة غداء عمل',
      titleEn: 'Work Lunch',
      defaultAmount: 30.0,
      defaultCategoryId: 'cat_food',
      iconCodePoint: 0xe57a, // restaurant
      colorValue: 0xFFEA580C, // Orange
      suggestedFrequency: RoutineFrequency.daily,
    ),
    RoutineTemplate(
      titleAr: 'بنزين ووقود',
      titleEn: 'Fuel / Gas',
      defaultAmount: 80.0,
      defaultCategoryId: 'cat_transport',
      iconCodePoint: 0xe344, // local_gas_station
      colorValue: 0xFF0284C7, // Sky blue
      suggestedFrequency: RoutineFrequency.weekly,
    ),
    RoutineTemplate(
      titleAr: 'خبز وبقالة يومية',
      titleEn: 'Daily Groceries',
      defaultAmount: 20.0,
      defaultCategoryId: 'cat_shopping',
      iconCodePoint: 0xe59c, // shopping_cart
      colorValue: 0xFF16A34A, // Green
      suggestedFrequency: RoutineFrequency.everyXDays,
      suggestedIntervalDays: 3,
    ),
    RoutineTemplate(
      titleAr: 'مستلزمات وصيدلية',
      titleEn: 'Pharmacy',
      defaultAmount: 35.0,
      defaultCategoryId: 'cat_health',
      iconCodePoint: 0xe3be, // local_hospital
      colorValue: 0xFF059669, // Emerald
      suggestedFrequency: RoutineFrequency.manual,
    ),
  ];

  Future<void> loadRoutines() async {
    _isLoading = true;
    notifyListeners();
    try {
      _routines = await _dbHelper.getAllRoutineExpenses();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refresh(TransactionProvider tx, WalletProvider wallets) async {
    await tx.loadTransactions();
    await wallets.loadWallets(wallets.defaultWallet?.currencyCode ?? 'USD');
    await loadRoutines();
  }

  Future<String?> quickLogExpense(
    RoutineExpenseModel routine, {
    required TransactionProvider txProvider,
    required WalletProvider walletProvider,
    double? customAmount,
    String? customNote,
    DateTime? executionDate,
    bool confirmDue = false,
  }) async {
    final id = await _dbHelper.recordRoutine(
      routine.id,
      amount: customAmount,
      note: customNote,
      now: executionDate,
      dueDate: confirmDue ? routine.nextDueDate : null,
    );
    if (id != null) _lastLoggedTransactionId = id;
    await _refresh(txProvider, walletProvider);
    return id;
  }

  Future<bool> undoQuickLog(
    String transactionId, {
    required TransactionProvider txProvider,
    required WalletProvider walletProvider,
  }) async {
    final done = await _dbHelper.undoRoutineTransaction(transactionId);
    if (_lastLoggedTransactionId == transactionId) {
      _lastLoggedTransactionId = null;
    }
    await _refresh(txProvider, walletProvider);
    return done;
  }

  Future<bool> undoLastQuickLog({
    required TransactionProvider txProvider,
    required WalletProvider walletProvider,
  }) async {
    final id = _lastLoggedTransactionId;
    return id == null
        ? false
        : undoQuickLog(
            id,
            txProvider: txProvider,
            walletProvider: walletProvider,
          );
  }

  Future<int> processAutoRecurringDue({
    required TransactionProvider txProvider,
    required WalletProvider walletProvider,
  }) {
    return _processing ??= _process(
      txProvider,
      walletProvider,
    ).whenComplete(() => _processing = null);
  }

  Future<int> _process(TransactionProvider tx, WalletProvider wallets) async {
    try {
      return await _dbHelper.processRoutineDue();
    } finally {
      await _refresh(tx, wallets);
    }
  }

  Future<void> syncReminders(bool isArabic) => NotificationService.instance
      .syncRoutineReminders(_routines, isArabic: isArabic);

  Future<void> addRoutine({
    String? id,
    required String title,
    required double amount,
    required String categoryId,
    required String walletId,
    required String currencyCode,
    String? note,
    int? iconCodePoint,
    int? colorValue,
    bool isAutoRecurring = false,
    RecordingMode? mode,
    TransactionType type = TransactionType.expense,
    String? toWalletId,
    RoutineFrequency frequency = RoutineFrequency.manual,
    int intervalDays = 2,
    DateTime? nextDueDate,
  }) async {
    final recording =
        mode ??
        (isAutoRecurring ? RecordingMode.automatic : RecordingMode.manual);
    final date = recording == RecordingMode.manual
        ? null
        : nextDueDate ?? DateTime.now();
    await _dbHelper.saveRoutine(
      RoutineExpenseModel(
        id: id ?? const Uuid().v4(),
        title: title,
        amount: amount,
        categoryId: categoryId,
        walletId: walletId,
        currencyCode: currencyCode,
        note: note,
        iconCodePoint: iconCodePoint,
        colorValue: colorValue,
        mode: recording,
        type: type,
        toWalletId: toWalletId,
        frequency: recording == RecordingMode.manual
            ? RoutineFrequency.manual
            : frequency,
        intervalDays: intervalDays,
        nextDueDate: date,
        anchorDay: date?.day,
        anchorMonth: date?.month,
      ),
    );
    await loadRoutines();
  }

  Future<void> updateRoutine(
    RoutineExpenseModel item, {
    RoutineExpenseModel? previous,
  }) async {
    await _dbHelper.saveRoutine(item, expected: previous);
    await loadRoutines();
  }

  Future<void> toggleActive(String id) async {
    final item = getById(id);
    if (item == null) return;
    var next = item.nextDueDate;
    if (!item.isActive && item.isScheduled && next != null) {
      final now = DateTime.now();
      while (next!.isBefore(now)) {
        next = item.calculateNextDate(next);
      }
    }
    await updateRoutine(
      item.copyWith(isActive: !item.isActive, nextDueDate: next),
      previous: item,
    );
  }

  Future<void> deleteRoutine(String id) async {
    await _dbHelper.deleteRoutineExpense(id);
    await loadRoutines();
  }

  RoutineExpenseModel? getById(String id) {
    for (final item in _routines) {
      if (item.id == id) return item;
    }
    return null;
  }
}
