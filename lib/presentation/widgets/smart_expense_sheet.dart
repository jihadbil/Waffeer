import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/parsed_ai_expense.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../screens/transactions/add_edit_transaction_screen.dart';

/// نافذة الإدخال الذكي باللغة الطبيعية ورسائل البنوك (SMS)
class SmartExpenseSheet extends StatefulWidget {
  const SmartExpenseSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmartExpenseSheet(),
    );
  }

  @override
  State<SmartExpenseSheet> createState() => _SmartExpenseSheetState();
}

class _SmartExpenseSheetState extends State<SmartExpenseSheet> {
  final TextEditingController _textController = TextEditingController();
  ParsedAiExpense? _parsedResult;
  bool _isSaving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyzeInput() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    final ai = context.read<AiProvider>();
    final result = await ai.parseExpenseText(input: text, context: context);

    if (!mounted) return;
    setState(() {
      _parsedResult = result;
    });
  }

  Future<void> _saveDirectly(ParsedAiExpense result) async {
    if (result.amount == null || result.amount! <= 0) return;

    setState(() => _isSaving = true);
    final settings = context.read<SettingsProvider>();
    final catProvider = context.read<CategoryProvider>();
    final walletProvider = context.read<WalletProvider>();
    final txProvider = context.read<TransactionProvider>();
    final isArabic = settings.isArabic;

    // Resolve category
    final categoryId = result.suggestedCategoryId ??
        (catProvider.categories.isNotEmpty ? catProvider.categories.first.id : 'cat_other');

    // Resolve wallet
    final walletId = result.suggestedWalletId ??
        walletProvider.defaultWallet?.id ??
        (walletProvider.wallets.isNotEmpty ? walletProvider.wallets.first.id : 'default');

    try {
      await txProvider.addTransaction(
        amount: result.amount!,
        type: result.isIncome ? TransactionType.income : TransactionType.expense,
        categoryId: categoryId,
        walletId: walletId,
        dateTime: result.date ?? DateTime.now(),
        title: result.title,
        note: result.note ?? (isArabic ? 'تمت الإضافة عبر التسجيل الذكي 🪄' : 'Added via Smart AI Logger'),
        currencyCode: settings.currencyCode,
        walletProvider: walletProvider,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                isArabic
                    ? 'تم تسجيل "${result.title}" بمبلغ ${result.amount} بنجاح ✨'
                    : 'Recorded "${result.title}" for ${result.amount} successfully ✨',
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'حدث خطأ أثناء الحفظ.' : 'Error saving transaction.'),
          ),
        );
      }
    }
  }

  void _openInAddEditScreen(ParsedAiExpense result) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(
          initialAmount: result.amount,
          initialTitle: result.title,
          initialCategoryId: result.suggestedCategoryId,
          initialDate: result.date,
          initialType: result.isIncome ? TransactionType.income : TransactionType.expense,
          initialNote: result.note ?? (context.read<SettingsProvider>().isArabic ? 'تسجيل ذكي ✨' : 'Smart Logger'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ai = context.watch<AiProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: bottomInset > 0 ? bottomInset + 16 : 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'التسجيل الذكي الفوري' : 'Smart AI Expense Logger',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Text(
                        isArabic
                            ? 'اكتب جملة عادية أو الصق رسالة سحب بنكية (SMS)'
                            : 'Type naturally or paste bank SMS notifications',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text Field
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: isArabic
                          ? 'مثال: صرفت 85 ريال عشاء في ماك من بطاقة الراجحي\nأو الصق رسالة البنك النصية هنا...'
                          : 'e.g. Spent \$45 on dinner with credit card or paste SMS...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              setState(() {
                                _textController.text = data.text!;
                              });
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          label: Text(isArabic ? 'لصق' : 'Paste'),
                        ),
                        if (_textController.text.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _textController.clear();
                                _parsedResult = null;
                              });
                            },
                            child: Text(
                              isArabic ? 'مسح' : 'Clear',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick Samples Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSampleChip('قهوة بـ 18 ريال دانكن', isArabic),
                  _buildSampleChip('بنزين 95 ريال كاش', isArabic),
                  _buildSampleChip('سوبرماركت 210 ريال بنده', isArabic),
                  _buildSampleChip('راتب 12000 ريال الراجحي', isArabic),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Analyze Button
            FilledButton.icon(
              onPressed: ai.isParsingExpense ? null : _analyzeInput,
              icon: ai.isParsingExpense
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                ai.isParsingExpense
                    ? (isArabic ? 'جاري التحليل بالذكاء الاصطناعي...' : 'Analyzing with AI...')
                    : (isArabic ? 'تحليل واستخراج البيانات ✨' : 'Analyze & Extract Data ✨'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            // Extracted Result Card
            if (_parsedResult != null) ...[
              const SizedBox(height: 18),
              _buildExtractedCard(_parsedResult!, settings, isArabic, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSampleChip(String text, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11)),
        onPressed: () {
          setState(() {
            _textController.text = text;
          });
        },
      ),
    );
  }

  Widget _buildExtractedCard(
    ParsedAiExpense result,
    SettingsProvider settings,
    bool isArabic,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : Colors.green.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: result.isIncome
                      ? AppColors.income.withValues(alpha: 0.15)
                      : AppColors.expense.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  result.isIncome
                      ? (isArabic ? 'دخل' : 'Income')
                      : (isArabic ? 'مصروف' : 'Expense'),
                  style: TextStyle(
                    color: result.isIncome ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (result.amount != null)
                Text(
                  CurrencyFormatter.format(
                    result.amount!,
                    currencyCode: settings.currencyCode,
                    isArabic: isArabic,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            result.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          // Metadata row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (result.categoryName != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(result.categoryName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              if (result.walletName != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(result.walletName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              if (result.date != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(DateFormatter.formatShort(result.date!), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : () => _saveDirectly(result),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(isArabic ? 'حفظ فوري' : 'Save Now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInAddEditScreen(result),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(isArabic ? 'تعديل قبل الحفظ' : 'Edit First'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
