/// نموذج يمثل بنداً فردياً من بنود الفاتورة المكتشفة (الصنف، السعر، والكمية)
class ReceiptLineItem {
  /// اسم البند أو الصنف
  final String name;

  /// سعر البند الفردي أو الإجمالي
  final double price;

  /// كمية الصنف (اختياري)
  final double? quantity;

  const ReceiptLineItem({
    required this.name,
    required this.price,
    this.quantity,
  });

  /// تحويل كائن البند إلى خريطة Map لحفظه أو نقله
  Map<String, dynamic> toMap() {
    return {'name': name, 'price': price, 'quantity': quantity};
  }

  /// إنشاء كائن بند الفاتورة من خريطة Map
  factory ReceiptLineItem.fromMap(Map<String, dynamic> map) {
    return ReceiptLineItem(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble(),
    );
  }
}

/// نموذج يمثل الفاتورة الممسوحة ضوئياً بعد معالجتها واستخراج بياناتها بالذكاء الاصطناعي
class ParsedReceipt {
  /// مسار ملف صورة الفاتورة المحفوظة محلياً على الجهاز
  final String imagePath;

  /// اسم المتجر أو المحل المستخرج من ترويسة الفاتورة
  final String? merchantName;

  /// المبلغ الإجمالي النهائي للفاتورة المستخرج بواسطة خوارزميات التعرف
  final double? totalAmount;

  /// مبلغ ضريبة القيمة المضافة (VAT) إن وجد
  final double? taxAmount;

  /// تاريخ ووقت إصدار الفاتورة المستخرج
  final DateTime? dateTime;

  /// معرّف التصنيف المقترح تلقائياً بناءً على تحليل الكلمات المفتاحية
  final String? suggestedCategoryId;

  /// اسم التصنيف المقترح للعرض
  final String? suggestedCategoryName;

  /// قائمة البنود والأصناف الفردية المكتشفة في الفاتورة
  final List<ReceiptLineItem> lineItems;

  /// النص الخام الكامل المستخرج عبر محرك OCR للشفافية وإمكانية النسخ
  final String rawText;

  /// رمز أو اسم العملة المكتشف في الفاتورة (إن وجد)
  final String? currency;

  /// درجة الثقة والدقة في التعرف على بيانات الفاتورة (من 0.0 إلى 1.0)
  final double confidenceScore;

  const ParsedReceipt({
    required this.imagePath,
    this.merchantName,
    this.totalAmount,
    this.taxAmount,
    this.dateTime,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.lineItems = const [],
    this.rawText = '',
    this.currency,
    this.confidenceScore = 0.0,
  });

  /// التحقق مما إذا كان قد تم استخراج المبلغ الإجمالي بنجاح
  bool get hasExtractedAmount => totalAmount != null && totalAmount! > 0;

  /// التحقق مما إذا كان قد تم استخراج اسم المتجر بنجاح
  bool get hasExtractedMerchant =>
      merchantName != null && merchantName!.trim().isNotEmpty;

  /// التحقق مما إذا كان قد تم استخراج تاريخ الفاتورة بنجاح
  bool get hasExtractedDate => dateTime != null;

  /// التحقق مما إذا كان هناك تصنيف مقترح للفاتورة
  bool get hasExtractedCategory =>
      suggestedCategoryId != null && suggestedCategoryId!.isNotEmpty;

  /// إنشاء نسخة جديدة من الكائن مع إمكانية تعديل بعض الحقول
  ParsedReceipt copyWith({
    String? imagePath,
    String? merchantName,
    double? totalAmount,
    double? taxAmount,
    DateTime? dateTime,
    String? suggestedCategoryId,
    String? suggestedCategoryName,
    List<ReceiptLineItem>? lineItems,
    String? rawText,
    String? currency,
    double? confidenceScore,
  }) {
    return ParsedReceipt(
      imagePath: imagePath ?? this.imagePath,
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      dateTime: dateTime ?? this.dateTime,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      suggestedCategoryName:
          suggestedCategoryName ?? this.suggestedCategoryName,
      lineItems: lineItems ?? this.lineItems,
      rawText: rawText ?? this.rawText,
      currency: currency ?? this.currency,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }
}
