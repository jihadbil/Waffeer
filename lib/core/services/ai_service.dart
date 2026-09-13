import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../data/models/ai_action.dart';
import '../../data/models/ai_chat_message.dart';
import '../../data/models/category_model.dart';
import '../../data/models/parsed_ai_expense.dart';
import '../../data/models/receipt_model.dart';
import '../../data/models/wallet_model.dart';

/// نتيجة رد المستشار الذكي شاملة النص وأي إجراءات تنفيذية مطلوبة
class AdvisorResult {
  final String message;
  final List<AiAction> actions;

  /// خاصية توافقية للإجراء الأول في حال وجوده
  AiAction? get action => actions.isNotEmpty ? actions.first : null;

  AdvisorResult({
    required this.message,
    List<AiAction>? actions,
    AiAction? action,
  }) : actions = actions ?? (action != null ? [action] : const []);
}

/// خدمة الذكاء الاصطناعي المركزية لتطبيق "وفير"
///
/// تدير التواصل مع نماذج Google Gemini (Gemini 1.5 Flash):
/// 1. فحص الاتصال ومفتاح API.
/// 2. المستشار المالي الذكي (AI Financial Advisor Chat).
/// 3. استخراج المعاملات من النصوص والرسائل البنكية (Natural Language & SMS Logger).
/// 4. المسح الذكي للفواتير متعدد الوسائط (Multimodal Vision OCR).
/// 5. التوقعات والتحليلات الذكية للوحة التحكم.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const String modelName = 'gemini-2.5-flash';
  static const List<String> candidateModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  /// إرسال طلب توليد محتوى مع تجربة تلقائية للنماذج البديلة في حال كان النموذج غير متاح
  Future<GenerateContentResponse> _generateContentWithFallback({
    required String apiKey,
    required List<Content> contents,
    double temperature = 0.3,
    Content? systemInstruction,
  }) async {
    Object? lastError;
    for (final model in candidateModels) {
      try {
        final generativeModel = GenerativeModel(
          model: model,
          apiKey: apiKey.trim(),
          generationConfig: GenerationConfig(temperature: temperature),
          systemInstruction: systemInstruction,
        );
        return await generativeModel.generateContent(contents);
      } catch (e) {
        lastError = e;
        final errStr = e.toString().toLowerCase();
        // أخطاء المفتاح أو الحصص لا تتغير بتغيير النموذج
        if (errStr.contains('api_key') ||
            errStr.contains('api key not valid') ||
            errStr.contains('unauthorized') ||
            errStr.contains('quota') ||
            errStr.contains('429')) {
          rethrow;
        }
        // في حال كان النموذج محذوفاً أو غير مدعوم للإصدار، جرب النموذج التالي في القائمة
        if (errStr.contains('not found') ||
            errStr.contains('no longer available') ||
            errStr.contains('not supported')) {
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? Exception('All candidate Gemini models failed');
  }

  /// اختبار صلاحية مفتاح الـ API والاتصال بخوادم Google Gemini
  Future<bool> testConnection(String apiKey) async {
    if (apiKey.trim().isEmpty) return false;
    try {
      final response = await _generateContentWithFallback(
        apiKey: apiKey.trim(),
        contents: [Content.text('مرحبا! رد بكلمة "OK" فقط للتحقق من الاتصال.')],
        temperature: 0.1,
      );
      return response.text != null && response.text!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// تحليل النصوص الحرة أو رسائل السحب البنكية (SMS) واستخراج تفاصيل المعاملة
  Future<ParsedAiExpense> parseExpensePrompt({
    required String apiKey,
    required String input,
    required List<CategoryModel> categories,
    required List<WalletModel> wallets,
    required String defaultCurrency,
    required bool isArabic,
  }) async {
    if (apiKey.trim().isEmpty || input.trim().isEmpty) {
      return ParsedAiExpense(
        title: input,
        rawInput: input,
        confidence: 0.0,
      );
    }

    final categoriesListStr = categories
        .map((c) => '{"id": "${c.id}", "name": "${isArabic ? c.nameAr : c.nameEn}", "type": "${c.type.name}"}')
        .join(',\n');

    final walletsListStr = wallets
        .map((w) => '{"id": "${w.id}", "name": "${isArabic ? w.nameAr : w.nameEn}"}')
        .join(',\n');

    final prompt = '''
أنت مساعد مالي ذكي متخصص في تطبيق "وفير".
المهمة: قم بتحليل النص التالي المستخرج من مستخدم أو من رسالة بنكية (SMS) واستخرج بيانات المعاملة المالية بصيغة JSON حصراً.

النص المدخل:
"""
$input
"""

قائمة التصنيفات المتاحة في التطبيق:
[
$categoriesListStr
]

قائمة المحافظ المتاحة في التطبيق:
[
$walletsListStr
]

العملة الافتراضية: $defaultCurrency.
تاريخ اليوم: ${DateTime.now().toIso8601String().substring(0, 10)}.

القواعد:
1. استخرج المبلغ كرقم (double). إذا لم تجد مبلغا حدده كـ null.
2. استخرج اسم المتجر أو عنوان المصروف للعنوان (title). إذا كانت رسالة بنكية مثل "شراء لدى كارفور"، فالعنوان هو "كارفور".
3. طابق التصنيف الأنسب من القائمة المتاحة وأرجع الـ id واسم التصنيف.
4. طابق المحفظة الأنسب من القائمة المتاحة وأرجع الـ id واسم المحفظة (إن ذكر اسم البنك أو البطاقة).
5. حدد نوع المعاملة: هل هي دخل (is_income: true) أم مصروف (is_income: false). الإيداع والرواتب دخل، الشراء والسحب مصروف.
6. التاريخ: بالصيغة YYYY-MM-DD إن وجد، وإلا null.
7. أرجع الإجابة في هيئة JSON فقط بدون أي نص إضافي أو شروحات:
{
  "amount": 0.0,
  "title": "اسم المتجر أو المعاملة",
  "category_id": "معرف التصنيف أو null",
  "category_name": "اسم التصنيف أو null",
  "wallet_id": "معرف المحفظة أو null",
  "wallet_name": "اسم المحفظة أو null",
  "date": "YYYY-MM-DD",
  "is_income": false,
  "note": "ملاحظة إضافية إن وجدت",
  "confidence": 0.95
}
''';

    try {
      final response = await _generateContentWithFallback(
        apiKey: apiKey.trim(),
        contents: [Content.text(prompt)],
        temperature: 0.1,
      );
      final text = response.text?.trim() ?? '';

      final jsonStr = _extractJsonBlock(text);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final amount = map['amount'] != null ? (map['amount'] as num).toDouble() : null;
      final title = (map['title'] as String?)?.trim() ?? input;
      final categoryId = map['category_id'] as String?;
      final categoryName = map['category_name'] as String?;
      final walletId = map['wallet_id'] as String?;
      final walletName = map['wallet_name'] as String?;
      final isIncome = map['is_income'] == true;
      final note = map['note'] as String?;
      final dateStr = map['date'] as String?;
      DateTime? parsedDate;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedDate = DateTime.tryParse(dateStr);
      }

      return ParsedAiExpense(
        amount: amount,
        title: title.isNotEmpty ? title : (isArabic ? 'معاملة جديدة' : 'New Transaction'),
        suggestedCategoryId: categoryId,
        categoryName: categoryName,
        suggestedWalletId: walletId,
        walletName: walletName,
        date: parsedDate,
        note: note,
        isIncome: isIncome,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.9,
        rawInput: input,
      );
    } catch (e) {
      // Return fallback parsed expense
      return _fallbackRegexParser(input, categories, wallets, isArabic);
    }
  }

  /// مسح صورة الفاتورة أو الإيصال عبر Gemini Vision لاستخراج البيانات بدقة فائقة
  Future<ParsedReceipt?> scanReceiptWithVision({
    required String apiKey,
    required File imageFile,
    required List<CategoryModel> categories,
    required bool isArabic,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    try {
      final bytes = await imageFile.readAsBytes();
      final mimeType = imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final categoriesListStr = categories
          .map((c) => '{"id": "${c.id}", "name": "${isArabic ? c.nameAr : c.nameEn}"}')
          .join(', ');

      final prompt = '''
أنت خبير في قراءة وتحليل الإيصالات والفواتير العربية والإنجليزية لتطبيق "وفير".
حلل هذه الصورة واستخرج بيانات الفاتورة في هيئة JSON فقط بدون أي نص إضافي:
{
  "merchant_name": "اسم المتجر أو المحل بدقة",
  "total_amount": 0.0,
  "tax_amount": 0.0,
  "date": "YYYY-MM-DD HH:mm",
  "suggested_category_id": "معرف التصنيف الأنسب من القائمة المتاحة",
  "suggested_category_name": "اسم التصنيف",
  "line_items": [
    {"name": "اسم البند", "price": 0.0, "qty": 1.0}
  ],
  "confidence": 0.95
}

قائمة التصنيفات المتاحة:
[$categoriesListStr]

إذا لم تجد حقلاً معيناً، اجعل قيمته null أو 0.0. تأكد من أن المبلغ الإجمالي النهائي (total_amount) صحيح ودقيق.
''';

      final content = Content.multi([
        TextPart(prompt),
        DataPart(mimeType, bytes),
      ]);

      final response = await _generateContentWithFallback(
        apiKey: apiKey.trim(),
        contents: [content],
        temperature: 0.1,
      );
      final text = response.text?.trim() ?? '';
      final jsonStr = _extractJsonBlock(text);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final total = map['total_amount'] != null ? (map['total_amount'] as num).toDouble() : null;
      final tax = map['tax_amount'] != null ? (map['tax_amount'] as num).toDouble() : null;
      final merchant = map['merchant_name'] as String?;
      final dateStr = map['date'] as String?;
      final catId = map['suggested_category_id'] as String?;

      DateTime? parsedDateTime;
      if (dateStr != null && dateStr.isNotEmpty) {
        parsedDateTime = DateTime.tryParse(dateStr);
      }

      final itemsRaw = map['line_items'] as List<dynamic>? ?? [];
      final List<ReceiptLineItem> items = [];
      for (final item in itemsRaw) {
        if (item is Map<String, dynamic>) {
          items.add(
            ReceiptLineItem(
              name: (item['name'] as String?) ?? '',
              price: (item['price'] as num?)?.toDouble() ?? 0.0,
              quantity: (item['qty'] as num?)?.toDouble() ?? 1.0,
            ),
          );
        }
      }

      return ParsedReceipt(
        imagePath: imageFile.path,
        totalAmount: total,
        taxAmount: tax,
        merchantName: merchant,
        dateTime: parsedDateTime,
        suggestedCategoryId: catId,
        lineItems: items,
        rawText: 'Gemini Vision AI: $text',
        confidenceScore: (map['confidence'] as num?)?.toDouble() ?? 0.95,
      );
    } catch (e) {
      return null;
    }
  }

  /// المستشار المالي الذكي: محادثة تفاعلية تجيب على استفسارات المستخدم وتنفذ الأوامر المالية
  Future<AdvisorResult> askFinancialAdvisor({
    required String apiKey,
    required String userMessage,
    required String financialContextSummary,
    required List<AiChatMessage> history,
    required bool isArabic,
    List<CategoryModel> categories = const [],
    List<WalletModel> wallets = const [],
  }) async {
    if (apiKey.trim().isEmpty) {
      return AdvisorResult(
        message: isArabic
            ? 'يرجى إدخال وتفعيل مفتاح الذكاء الاصطناعي (API Key) من الإعدادات للبدء.'
            : 'Please enter and enable your AI API Key in Settings to begin.',
      );
    }

    final categoriesListStr = categories
        .map((c) => '  {"id": "${c.id}", "name": "${isArabic ? c.nameAr : c.nameEn}", "type": "${c.type.name}"}')
        .join(',\n');

    final walletsListStr = wallets
        .map((w) => '  {"id": "${w.id}", "name": "${isArabic ? w.nameAr : w.nameEn}", "balance": ${w.currentBalance}}')
        .join(',\n');

    final systemInstruction = '''
أنت "مستشار وفير الذكي" (Waffeer Financial Advisor)، مساعد مالي شخصي خبير، ودود، ومشجع للمستخدم في تطبيق "وفير".
هدف المستشار:
- مساعدة المستخدم في توفير المال، ضبط النفقات، تحقيق أهدافه المالية وسداد ديونه.
- الإجابة بدقة، إيجاز، واحترافية بناءً على الأرقام الحقيقية الموضحة في السياق المالي للمستخدم.
- استخدام التنسيق الجميل (نقاط، أرقام بارزة، تنبيهات مشجعة، وإيموجي ذكي).
- الرد بلغة ${isArabic ? 'عربية سليمة وسلسة' : 'English'} وبأسلوب محفز وتطبيقي.

السياق المالي للمستخدم (ملخص رقمي مشفر مجهول المصدر):
"""
$financialContextSummary
"""

قائمة التصنيفات المتاحة في التطبيق (يجب اختيار الأنسب منها واستخدام معرفها واسمها):
[
$categoriesListStr
]

قائمة المحافظ المتاحة في التطبيق:
[
$walletsListStr
]

صلاحياتك التنفيذية (Agent Tool Execution):
أنت تملك القدرة على تنفيذ الأوامر داخل التطبيق بالنيابة عن المستخدم عند طلبه ذلك (مثل: تسجيل مصروف، تسجيل دخل، إضافة تصنيف، تغيير المظهر، تغيير العملة، أو إنشاء ميزانية).
يمكنك تنفيذ أمر واحد أو عدة أوامر معاً في نفس الرد إذا طلب المستخدم ذلك (مثلاً: إضافة دخل وإضافة مصروف معاً في نفس الوقت).

عندما يطلب المستخدم تنفيذ إجراء أو أكثر:
1. أجب في السطر الأول بعبارة تأكيدية ودية وموجزة ومحفزة توضح ما تم تنفيذه.
2. أضف في نهاية رسالتك كتلة JSON محاطة بـ ```action و ``` تحتوي على مصفوفة JSON تضم الأوامر المطلوبة بدقة كالتالي:

أمثلة لكتل الأوامر:
- لتسجيل دخل (مع ربطه بالتصنيف والمحفظة المناسبين من القوائم أعلاه):
```action
[
  {"action": "add_income", "amount": 400.0, "title": "هدية", "category_id": "cat_gift", "category_name": "هدايا ومكافآت", "wallet_id": "معرف المحفظة أو null", "wallet_name": "اسم المحفظة"}
]
```

- لتسجيل مصروف (مع ربطه بالتصنيف والمحفظة المناسبين من القوائم أعلاه):
```action
[
  {"action": "add_expense", "amount": 50.0, "title": "قهوة", "category_id": "cat_food", "category_name": "طعام ومطاعم", "wallet_id": "معرف المحفظة أو null", "wallet_name": "كاش"}
]
```

- لتنفيذ أكثر من معاملة معاً (مثل: تسجيل دخل وتسجيل مصروف في نفس الوقت):
```action
[
  {"action": "add_income", "amount": 500.0, "title": "راتب", "category_id": "cat_salary", "category_name": "راتب شهري", "wallet_name": "البنك"},
  {"action": "add_expense", "amount": 50.0, "title": "ترفيه", "category_id": "cat_entertainment", "category_name": "ترفيه وأنشطة", "wallet_name": "كاش"}
]
```

- لإضافة تصنيف جديد تماماً (فقط وحصراً إذا طلب المستخدم صراحة إنشاء تصنيف جديد):
```action
[
  {"action": "add_category", "name": "اشتراكات", "type": "expense"}
]
```

- لتغيير مظهر التطبيق (فاتح/داكن):
```action
[
  {"action": "change_theme", "mode": "dark"}
]
```

- لتغيير العملة:
```action
[
  {"action": "change_currency", "currency_code": "SAR"}
]
```

- لإنشاء ميزانية جديدة:
```action
[
  {"action": "add_budget", "amount": 1000.0, "category_name": "طعام ومطاعم", "period": "monthly"}
]
```

قواعد صارمة جداً لتنفيذ الأوامر (Strict Execution Rules):
1. مطابقة التصنيفات: اختر دوماً "category_id" و "category_name" المناسبين من قائمة التصنيفات المتاحة أعلاه بحسب نوع المعاملة (income للدخل، expense للمصروف):
   - افهم المعنى اللغوي والمفرد والجمع: (هدية، عيدية، مكافأة) -> تتبع تصنيف "هدايا ومكافآت" (cat_gift).
   - (قهوة، غداء، عشاء، مطعم، تموينات، اكل) -> تتبع تصنيف "طعام ومطاعم" (cat_food).
   - (بنزين، اوبر، كريم، تاكسي، مواصلات) -> تتبع تصنيف "مواصلات وبنزين" (cat_transport).
   - (راتب، معاش، مرتب، أجر) -> تتبع تصنيف "راتب شهري" (cat_salary).
2. عدم توليد تصنيفات وهمية: لا تقم أبداً بإنشاء أمر "add_category" إلا إذا طلب المستخدم حرفياً وصراحة إنشاء تصنيف جديد (مثل: "أنشئ تصنيف جديد" أو "أضف تصنيف كذا"). في كل معاملات الصرف والدخل العادية، طابق مع التصنيفات الحالية الموجودة أعلاه.
3. منع التكرار: إذا طلب المستخدم عملية واحدة فقط (مثل: "أضف دخل 400 دينار هدية")، ضع عنصراً واحداً فقط في مصفوفة action. لا تكرر نفس المعاملة مرتين أبداً في المصفوفة إلا إذا طلب المستخدم صراحة تسجيل عدة معاملات مختلفة أو مكررة.
4. المحفظة: إذا لم يذكر المستخدم اسم المحفظة في طلبه، اختر المحفظة الأولى في القائمة أو اتركها null ليتم الإيداع/الخصم من المحفظة الافتراضية.
5. إذا لم يكن هناك طلب تنفيذ صريح (مثلاً: مجرد استفسار أو نصيحة مالية)، أجب بشكل طبيعي بدون أي كتلة action.
''';

    try {
      final List<Content> contents = [];

      // تنقية السجل واستبعاد الرسائل الفارغة وتجنب تكرار رسالة المستخدم الحالية
      final cleanHistory = history.where((msg) {
        if (msg.isError || msg.content.trim().isEmpty) return false;
        return true;
      }).toList();

      // إذا كانت آخر رسالة مسجلة هي نفس رسالة المستخدم، نحذفها من السجل التاريخي لأننا سنضيفها كطلب حالي في النهاية
      if (cleanHistory.isNotEmpty &&
          cleanHistory.last.isUser &&
          cleanHistory.last.content.trim() == userMessage.trim()) {
        cleanHistory.removeLast();
      }

      final recentHistory = cleanHistory.length > 6
          ? cleanHistory.sublist(cleanHistory.length - 6)
          : cleanHistory;

      for (final msg in recentHistory) {
        if (msg.isUser) {
          contents.add(Content.text(msg.content));
        } else if (msg.content.isNotEmpty) {
          contents.add(Content.model([TextPart(msg.content)]));
        }
      }

      contents.add(Content.text(userMessage));

      final response = await _generateContentWithFallback(
        apiKey: apiKey.trim(),
        contents: contents,
        temperature: 0.3,
        systemInstruction: Content.system(systemInstruction),
      );
      final text = response.text?.trim() ?? (isArabic ? 'عذراً، لم أستطع توليد إجابة.' : 'Sorry, could not generate a response.');

      return extractActionFromResponse(text, isArabic);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('api_key') ||
          errStr.contains('api key not valid') ||
          errStr.contains('unauthorized') ||
          errStr.contains('403') ||
          errStr.contains('401')) {
        return AdvisorResult(
          message: isArabic
              ? '⚠️ يبدو أن هناك مشكلة في مفتاح الـ API. يرجى التأكد من صلاحية المفتاح في إعدادات الذكاء الاصطناعي.'
              : '⚠️ There seems to be an issue with your API Key. Please verify it in AI Settings.',
        );
      }
      if (errStr.contains('quota') || errStr.contains('429') || errStr.contains('resource_exhausted')) {
        return AdvisorResult(
          message: isArabic
              ? '⚠️ تم تجاوز حد الطلبات المتاح لمفتاح API حالياً (Quota/Rate Limit). يرجى الانتظار دقيقة والمحاولة مجدداً.'
              : '⚠️ Request quota exceeded. Please wait a moment and try again.',
        );
      }
      if (errStr.contains('socketexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('network') ||
          errStr.contains('connection refused') ||
          errStr.contains('timed out')) {
        return AdvisorResult(
          message: isArabic
              ? '📶 تعذر الاتصال بخوادم الذكاء الاصطناعي. يرجى التحقق من اتصال هاتفك بالإنترنت والمحاولة مجدداً.'
              : '📶 Could not reach AI servers. Please check your internet connection and try again.',
        );
      }
      return AdvisorResult(
        message: isArabic
            ? 'تعذر الاتصال بالمستشار الذكي حالياً: ${e.toString().split('\n').first}'
            : 'Could not connect to AI advisor: ${e.toString().split('\n').first}',
      );
    }
  }

  /// استخراج كتل الأوامر التنفيذية Action Blocks من رد المستشار وتحويلها لكائنات AiAction مع منع التكرار
  static AdvisorResult extractActionFromResponse(String rawText, bool isArabic) {
    if (!rawText.contains('```action') && !rawText.contains('```json')) {
      return AdvisorResult(message: rawText, actions: const []);
    }

    try {
      final List<AiAction> rawActions = [];
      String cleanMessage = rawText;

      final regExp = RegExp(r'```(?:action|json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
      final matches = regExp.allMatches(rawText).toList();

      for (final match in matches) {
        final blockContent = match.group(1)?.trim() ?? '';
        if (blockContent.isEmpty) continue;

        try {
          final decoded = jsonDecode(blockContent);
          bool isActionBlock = false;

          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic> && item.containsKey('action')) {
                final act = _parseSingleActionMap(item, isArabic);
                if (act != null) {
                  rawActions.add(act);
                  isActionBlock = true;
                }
              }
            }
          } else if (decoded is Map<String, dynamic>) {
            if (decoded.containsKey('action')) {
              final act = _parseSingleActionMap(decoded, isArabic);
              if (act != null) {
                rawActions.add(act);
                isActionBlock = true;
              }
            }
          }

          if (isActionBlock) {
            cleanMessage = cleanMessage.replaceFirst(match.group(0)!, '').trim();
          }
        } catch (_) {
          // ليس JSON صالحاً، نتجاهل الخطأ ونستمر
        }
      }

      // إزالة الإجراءات المتطابقة المكررة في نفس الرد (Action Deduplication)
      final List<AiAction> deduplicatedActions = [];
      for (final act in rawActions) {
        final isDuplicate = deduplicatedActions.any((existing) {
          if (existing.type != act.type) return false;
          final sameAmt = (existing.data['amount'] as num?) == (act.data['amount'] as num?);
          final sameTitle = (existing.data['title'] as String?)?.trim() == (act.data['title'] as String?)?.trim();
          final sameCat = (existing.data['category_id'] == act.data['category_id']) ||
              (existing.data['category_name'] == act.data['category_name']);
          return sameAmt && sameTitle && sameCat;
        });

        if (!isDuplicate) {
          deduplicatedActions.add(act);
        }
      }

      return AdvisorResult(
        message: cleanMessage.isNotEmpty ? cleanMessage : rawText,
        actions: deduplicatedActions,
      );
    } catch (_) {
      return AdvisorResult(message: rawText, actions: const []);
    }
  }

  /// تحويل كائن JSON لمعاملة أو أمر منفرد إلى كائن AiAction
  static AiAction? _parseSingleActionMap(Map<String, dynamic> map, bool isArabic) {
    final actionTypeStr = map['action'] as String?;
    switch (actionTypeStr) {
      case 'add_expense':
        final amt = (map['amount'] as num?)?.toDouble() ?? 0.0;
        final title = (map['title'] as String?)?.trim() ?? (isArabic ? 'مصروف' : 'Expense');
        return AiAction(
          type: AiActionType.addExpense,
          title: isArabic ? 'تسجيل مصروف: $title' : 'Record Expense: $title',
          details: '$amt ${map['category_name'] ?? ''} ${map['wallet_name'] ?? ''}'.trim(),
          data: map,
        );

      case 'add_income':
        final amt = (map['amount'] as num?)?.toDouble() ?? 0.0;
        final title = (map['title'] as String?)?.trim() ?? (isArabic ? 'دخل' : 'Income');
        return AiAction(
          type: AiActionType.addIncome,
          title: isArabic ? 'تسجيل دخل: $title' : 'Record Income: $title',
          details: '$amt ${map['category_name'] ?? ''} ${map['wallet_name'] ?? ''}'.trim(),
          data: map,
        );

      case 'add_category':
        final name = (map['name'] as String?)?.trim() ?? '';
        final isIncome = map['type'] == 'income';
        return AiAction(
          type: AiActionType.addCategory,
          title: isArabic ? 'إنشاء تصنيف جديد: $name' : 'New Category: $name',
          details: isIncome
              ? (isArabic ? 'تصنيف دخل' : 'Income Category')
              : (isArabic ? 'تصنيف مصروف' : 'Expense Category'),
          data: map,
        );

      case 'change_theme':
        final mode = (map['mode'] as String?)?.trim().toLowerCase() ?? 'dark';
        final modeLabel = mode == 'dark'
            ? (isArabic ? 'الوضع الداكن 🌙' : 'Dark Mode 🌙')
            : (mode == 'light'
                ? (isArabic ? 'الوضع الفاتح ☀️' : 'Light Mode ☀️')
                : (isArabic ? 'تلقائي ⚙️' : 'System ⚙️'));
        return AiAction(
          type: AiActionType.changeTheme,
          title: isArabic ? 'تغيير مظهر التطبيق' : 'Change App Theme',
          details: modeLabel,
          data: map,
        );

      case 'change_currency':
        final code = (map['currency_code'] as String?)?.trim().toUpperCase() ?? 'USD';
        return AiAction(
          type: AiActionType.changeCurrency,
          title: isArabic ? 'تغيير عملة التطبيق' : 'Change Currency',
          details: code,
          data: map,
        );

      case 'add_budget':
        final amt = (map['amount'] as num?)?.toDouble() ?? 0.0;
        final cat = (map['category_name'] as String?)?.trim() ?? (isArabic ? 'ميزانية شاملة' : 'Overall');
        return AiAction(
          type: AiActionType.addBudget,
          title: isArabic ? 'إنشاء ميزانية: $cat' : 'Create Budget: $cat',
          details: '$amt ${isArabic ? 'شهرياً' : 'Monthly'}',
          data: map,
        );

      default:
        return null;
    }
  }

  /// توليد نصيحة أو تنبيه مالي ذكي وسريع للوحة التحكم الرئيسية
  Future<String?> generateDashboardTip({
    required String apiKey,
    required String financialContextSummary,
    required bool isArabic,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    final prompt = '''
بناءً على هذا الملخص المالي السريع للمستخدم:
"""
$financialContextSummary
"""
اكتب نصيحة أو ملاحظة ذكية وموجزة جداً (جملة أو جملتين فقط بأسلوب FinTech مشوق ومحفز مع إيموجي مناسب) لظهورها في شريط التنبيهات الذكي في واجهة التطبيق.
اللغة: ${isArabic ? 'العربية' : 'الإنجليزية'}.
لا تذكر أي مقدمات، أرجع النصيحة مباشرة فقط.
''';

    try {
      final response = await _generateContentWithFallback(
        apiKey: apiKey.trim(),
        contents: [Content.text(prompt)],
        temperature: 0.6,
      );
      return response.text?.trim();
    } catch (e) {
      return null;
    }
  }

  /// استخراج نص الـ JSON النقي من ردود الذكاء الاصطناعي التي قد تحتوي Markdown
  static String _extractJsonBlock(String text) {
    if (text.contains('```json')) {
      final start = text.indexOf('```json') + 7;
      final end = text.indexOf('```', start);
      if (end != -1) {
        return text.substring(start, end).trim();
      }
    } else if (text.contains('```')) {
      final start = text.indexOf('```') + 3;
      final end = text.indexOf('```', start);
      if (end != -1) {
        return text.substring(start, end).trim();
      }
    }
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return text.substring(firstBrace, lastBrace + 1).trim();
    }
    return text;
  }

  /// محلل احتياطي محلي في حالة عدم توفر اتصال بالإنترنت أو عدم صحة المفتاح
  static ParsedAiExpense _fallbackRegexParser(
    String input,
    List<CategoryModel> categories,
    List<WalletModel> wallets,
    bool isArabic,
  ) {
    // محاولة استخراج رقم المبلغ
    final clean = input.replaceAll('،', '.').replaceAll(',', '');
    final numRegex = RegExp(r'(\d+(?:\.\d{1,2})?)');
    final match = numRegex.firstMatch(clean);
    final amount = match != null ? double.tryParse(match.group(1)!) : null;

    // محاولة مطابقة التصنيف
    CategoryModel? matchedCat;
    for (final cat in categories) {
      if (input.toLowerCase().contains(cat.nameAr.toLowerCase()) ||
          input.toLowerCase().contains(cat.nameEn.toLowerCase())) {
        matchedCat = cat;
        break;
      }
    }

    // محاولة مطابقة المحفظة
    WalletModel? matchedWallet;
    for (final w in wallets) {
      if (input.toLowerCase().contains(w.nameAr.toLowerCase()) ||
          input.toLowerCase().contains(w.nameEn.toLowerCase())) {
        matchedWallet = w;
        break;
      }
    }

    final isIncome = input.contains('إيداع') ||
        input.contains('راتب') ||
        input.contains('تحويل وارد') ||
        input.toLowerCase().contains('salary') ||
        input.toLowerCase().contains('deposit');

    return ParsedAiExpense(
      amount: amount,
      title: input.length > 30 ? input.substring(0, 30) : input,
      suggestedCategoryId: matchedCat?.id,
      categoryName: matchedCat != null ? (isArabic ? matchedCat.nameAr : matchedCat.nameEn) : null,
      suggestedWalletId: matchedWallet?.id,
      walletName: matchedWallet != null ? (isArabic ? matchedWallet.nameAr : matchedWallet.nameEn) : null,
      isIncome: isIncome,
      confidence: amount != null ? 0.6 : 0.2,
      rawInput: input,
    );
  }
}
