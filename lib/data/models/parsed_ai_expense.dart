/// نموذج نتيجة استخراج المعاملة بالذكاء الاصطناعي من النصوص ورسائل البنوك
class ParsedAiExpense {
  final double? amount;
  final String title;
  final String? suggestedCategoryId;
  final String? categoryName;
  final String? suggestedWalletId;
  final String? walletName;
  final DateTime? date;
  final String? note;
  final bool isIncome;
  final double confidence;
  final String rawInput;

  const ParsedAiExpense({
    this.amount,
    required this.title,
    this.suggestedCategoryId,
    this.categoryName,
    this.suggestedWalletId,
    this.walletName,
    this.date,
    this.note,
    this.isIncome = false,
    this.confidence = 0.85,
    required this.rawInput,
  });

  bool get isValid => amount != null && amount! > 0;
}
