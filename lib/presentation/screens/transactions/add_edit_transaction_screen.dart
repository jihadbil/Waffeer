import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../core/services/receipt_scanner_service.dart';
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
    this.initialType = TransactionType.expense,
    this.initialAmount,
    this.initialTitle,
    this.initialCategoryId,
    this.initialDate,
    this.initialReceiptImagePath,
    this.initialNote,
  });

  @override
  State<AddEditTransactionScreen> createState() => _AddEditTransactionScreenState();
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
  final ImagePicker _picker = ImagePicker();

  /// حالة المعالجة عند المسح الذكي للفاتورة من داخل الشاشة
  bool _isScanning = false;

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
    }

    // تعيين المحفظة والتصنيف الافتراضيين بعد اكتمال بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catProvider = context.read<CategoryProvider>();
      final walletProvider = context.read<WalletProvider>();

      if (_selectedCategoryId == null) {
        if (_selectedType == TransactionType.expense && catProvider.expenseCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.expenseCategories.first.id;
        } else if (_selectedType == TransactionType.income && catProvider.incomeCategories.isNotEmpty) {
          _selectedCategoryId = catProvider.incomeCategories.first.id;
        }
      }

      if (_selectedWalletId == null && walletProvider.wallets.isNotEmpty) {
        _selectedWalletId = walletProvider.defaultWallet?.id ?? walletProvider.wallets.first.id;
        if (walletProvider.wallets.length > 1) {
          _selectedToWalletId = walletProvider.wallets[1].id;
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// مسح الفاتورة بالكاميرا أو المعرض واستخراج البيانات وتعبئة حقول الشاشة آلياً
  Future<void> _scanAndAutoFill(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 90);
      if (pickedFile == null) return;

      setState(() {
        _isScanning = true;
      });

      final file = File(pickedFile.path);
      // معالجة الفاتورة واستخراج البيانات
      final parsed = await ReceiptScannerService.instance.scanReceipt(file);

      if (mounted) {
        final catProvider = context.read<CategoryProvider>();
        final isArabic = context.read<SettingsProvider>().isArabic;

        // مطابقة التصنيف المستخرج
        String? newCatId = parsed.suggestedCategoryId;
        if (newCatId != null) {
          final exists = catProvider.expenseCategories.any((c) => c.id == newCatId);
          if (!exists && catProvider.expenseCategories.isNotEmpty) {
            newCatId = catProvider.expenseCategories.first.id;
          }
        }

        // تحديث الحقول في الشاشة بالبيانات المستخرجة
        setState(() {
          _isScanning = false;
          _receiptImagePath = file.path;
          _selectedType = TransactionType.expense;

          if (parsed.totalAmount != null) {
            _amountController.text = parsed.totalAmount! % 1 == 0
                ? parsed.totalAmount!.toInt().toString()
                : parsed.totalAmount!.toStringAsFixed(2);
          }

          if (parsed.merchantName != null && parsed.merchantName!.trim().isNotEmpty) {
            _titleController.text = parsed.merchantName!.trim();
          }

          if (parsed.dateTime != null) {
            _selectedDate = parsed.dateTime!;
          }

          if (newCatId != null) {
            _selectedCategoryId = newCatId;
          }
        });

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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        final isArabic = context.read<SettingsProvider>().isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ أثناء قراءة الفاتورة' : 'Error scanning receipt',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
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
        title: Text(isArabic ? 'إضافة معاملة جديدة' : 'Add Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Type Selector (Expense / Income / Transfer)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
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
            const SizedBox(height: 24),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isArabic ? 'المبلغ' : 'Amount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Categories Section (For Expense & Income)
            if (_selectedType != TransactionType.transfer) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'التصنيف' : 'Category',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${categories.length} ${isArabic ? "تصنيف" : "categories"}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 95,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final cat = categories[idx];
                    final isSelected = cat.id == _selectedCategoryId;

                    return InkWell(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 78,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cat.color.withValues(alpha: isDark ? 0.25 : 0.15)
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? cat.color
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CategoryIconWidget(
                              iconData: cat.iconData,
                              color: cat.color,
                              size: 40,
                              iconSize: 20,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.localizedName(isArabic),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              const SizedBox(height: 20),
            ],

            // Wallet Selection
            Text(
              _selectedType == TransactionType.transfer
                  ? (isArabic ? 'من حساب / محفظة' : 'From Wallet')
                  : (isArabic ? 'الحساب / المحفظة' : 'Wallet / Account'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedWalletId,
              items: walletProvider.wallets.map((w) {
                return DropdownMenuItem(
                  value: w.id,
                  child: Row(
                    children: [
                      Icon(w.iconData, color: w.color, size: 20),
                      const SizedBox(width: 10),
                      Text(w.localizedName(isArabic)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            // To Wallet (Only if Transfer)
            if (_selectedType == TransactionType.transfer) ...[
              const SizedBox(height: 16),
              Text(
                isArabic ? 'إلى حساب / محفظة' : 'To Wallet',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedToWalletId,
                items: walletProvider.wallets
                    .where((w) => w.id != _selectedWalletId)
                    .map((w) {
                  return DropdownMenuItem(
                    value: w.id,
                    child: Row(
                      children: [
                        Icon(w.iconData, color: w.color, size: 20),
                        const SizedBox(width: 10),
                        Text(w.localizedName(isArabic)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedToWalletId = val),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Date & Time Picker
            Text(
              isArabic ? 'التاريخ والوقت' : 'Date & Time',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (pickedDate != null && context.mounted) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  setState(() {
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime?.hour ?? _selectedDate.hour,
                      pickedTime?.minute ?? _selectedDate.minute,
                    );
                  });
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)}  •  ${DateFormatter.formatTime(_selectedDate, isArabic: isArabic)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Receipt Attachment Section
            Text(
              isArabic ? 'صورة الفاتورة أو الإيصال (اختياري)' : 'Receipt / Invoice Photo (Optional)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            if (_isScanning) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArabic
                          ? 'جاري مسح الفاتورة واستخراج البيانات الذكية...'
                          : 'Scanning receipt & extracting data...',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                                : (isArabic ? 'صورة الإيصال' : 'Receipt Image'),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 2),
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
                        icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                        onPressed: () => setState(() => _receiptImagePath = null),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    // Smart AI Scan Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(
                          isArabic ? 'مسح الفاتورة واستخراج البيانات الذكي (AI)' : 'Smart AI Receipt Scan',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
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
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: Text(isArabic ? 'تصوير فوري' : 'Snap & Auto-fill'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _scanAndAutoFill(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: Text(isArabic ? 'من الاستوديو' : 'From Gallery'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _scanAndAutoFill(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Title & Note Input
            Text(
              isArabic ? 'العنوان والملاحظات (اختياري)' : 'Title & Notes (Optional)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: isArabic ? 'عنوان المعاملة (مثل: عشاء في مطعم)' : 'Transaction title...',
                prefixIcon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isArabic ? 'ملاحظات إضافية...' : 'Additional notes...',
                prefixIcon: const Icon(Icons.notes_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isArabic ? 'حفظ المعاملة ✓' : 'Save Transaction ✓',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
          setState(() {
            _selectedType = type;
            final catProvider = context.read<CategoryProvider>();
            if (type == TransactionType.expense && catProvider.expenseCategories.isNotEmpty) {
              _selectedCategoryId = catProvider.expenseCategories.first.id;
            } else if (type == TransactionType.income && catProvider.incomeCategories.isNotEmpty) {
              _selectedCategoryId = catProvider.incomeCategories.first.id;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
          content: Text(isArabic ? 'يرجى إدخال مبلغ صحيح' : 'Please enter a valid amount'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى إدخال مبلغ أكبر من الصفر' : 'Amount must be greater than 0'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى اختيار المحفظة' : 'Please select a wallet'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer && _selectedToWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى اختيار المحفظة المحول إليها' : 'Please select destination wallet'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final categoryId = _selectedType == TransactionType.transfer
        ? 'cat_transfer'
        : (_selectedCategoryId ?? 'cat_other_exp');

    final walletProvider = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();

    await txProvider.addTransaction(
      amount: amount,
      type: _selectedType,
      categoryId: categoryId,
      walletId: _selectedWalletId!,
      toWalletId: _selectedType == TransactionType.transfer ? _selectedToWalletId : null,
      dateTime: _selectedDate,
      title: _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : null,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      receiptImagePath: _receiptImagePath,
      currencyCode: settings.currencyCode,
      walletProvider: walletProvider,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم حفظ المعاملة بنجاح ✓' : 'Transaction saved successfully ✓'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    }
  }
}
