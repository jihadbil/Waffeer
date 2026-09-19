import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/routine_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../core/services/receipt_scanner_service.dart';
import '../../../data/models/parsed_ai_expense.dart';
import '../../../providers/ai_provider.dart';
import '../../widgets/category_icon_widget.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import 'receipt_scanner_screen.dart';

/// شاشة إضافة أو تعديل معاملة مالية (مصروف / دخل / تحويل مالي)
///
/// تدعم الشاشة:
/// 1. إدخال وتعديل المبلغ، العنوان، التصنيف، المحفظة، والتاريخ.
/// 2. استقبال بيانات أولية مسبقة من الماسح الضوئي الذكي للفواتير [ReceiptScannerScreen].
/// 3. ميزة المسح الذكي الفوري من داخل الشاشة لاستخراج البيانات وتعبئة الحقول آلياً.
class AddEditTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;

  /// نوع المعاملة الأولي (مصروف، دخل، أو تحويل)
  final TransactionType initialType;

  /// المبلغ الأولي في حال التمرير من ماسح الفواتير
  final double? initialAmount;

  /// العنوان أو اسم المتجر الأولي
  final String? initialTitle;

  /// معرّف التصنيف المقترح الأولي
  final String? initialCategoryId;

  /// تاريخ المعاملة الأولي
  final DateTime? initialDate;

  /// مسار صورة الفاتورة المرفقة
  final String? initialReceiptImagePath;

  /// ملاحظات أولية إضافية
  final String? initialNote;

  const AddEditTransactionScreen({
    super.key,
    this.transaction,
    this.initialType = TransactionType.expense,
    this.initialAmount,
    this.initialTitle,
    this.initialCategoryId,
    this.initialDate,
    this.initialReceiptImagePath,
    this.initialNote,
  });

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  // نوع المعاملة المحدد حالياً
  late TransactionType _selectedType;

  // متحكمات النصوص
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedWalletId;
  String? _selectedToWalletId;
  DateTime _selectedDate = DateTime.now();
  String? _receiptImagePath;
  final Set<String> _pendingReceiptPaths = <String>{};
  final ImagePicker _picker = ImagePicker();

  /// حالة المعالجة عند المسح الذكي للفاتورة من داخل الشاشة
  bool _isScanning = false;
  bool _showAdvancedDetails = false;
  bool _isSaving = false;
  bool _saveAsRoutine = false;
  final String _newTransactionId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;

    // تعبئة البيانات الأولية في حال تم تمريرها من الماسح الضوئي
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount! % 1 == 0
          ? widget.initialAmount!.toInt().toString()
          : widget.initialAmount!.toStringAsFixed(2);
    }
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }
    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId;
    }
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialReceiptImagePath != null) {
      _receiptImagePath = widget.initialReceiptImagePath;
      if (widget.transaction == null) {
        _pendingReceiptPaths.add(widget.initialReceiptImagePath!);
      }
    }

    final existing = widget.transaction;
    if (existing != null) {
      _selectedType = existing.type;
      _amountController.text = existing.amount % 1 == 0
          ? existing.amount.toInt().toString()
          : existing.amount.toStringAsFixed(2);
      _titleController.text = existing.title ?? '';
      _noteController.text = existing.note ?? '';
      _selectedCategoryId = existing.categoryId;
      _selectedWalletId = existing.walletId;
      _selectedToWalletId = existing.toWalletId;
      _selectedDate = existing.dateTime;
      _receiptImagePath = existing.receiptImagePath;
    }

    _showAdvancedDetails =
        existing != null ||
        widget.initialReceiptImagePath != null ||
        widget.initialTitle != null ||
        widget.initialNote != null ||
        widget.initialDate != null;

    // تعيين المحفظة والتصنيف الافتراضيين بعد اكتمال بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();

      if (_selectedCategoryId == null) {
        if (_selectedType == TransactionType.expense &&
            catProvider.expenseCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.expenseCategories.first.id;
        } else if (_selectedType == TransactionType.income &&
            catProvider.incomeCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.incomeCategories.first.id;
        }
      }

      if (_selectedWalletId == null && walletProvider.wallets.isNotEmpty) {
        _selectedWalletId =
            walletProvider.defaultWallet?.id ?? walletProvider.wallets.first.id;
        if (walletProvider.wallets.length > 1) {
          _selectedToWalletId = walletProvider.wallets[1].id;
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final path in _pendingReceiptPaths) {
      unawaited(ReceiptScannerService.deleteManagedReceipt(path));
    }
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// مسح الفاتورة بالكاميرا أو المعرض واستخراج البيانات وتعبئة حقول الشاشة آلياً
  Future<void> _scanAndAutoFill(ImageSource source) async {
    String? persistedPath;
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile == null) return;

      setState(() {
        _isScanning = true;
      });

      final file = File(pickedFile.path);
      persistedPath = await ReceiptScannerService.persistReceiptImage(
        pickedFile.path,
      );
      // معالجة الفاتورة واستخراج البيانات
      final parsed = await ReceiptScannerService.instance.scanReceipt(file);

      if (mounted) {
        final catProvider = context.read<CategoryProvider>();
        final isArabic = context.read<SettingsProvider>().isArabic;

        // مطابقة التصنيف المستخرج
        String? newCatId = parsed.suggestedCategoryId;
        if (newCatId != null) {
          final exists = catProvider.expenseCategories.any(
            (c) => c.id == newCatId,
          );
          if (!exists && catProvider.expenseCategories.isNotEmpty) {
            newCatId = catProvider.expenseCategories.first.id;
          }
        }

        // تحديث الحقول في الشاشة بالبيانات المستخرجة
        final previousPath = _receiptImagePath;
        setState(() {
          _isScanning = false;
          _receiptImagePath = persistedPath;
          _pendingReceiptPaths.add(persistedPath!);
          _selectedType = TransactionType.expense;

          if (parsed.totalAmount != null) {
            _amountController.text = parsed.totalAmount! % 1 == 0
                ? parsed.totalAmount!.toInt().toString()
                : parsed.totalAmount!.toStringAsFixed(2);
          }

          if (parsed.merchantName != null &&
              parsed.merchantName!.trim().isNotEmpty) {
            _titleController.text = parsed.merchantName!.trim();
          }

          if (parsed.dateTime != null) {
            _selectedDate = parsed.dateTime!;
          }

          if (newCatId != null) {
            _selectedCategoryId = newCatId;
          }
        });
        if (previousPath != null && _pendingReceiptPaths.remove(previousPath)) {
          unawaited(ReceiptScannerService.deleteManagedReceipt(previousPath));
        }

        // إظهار إشعار نجاح استخراج البيانات
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تم استخراج بيانات الفاتورة بنجاح: ${parsed.totalAmount != null ? "${parsed.totalAmount} " : ""}'
                        : 'Receipt data extracted successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await ReceiptScannerService.deleteManagedReceipt(persistedPath);
      }
    } catch (e) {
      if (persistedPath != null) {
        _pendingReceiptPaths.remove(persistedPath);
        await ReceiptScannerService.deleteManagedReceipt(persistedPath);
      }
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        final isArabic = context.read<SettingsProvider>().isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'حدث خطأ أثناء قراءة الفاتورة'
                  : 'Error scanning receipt',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  Future<void> _openSmartAiFiller() async {
    final textController = TextEditingController();
    final isArabic = context.read<SettingsProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final parsed = await showModalBottomSheet<ParsedAiExpense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final ai = modalCtx.watch<AiProvider>();
          final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: bottomInset > 0 ? bottomInset + 16 : 28,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      isArabic
                          ? 'تعبئة تلقائية ذكية (نص أو SMS)'
                          : 'Smart AI Autofill (Text or SMS)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: textController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'الصق رسالة البنك أو اكتب مثل: 50 ريال كاش بنزين'
                          : 'Paste SMS or type expense...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: ai.isParsingExpense
                      ? null
                      : () async {
                          final res = await ai.parseExpenseText(
                            input: textController.text.trim(),
                            context: context,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, res);
                        },
                  icon: ai.isParsingExpense
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    isArabic
                        ? 'استخراج وتعبئة الحقول ✨'
                        : 'Extract & Fill Fields ✨',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (parsed != null && mounted) {
      setState(() {
        if (parsed.amount != null) {
          _amountController.text = parsed.amount!.toStringAsFixed(
            parsed.amount! % 1 == 0 ? 0 : 2,
          );
        }
        if (parsed.title.isNotEmpty) {
          _titleController.text = parsed.title;
        }
        if (parsed.suggestedCategoryId != null) {
          _selectedCategoryId = parsed.suggestedCategoryId;
        }
        if (parsed.suggestedWalletId != null) {
          _selectedWalletId = parsed.suggestedWalletId;
        }
        if (parsed.date != null) {
          _selectedDate = parsed.date!;
        }
        if (parsed.isIncome) {
          _selectedType = TransactionType.income;
        }
        if (parsed.note != null && parsed.note!.isNotEmpty) {
          _noteController.text = parsed.note!;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final catProvider = context.watch<CategoryProvider>();
    final walletProvider = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = _selectedType == TransactionType.expense
        ? catProvider.expenseCategories
        : catProvider.incomeCategories;

    final Color accentColor = _selectedType == TransactionType.expense
        ? AppColors.expense
        : _selectedType == TransactionType.income
        ? AppColors.income
        : AppColors.transfer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null
              ? (isArabic ? 'تعديل المعاملة' : 'Edit Transaction')
              : (isArabic ? 'إضافة معاملة جديدة' : 'Add Transaction'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        actions: [
          if (settings.isAiEnabled)
            IconButton(
              tooltip: isArabic
                  ? 'تعبئة ذكية بالذكاء الاصطناعي'
                  : 'Smart AI Autofill',
              icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
              onPressed: _openSmartAiFiller,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. محول نوع المعاملة التفاعلي (مصروف / دخل / تحويل)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFDCE7E1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  _buildTypeTab(
                    type: TransactionType.expense,
                    label: isArabic ? 'مصروف' : 'Expense',
                    icon: Icons.arrow_upward_rounded,
                    activeColor: AppColors.expense,
                  ),
                  _buildTypeTab(
                    type: TransactionType.income,
                    label: isArabic ? 'دخل' : 'Income',
                    icon: Icons.arrow_downward_rounded,
                    activeColor: AppColors.income,
                  ),
                  _buildTypeTab(
                    type: TransactionType.transfer,
                    label: isArabic ? 'تحويل' : 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    activeColor: AppColors.transfer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. بطاقة إدخال المبلغ الرئيسية (Hero Amount Display)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accentColor.withValues(alpha: isDark ? 0.4 : 0.25),
                  width: 1.5,
                ),
                boxShadow: const [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isArabic ? 'المبلغ المطلوب تسجيله' : 'Transaction Amount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        settings.currency.symbol,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(width: 8),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          autofocus: widget.initialAmount == null,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF163C30),
                            fontFamily: 'Cairo',
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. شريط اختيار التصنيفات (للمصروف والدخل)
            if (_selectedType != TransactionType.transfer) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'التصنيف المالي' : 'Category',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    '${categories.length} ${isArabic ? "تصنيف" : "categories"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (ctx, idx) {
                    final cat = categories[idx];
                    final isSelected = cat.id == _selectedCategoryId;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategoryId = cat.id);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 82,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cat.color.withValues(
                                  alpha: isDark ? 0.28 : 0.16,
                                )
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? cat.color
                                : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: const [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CategoryIconWidget(
                              iconData: cat.iconData,
                              color: cat.color,
                              size: 42,
                              iconSize: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.localizedName(isArabic),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
            ],

            // 4. اختيار المحفظة / الحساب
            Text(
              _selectedType == TransactionType.transfer
                  ? (isArabic ? 'من حساب / محفظة' : 'From Wallet')
                  : (isArabic ? 'الحساب / المحفظة' : 'Wallet / Account'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedWalletId,
              items: walletProvider.wallets.map((w) {
                return DropdownMenuItem(
                  value: w.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: w.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(w.iconData, color: w.color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        w.localizedName(isArabic),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedWalletId = val;
                  final newSource = walletProvider.getWalletById(val);
                  final currentDest = walletProvider.getWalletById(
                    _selectedToWalletId,
                  );
                  if (_selectedToWalletId == val ||
                      (newSource != null &&
                          currentDest != null &&
                          newSource.currencyCode != currentDest.currencyCode)) {
                    _selectedToWalletId = null;
                  }
                });
              },
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // في حالة التحويل: اختيار المحفظة المحول إليها
            if (_selectedType == TransactionType.transfer) ...[
              Text(
                isArabic ? 'إلى حساب / محفظة' : 'To Destination Wallet',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final currentSourceWallet = walletProvider.getWalletById(
                    _selectedWalletId,
                  );
                  final matchingWallets = walletProvider.wallets
                      .where(
                        (w) =>
                            w.id != _selectedWalletId &&
                            (currentSourceWallet == null ||
                                w.currencyCode ==
                                    currentSourceWallet.currencyCode),
                      )
                      .toList();

                  if (matchingWallets.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'لا توجد محفظة أخرى بنفس العملة (${currentSourceWallet?.currencyCode ?? ""}) للتحويل إليها.'
                                  : 'No other wallet with currency (${currentSourceWallet?.currencyCode ?? ""}) available for transfer.',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    key: ValueKey(
                      'to_wallet_${_selectedWalletId}_$_selectedToWalletId',
                    ),
                    initialValue:
                        matchingWallets.any((w) => w.id == _selectedToWalletId)
                        ? _selectedToWalletId
                        : null,
                    items: matchingWallets.map((w) {
                      return DropdownMenuItem(
                        value: w.id,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: w.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(w.iconData, color: w.color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              w.localizedName(isArabic),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedToWalletId = val);
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(
                  () => _showAdvancedDetails = !_showAdvancedDetails,
                ),
                icon: Icon(
                  _showAdvancedDetails
                      ? Icons.expand_less_rounded
                      : Icons.tune_rounded,
                  size: 19,
                ),
                label: Text(
                  _showAdvancedDetails
                      ? (isArabic
                            ? 'إخفاء التفاصيل الإضافية'
                            : 'Hide extra details')
                      : (isArabic
                            ? 'إضافة تاريخ أو ملاحظة أو إيصال'
                            : 'Add date, note or receipt'),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_showAdvancedDetails) ...[
              // 5. التاريخ والوقت
              Text(
                isArabic ? 'تاريخ ووقت المعاملة' : 'Date & Time',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate == null) return;
                  if (!context.mounted) return;
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  if (pickedTime != null && mounted) {
                    setState(() {
                      _selectedDate = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormatter.formatDate(
                          _selectedDate,
                          isArabic: isArabic,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormatter.formatTime(
                          _selectedDate,
                          isArabic: isArabic,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 6. قسم إرفاق الفاتورة ومسح الذكاء الاصطناعي
              Text(
                isArabic
                    ? 'صورة الفاتورة أو الإيصال (اختياري)'
                    : 'Receipt / Invoice Photo (Optional)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),

              if (_isScanning) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArabic
                            ? 'جاري مسح الفاتورة واستخراج البيانات الذكية...'
                            : 'Scanning receipt & extracting data...',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_receiptImagePath != null) ...[
                Stack(
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptViewerDialog(
                              imagePath: _receiptImagePath!,
                              title: _titleController.text.trim().isNotEmpty
                                  ? _titleController.text.trim()
                                  : (isArabic
                                        ? 'صورة الإيصال'
                                        : 'Receipt Image'),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          image: DecorationImage(
                            image: FileImage(File(_receiptImagePath!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: isArabic ? null : 8,
                      left: isArabic ? 8 : null,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 18,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            final removedPath = _receiptImagePath;
                            setState(() => _receiptImagePath = null);
                            if (removedPath != null &&
                                _pendingReceiptPaths.remove(removedPath)) {
                              unawaited(
                                ReceiptScannerService.deleteManagedReceipt(
                                  removedPath,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : const Color(0xFFF5F8F7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Smart AI Scan Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isArabic
                                ? 'مسح الفاتورة واستخراج البيانات الذكي (AI)'
                                : 'Smart AI Receipt Scan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReceiptScannerScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isArabic ? 'تصوير فوري' : 'Snap & Auto-fill',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _scanAndAutoFill(ImageSource.camera);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.photo_library_rounded,
                                size: 18,
                              ),
                              label: Text(
                                isArabic ? 'من الاستوديو' : 'From Gallery',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                _scanAndAutoFill(ImageSource.gallery);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 7. العنوان والملاحظات
              Text(
                isArabic
                    ? 'العنوان والملاحظات (اختياري)'
                    : 'Title & Notes (Optional)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'عنوان المعاملة (مثل: مقاضي سوبرماركت)'
                      : 'Transaction title...',
                  prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: isArabic
                      ? 'ملاحظات إضافية...'
                      : 'Additional notes...',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                ),
              ),
              if (_selectedType == TransactionType.expense &&
                  widget.transaction == null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : const Color(0xFFF5F8F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _saveAsRoutine
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                    ),
                  ),
                  child: SwitchListTile(
                    value: _saveAsRoutine,
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _saveAsRoutine = val),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      isArabic
                          ? 'حفظ أيضاً للتسجيل السريع'
                          : 'Save as Routine Expense',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    subtitle: Text(
                      isArabic
                          ? 'لتتمكن من تسجيله مستقبلاً بنقرة واحدة من الرئيسية'
                          : 'To log it in 1 tap from Dashboard in the future',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: _selectedType == TransactionType.expense
                  ? AppColors.expenseGradient
                  : _selectedType == TransactionType.income
                  ? AppColors.emeraldGradient
                  : AppColors.walletGradient1,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [],
            ),
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _saveTransaction();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.transaction != null
                          ? (isArabic ? 'حفظ التعديلات' : 'Save Changes')
                          : (isArabic ? 'حفظ المعاملة' : 'Save Transaction'),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTab({
    required TransactionType type,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = type;
            final catProvider = context.read<CategoryProvider>();
            if (type == TransactionType.expense &&
                catProvider.expenseCategories.isNotEmpty) {
              _selectedCategoryId = catProvider.expenseCategories.first.id;
            } else if (type == TransactionType.income &&
                catProvider.incomeCategories.isNotEmpty) {
              _selectedCategoryId = catProvider.incomeCategories.first.id;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'يرجى إدخال مبلغ صحيح' : 'Please enter a valid amount',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يرجى إدخال مبلغ أكبر من الصفر'
                : 'Amount must be greater than 0',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'يرجى اختيار المحفظة' : 'Please select a wallet',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final walletProvider = context.read<WalletProvider>();

    if (_selectedType == TransactionType.transfer) {
      if (_selectedToWalletId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'يرجى اختيار المحفظة المحول إليها'
                  : 'Please select destination wallet',
            ),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
      final sourceW = walletProvider.getWalletById(_selectedWalletId);
      final destW = walletProvider.getWalletById(_selectedToWalletId);
      if (sourceW != null &&
          destW != null &&
          sourceW.currencyCode != destW.currencyCode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'لا يمكن التحويل المباشر بين عملتين مختلفتين (${sourceW.currencyCode} و ${destW.currencyCode}).'
                  : 'Cannot transfer directly between different currencies (${sourceW.currencyCode} and ${destW.currencyCode}).',
            ),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
    }

    final categoryId = _selectedType == TransactionType.transfer
        ? 'cat_transfer'
        : (_selectedCategoryId ?? 'cat_other_exp');
    final txProvider = context.read<TransactionProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final routineProvider = context.read<RoutineProvider>();
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final note = _noteController.text.trim();
      final existing = widget.transaction;

      if (existing != null) {
        final updated = TransactionModel(
          id: existing.id,
          amount: amount,
          type: _selectedType,
          categoryId: categoryId,
          walletId: _selectedWalletId!,
          toWalletId: _selectedType == TransactionType.transfer
              ? _selectedToWalletId
              : null,
          dateTime: _selectedDate,
          title: title.isEmpty ? null : title,
          note: note.isEmpty ? null : note,
          receiptImagePath: _receiptImagePath,
          currencyCode: existing.currencyCode,
          isRecurring: existing.isRecurring,
          tag: existing.tag,
        );
        await txProvider.updateTransaction(
          updated,
          oldTx: existing,
          walletProvider: walletProvider,
        );
        if (existing.receiptImagePath != null &&
            existing.receiptImagePath != _receiptImagePath) {
          await ReceiptScannerService.deleteManagedReceipt(
            existing.receiptImagePath,
          );
        }
      } else {
        await txProvider.addTransaction(
          transactionId: _newTransactionId,
          saveAsRoutine:
              _saveAsRoutine && _selectedType == TransactionType.expense,
          amount: amount,
          type: _selectedType,
          categoryId: categoryId,
          walletId: _selectedWalletId!,
          toWalletId: _selectedType == TransactionType.transfer
              ? _selectedToWalletId
              : null,
          dateTime: _selectedDate,
          title: title.isEmpty ? null : title,
          note: note.isEmpty ? null : note,
          receiptImagePath: _receiptImagePath,
          currencyCode: walletProvider
              .getById(_selectedWalletId!)!
              .currencyCode,
          walletProvider: walletProvider,
        );

        await routineProvider.loadRoutines();
      }

      if (_receiptImagePath != null) {
        _pendingReceiptPaths.remove(_receiptImagePath);
      }

      await budgetProvider.checkAndNotify(
        txProvider.transactions,
        isArabic: isArabic,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing != null
                  ? (isArabic ? 'تم تحديث المعاملة' : 'Transaction updated')
                  : (isArabic ? 'تم حفظ المعاملة' : 'Transaction saved'),
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تعذر حفظ المعاملة. حاول مجددًا.'
                  : 'Could not save the transaction. Try again.',
            ),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }
}
