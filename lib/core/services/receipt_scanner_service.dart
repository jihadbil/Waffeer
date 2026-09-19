import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/category_model.dart';
import '../../data/models/receipt_model.dart';
import 'ai_service.dart';

/// خدمة التعرف الضوئي على النصوص (OCR) والتحليل الذكي لبيانات الفواتير والإيصالات
///
/// تستخدم هذه الخدمة نموذج Gemini Vision فائق الذكاء عند توفر المفتاح، مع التراجع التلقائي
/// لمحرك Google ML Kit محلياً على جهاز المستخدم (On-Device) عند انقطاع الاتصال
class ReceiptScannerService {
  // تطبيق نمط Singleton لضمان وجود نسخة واحدة فقط من الخدمة
  ReceiptScannerService._();
  static final ReceiptScannerService instance = ReceiptScannerService._();

  /// نسخ ملف الصورة الملتقطة من المجلد المؤقت إلى مجلد المستندات الدائم للتطبيق
  static Future<String> persistReceiptImage(String tempPath) async {
    try {
      final file = File(tempPath);
      if (!await file.exists()) return tempPath;

      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${appDir.path}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final extension = tempPath.split('.').last;
      final fileName =
          'receipt_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$extension';
      final permanentFile = await file.copy('${receiptsDir.path}/$fileName');
      return permanentFile.path;
    } catch (_) {
      return tempPath;
    }
  }

  /// Deletes only files owned by Waffeer's receipts directory.
  static Future<bool> deleteManagedReceipt(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return false;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsPath = p.normalize(p.absolute(appDir.path, 'receipts'));
      final candidate = p.normalize(p.absolute(filePath));
      if (!p.isWithin(receiptsPath, candidate)) return false;
      final file = File(candidate);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// محرك التعرف الضوئي على النصوص من Google ML Kit
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// إغلاق وتحرير موارد محرك ML Kit عند عدم الحاجة إليه
  void dispose() {
    _textRecognizer.close();
  }

  /// معالجة ملف صورة الفاتورة واستخراج البيانات المهيكلة منها
  ///
  /// تحاول أولاً استخدام Gemini Vision لاستخراج دقيق للبنود والضريبة، ثم تتراجع لـ ML Kit
  Future<ParsedReceipt> scanReceipt(
    File imageFile, {
    String? apiKey,
    List<CategoryModel>? categories,
    bool isArabic = true,
  }) async {
    // 1. محاولة التحليل بالرؤية الحاسوبية Gemini Vision إن توفر المفتاح
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      try {
        final geminiParsed = await AiService.instance.scanReceiptWithVision(
          apiKey: apiKey.trim(),
          imageFile: imageFile,
          categories: categories ?? [],
          isArabic: isArabic,
        );
        if (geminiParsed != null && geminiParsed.totalAmount != null) {
          return geminiParsed;
        }
      } catch (_) {
        // التراجع التلقائي إلى ML Kit المحلي
      }
    }

    // 2. تجهيز الصورة لمحرك ML Kit كبديل محلي
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );

    final rawText = recognizedText.text;
    final blocks = recognizedText.blocks;

    // 2. تجميع كافة الأسطر المستخرجة بالترتيب
    final List<String> allLines = [];
    for (final block in blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          allLines.add(text);
        }
      }
    }

    // 3. تحليل النصوص المستخرجة
    return parseReceiptText(
      rawText: rawText,
      lines: allLines,
      imagePath: imageFile.path,
    );
  }

  /// تحليل الأسطر النصية الخام وتحويلها إلى كائن فاتورة مهيكل [ParsedReceipt]
  ParsedReceipt parseReceiptText({
    required String rawText,
    required List<String> lines,
    required String imagePath,
  }) {
    // 1. توحيد صيغ الأرقام (تحويل الأرقام المشرقية ٠-٩ إلى 0-9 وتوحيد الفواصل)
    final normalizedLines = lines.map(_normalizeNumbers).toList();
    final normalizedRaw = _normalizeNumbers(rawText);

    // 2. استخراج المبلغ الإجمالي النهائي
    final totalAmount = _extractTotalAmount(normalizedLines);

    // 3. استخراج مبلغ الضريبة إن وجد
    final taxAmount = _extractTaxAmount(normalizedLines);

    // 4. استخراج تاريخ ووقت الفاتورة
    final dateTime = _extractDateTime(normalizedLines);

    // 5. استخراج اسم المتجر أو المحل من ترويسة الفاتورة
    final merchantName = _extractMerchantName(lines);

    // 6. اقتراح التصنيف المناسب بناءً على محتوى الفاتورة
    final categoryId = _predictCategory(normalizedRaw);

    // 7. استخراج بنود الفاتورة الفردية وأسعارها
    final lineItems = _extractLineItems(normalizedLines);

    // 8. حساب درجة الثقة التقديرية بناءً على الحقول المكتشفة بنجاح
    double confidence = 0.0;
    if (totalAmount != null && totalAmount > 0) confidence += 0.45;
    if (merchantName != null && merchantName.isNotEmpty) confidence += 0.25;
    if (dateTime != null) confidence += 0.20;
    if (categoryId != null) confidence += 0.10;

    return ParsedReceipt(
      imagePath: imagePath,
      merchantName: merchantName,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      dateTime: dateTime ?? DateTime.now(),
      suggestedCategoryId: categoryId,
      lineItems: lineItems,
      rawText: rawText,
      confidenceScore: confidence,
    );
  }

  /// تحويل الأرقام العربية المشرقية (٠-٩) إلى أرقام غربية (0-9) وتوحيد الفاصلة العشرية
  String _normalizeNumbers(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const westernDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    var res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(arabicDigits[i], westernDigits[i]);
    }
    // توحيد الفاصلة العشرية العربية '٫' لتصبح نقطة '.'
    res = res.replaceAll('٫', '.');
    return res;
  }

  /// استخراج المبلغ الإجمالي النهائي للفاتورة عبر مطابقة الكلمات الدلالية والأرقام
  double? _extractTotalAmount(List<String> lines) {
    // كلمات دلالية ذات أولوية قصوى تشير مباشرة للمبلغ الإجمالي
    final highPriorityKeywords = [
      'grand total',
      'total amount',
      'total due',
      'net total',
      'net amount',
      'amount due',
      'balance due',
      'total paid',
      'total bill',
      'المجموع النهائي',
      'المبلغ المطلوب',
      'المبلغ الإجمالي',
      'المجموع الكلي',
      'صافي القيمة',
      'القيمة الإجمالية',
      'المطلوب دفعه',
      'المستحق',
      'المبلغ الصافي',
    ];

    // كلمات دلالية عامة قد تشير إلى المجموع أو وسيلة الدفع
    final normalKeywords = [
      'total',
      'net',
      'paid',
      'sum',
      'gross',
      'amount',
      'المجموع',
      'الإجمالي',
      'الصافي',
      'المبلغ',
      'المدفوع',
      'نقداً',
      'كاش',
      'شبكة',
      'بطاقة',
      'فيزا',
      'مدى',
      'apple pay',
      'mada',
      'visa',
      'mastercard',
    ];

    // كلمات مستبعدة (مثل المجموع الفرعي، الضريبة، الباقي، أو الخصم لتجنب الخلط مع الإجمالي)
    final taxOrSubtotalKeywords = [
      'taxable',
      'subtotal',
      'sub-total',
      'sub total',
      'غير شامل',
      'قبل الضريبة',
      'بدون ضريبة',
      'vat 15%',
      'vat 5%',
      'ضريبة 15%',
      'ضريبة 5%',
      'قيمة الضريبة',
      'مبلغ الضريبة',
      'change',
      'الباقي',
      'خصم',
      'discount',
    ];

    // المرحلة 1: البحث عن الأسطر التي تحتوي على كلمات ذات أولوية قصوى
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final kw in highPriorityKeywords) {
        if (lower.contains(kw)) {
          final amount = _parseAmountFromLine(line);
          if (amount != null && amount > 0 && amount < 1000000) {
            return amount;
          }
        }
      }
    }

    // المرحلة 2: البحث عن الكلمات الدلالية العادية مع استبعاد سطور الضرائب والمجاميع الفرعية
    final candidates = <double>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      final isNormalKeyword = normalKeywords.any((kw) => lower.contains(kw));
      final isSubtotalOrTax = taxOrSubtotalKeywords.any(
        (kw) => lower.contains(kw),
      );

      if (isNormalKeyword && !isSubtotalOrTax) {
        // محاولة استخراج الرقم من نفس السطر
        var amount = _parseAmountFromLine(line);
        // إذا لم يكن الرقم في نفس السطر، البحث في السطر التالي مباشرة
        if (amount == null && i + 1 < lines.length) {
          amount = _parseAmountFromLine(lines[i + 1]);
        }
        if (amount != null && amount > 0 && amount < 1000000) {
          candidates.add(amount);
        }
      }
    }

    if (candidates.isNotEmpty) {
      // اختيار أعلى قيمة منطقية قريبة من الكلمات الدلالية
      candidates.sort();
      return candidates.last;
    }

    // المرحلة 3 (خطة احتياطية): استخراج جميع الأرقام من النصف السفلي للفاتورة واختيار أعلى قيمة منطقية
    final fallbackCandidates = <double>[];
    final startIndex = (lines.length * 0.3).floor();
    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      final amounts = _findAllAmountsInLine(line);
      for (final amt in amounts) {
        // استبعاد أرقام السنوات (2024, 2025, 2026) وأرقام الهواتف والقيم الشاذة
        if (amt > 0.5 &&
            amt < 50000 &&
            amt != 2024 &&
            amt != 2025 &&
            amt != 2026) {
          fallbackCandidates.add(amt);
        }
      }
    }

    if (fallbackCandidates.isNotEmpty) {
      fallbackCandidates.sort();
      return fallbackCandidates.last;
    }

    return null;
  }

  /// استخراج آخر قيمة رقمية صالحة من سطر نصي معين
  double? _parseAmountFromLine(String line) {
    final amounts = _findAllAmountsInLine(line);
    if (amounts.isNotEmpty) {
      return amounts.last;
    }
    return null;
  }

  /// استخراج جميع الأرقام والأسعار العشرية الموجودة في سطر نصي
  List<double> _findAllAmountsInLine(String line) {
    final List<double> results = [];
    // تعبير نمطي لمطابقة أنماط الأرقام مثل: 125.50, 1,250.00, 1250,50, 45.0, 99
    final regex = RegExp(
      r'(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{1,2})|\d+(?:[\.,]\d{1,2})|\b\d{1,5}\b)',
    );
    final matches = regex.allMatches(line);

    for (final match in matches) {
      var raw = match.group(1);
      if (raw != null) {
        // تنظيف المسافات والفواصل
        raw = raw.replaceAll(' ', '');
        if (raw.contains(',') && raw.contains('.')) {
          raw = raw.replaceAll(',', ''); // مثال: 1,234.56
        } else if (raw.contains(',')) {
          // إذا كانت الفاصلة مفردة وتتبعها خانتان عشريتان تُعامل كفاصلة عشرية
          final parts = raw.split(',');
          if (parts.length == 2 && parts[1].length <= 2) {
            raw = '${parts[0]}.${parts[1]}';
          } else {
            raw = raw.replaceAll(',', '');
          }
        }

        final val = double.tryParse(raw);
        if (val != null) {
          results.add(val);
        }
      }
    }
    return results;
  }

  /// استخراج مبلغ ضريبة القيمة المضافة (VAT) إن وجد
  double? _extractTaxAmount(List<String> lines) {
    final taxKeywords = [
      'vat',
      'tax',
      'tax amount',
      'ضريبة',
      'ضريبة القيمة المضافة',
      'مبلغ الضريبة',
      'قيمة الضريبة',
    ];

    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final kw in taxKeywords) {
        // استبعاد نسب الضريبة المئوية مثل 15% أو 5%
        if (lower.contains(kw) &&
            !lower.contains('15%') &&
            !lower.contains('5%')) {
          final amt = _parseAmountFromLine(line);
          if (amt != null && amt > 0 && amt < 10000) {
            return amt;
          }
        }
      }
    }
    return null;
  }

  /// استخراج التاريخ والوقت من أسطر الفاتورة
  DateTime? _extractDateTime(List<String> lines) {
    // تعابير نمطية لمختلف صيغ التواريخ الشائعة
    final ymdRegex = RegExp(
      r'(\b20\d{2})[-/. ](0?[1-9]|1[0-2])[-/. ](0?[1-9]|[12]\d|3[01])\b',
    );
    final dmyRegex = RegExp(
      r'\b(0?[1-9]|[12]\d|3[01])[-/. ](0?[1-9]|1[0-2])[-/. ](20\d{2})\b',
    );
    final dmyShortRegex = RegExp(
      r'\b(0?[1-9]|[12]\d|3[01])[-/. ](0?[1-9]|1[0-2])[-/. ](\d{2})\b',
    );
    final timeRegex = RegExp(
      r'\b([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?:\s*(AM|PM|am|pm|ص|م))?\b',
    );

    int? year, month, day, hour, minute;

    for (final line in lines) {
      // 1. محاولة مطابقة صيغة: YYYY-MM-DD
      if (year == null) {
        final ymdMatch = ymdRegex.firstMatch(line);
        if (ymdMatch != null) {
          year = int.tryParse(ymdMatch.group(1)!);
          month = int.tryParse(ymdMatch.group(2)!);
          day = int.tryParse(ymdMatch.group(3)!);
        }
      }

      // 2. محاولة مطابقة صيغة: DD-MM-YYYY
      if (year == null) {
        final dmyMatch = dmyRegex.firstMatch(line);
        if (dmyMatch != null) {
          day = int.tryParse(dmyMatch.group(1)!);
          month = int.tryParse(dmyMatch.group(2)!);
          year = int.tryParse(dmyMatch.group(3)!);
        }
      }

      // 3. محاولة مطابقة صيغة: DD-MM-YY
      if (year == null) {
        final dmyShortMatch = dmyShortRegex.firstMatch(line);
        if (dmyShortMatch != null) {
          day = int.tryParse(dmyShortMatch.group(1)!);
          month = int.tryParse(dmyShortMatch.group(2)!);
          final shortYear = int.tryParse(dmyShortMatch.group(3)!);
          if (shortYear != null) {
            year = 2000 + shortYear;
          }
        }
      }

      // استخراج الوقت إن وجد
      if (hour == null) {
        final timeMatch = timeRegex.firstMatch(line);
        if (timeMatch != null) {
          var h = int.tryParse(timeMatch.group(1)!);
          final m = int.tryParse(timeMatch.group(2)!);
          final period = timeMatch.group(4)?.toUpperCase();

          if (h != null && m != null) {
            // معالجة توقيت المساء والصباح (PM / AM / ص / م)
            if ((period == 'PM' || period == 'م') && h < 12) {
              h += 12;
            } else if ((period == 'AM' || period == 'ص') && h == 12) {
              h = 0;
            }
            hour = h;
            minute = m;
          }
        }
      }
    }

    if (year != null && month != null && day != null) {
      try {
        return DateTime(year, month, day, hour ?? 12, minute ?? 0);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// استخراج اسم المتجر أو المحل التجاري من الأسطر الأولى في ترويسة الفاتورة
  String? _extractMerchantName(List<String> originalLines) {
    // كلمات عامة مستبعدة تظهر في رأس الفاتورة ولكنها ليست اسماً للمتجر
    final noiseKeywords = [
      'فاتورة',
      'فاتوره',
      'ضريبية',
      'مبسطة',
      'إشعار',
      'سند',
      'قبض',
      'ايصال',
      'إيصال',
      'مرحبا',
      'شكرا',
      'أهلا',
      'tax invoice',
      'simplified tax invoice',
      'invoice',
      'receipt',
      'welcome',
      'thank you',
      'official receipt',
      'pos',
      'cashier',
      'cr:',
      'c.r',
      'c.r.',
      'vat:',
      'trn:',
      'tel:',
      'phone',
      'mobile',
      'fax',
      'www.',
      'http',
      '.com',
      '.sa',
      '.net',
      'branch',
      'فرع',
      'المملكة العربية السعودية',
      'kingdom of saudi arabia',
    ];

    // فحص الأسطر الخمسة الأولى فقط
    final checkLimit = originalLines.length > 5 ? 5 : originalLines.length;
    for (int i = 0; i < checkLimit; i++) {
      final line = originalLines[i].trim();
      final lower = line.toLowerCase();

      // تجاهل الأسطر القصيرة جداً أو الطويلة جداً
      if (line.length < 3 || line.length > 50) continue;

      // تجاهل الأسطر التي تتكون من أرقام أو رموز فقط
      if (RegExp(r'^[\d\s\-\.\/:\+,=]+$').hasMatch(line)) continue;

      // التحقق من خلو السطر من الكلمات العامة المستبعدة
      final isNoise = noiseKeywords.any((kw) => lower.contains(kw));
      if (!isNoise) {
        return line;
      }
    }

    // خطة احتياطية: إرجاع السطر الأول إن لم يكن رقماً خالصاً
    if (originalLines.isNotEmpty &&
        !RegExp(r'^[\d\s\-\.\/:\+,=]+$').hasMatch(originalLines.first)) {
      return originalLines.first.trim();
    }

    return null;
  }

  /// التنبؤ واقتراح تصنيف المصروف المناسب بناءً على تحليل الكلمات المفتاحية في الفاتورة
  String? _predictCategory(String text) {
    final lower = text.toLowerCase();

    // 1. تصنيف: طعام ومطاعم (Food & Dining)
    final foodKeywords = [
      'restaurant',
      'cafe',
      'coffee',
      'burger',
      'pizza',
      'shawarma',
      'bakery',
      'kitchen',
      'diner',
      'grill',
      'sushi',
      'fastfood',
      'kfc',
      'mcdonald',
      'starbucks',
      'dunkin',
      'barn',
      'java',
      'caribou',
      'tim hortons',
      'maestro',
      'domino',
      'subway',
      'hardees',
      'albaik',
      'مطعم',
      'كافيه',
      'مقهى',
      'قهوة',
      'برجر',
      'بيتزا',
      'شاورما',
      'مخبز',
      'بوفيه',
      'حاشي',
      'البيك',
      'كودو',
      'هرفي',
      'بارنز',
      'دانكن',
      'ستاربكس',
      'عصير',
      'فطائر',
      'مشويات',
      'وجبات',
      'كافتيريا',
      'شاي',
    ];
    if (foodKeywords.any((k) => lower.contains(k))) {
      return 'cat_food';
    }

    // 2. تصنيف: تسوق ومقاضي وسوبرماركت (Shopping & Groceries)
    final shoppingKeywords = [
      'supermarket',
      'hypermarket',
      'grocery',
      'mart',
      'market',
      'panda',
      'lulu',
      'carrefour',
      'othaim',
      'tamimi',
      'danube',
      'bin dawood',
      'extra',
      'jarir',
      'mall',
      'store',
      'retail',
      'بقالة',
      'تموينات',
      'اسواق',
      'أسواق',
      'سوبرماركت',
      'هايبرماركت',
      'بنده',
      'العثيم',
      'التميمي',
      'الدانوب',
      'بن داود',
      'كارفور',
      'لولو',
      'جرير',
      'اكسترا',
      'سنتربوينت',
      'نون',
      'امازون',
      'تسوق',
      'متجر',
      'ملابس',
      'احذية',
      'أحذية',
    ];
    if (shoppingKeywords.any((k) => lower.contains(k))) {
      return 'cat_shopping';
    }

    // 3. تصنيف: مواصلات ومحروقات وبنزين (Transportation & Fuel)
    final transportKeywords = [
      'fuel',
      'gas',
      'petrol',
      'station',
      'oil',
      'diesel',
      'sasco',
      'aldrees',
      'naft',
      'petromin',
      'totalenergies',
      'uber',
      'careem',
      'bolt',
      'taxi',
      'parking',
      'بنزين',
      'محطة',
      'وقود',
      'ديزل',
      'بترومين',
      'الدريس',
      'ساسكو',
      'نفط',
      'اوبر',
      'كريم',
      'بولت',
      'تاكسي',
      'مواقف',
      'غسيل سيارات',
      'زيت',
      'كفرات',
    ];
    if (transportKeywords.any((k) => lower.contains(k))) {
      return 'cat_transport';
    }

    // 4. تصنيف: صحة وصيدليات وعلاج (Health & Medical)
    final healthKeywords = [
      'pharmacy',
      'medical',
      'clinic',
      'hospital',
      'dental',
      'pharma',
      'nahdi',
      'dawaa',
      'optic',
      'lab',
      'صيدلية',
      'مستشفى',
      'عيادة',
      'مجمع طبي',
      'النهدي',
      'الدواء',
      'صيدليات',
      'علاج',
      'ادوية',
      'أدوية',
      'اسنان',
      'أسنان',
      'عيون',
      'نظارات',
      'مختبر',
    ];
    if (healthKeywords.any((k) => lower.contains(k))) {
      return 'cat_health';
    }

    // 5. تصنيف: فواتير ومرافق واتصالات (Bills & Utilities)
    final billsKeywords = [
      'electric',
      'electricity',
      'sec',
      'water',
      'telecom',
      'stc',
      'mobily',
      'zain',
      'salam',
      'redbull',
      'internet',
      'fiber',
      'utility',
      'bill',
      'كهرباء',
      'مياه',
      'اتصالات',
      'اس تي سي',
      'موبايلي',
      'زين',
      'سلام',
      'انترنت',
      'شحن رصيد',
      'فاتورة جوال',
    ];
    if (billsKeywords.any((k) => lower.contains(k))) {
      return 'cat_bills';
    }

    // 6. تصنيف: ترفيه وأنشطة وسينما (Entertainment)
    final entertainmentKeywords = [
      'cinema',
      'movie',
      'vox',
      'muvi',
      'empire',
      'amc',
      'games',
      'park',
      'resort',
      'gym',
      'fitness',
      'bowling',
      'سينما',
      'فوكس',
      'موفي',
      'بولينج',
      'ملاهي',
      'العاب',
      'ألعاب',
      'منتجع',
      'شاليه',
      'نادي',
      'جيم',
      'لياقة',
      'ترفيه',
    ];
    if (entertainmentKeywords.any((k) => lower.contains(k))) {
      return 'cat_entertainment';
    }

    // 7. تصنيف: سكن وإيجار وصيانة (Housing & Maintenance)
    final housingKeywords = [
      'rent',
      'lease',
      'maintenance',
      'plumbing',
      'furniture',
      'ikea',
      'hardware',
      'ايجار',
      'إيجار',
      'سكن',
      'شقة',
      'صيانة',
      'سباكة',
      'كهربائي',
      'اثاث',
      'أثاث',
      'ايكيا',
    ];
    if (housingKeywords.any((k) => lower.contains(k))) {
      return 'cat_housing';
    }

    // 8. تصنيف: تعليم وتطوير وتدريب (Education)
    final educationKeywords = [
      'school',
      'university',
      'college',
      'course',
      'academy',
      'training',
      'مدرسة',
      'جامعة',
      'كلية',
      'معهد',
      'دورة',
      'تدريب',
      'كتب',
      'مكتبة',
      'قرطاسية',
    ];
    if (educationKeywords.any((k) => lower.contains(k))) {
      return 'cat_education';
    }

    // التصنيف الافتراضي في حال عدم تطابق الكلمات المفتاحية
    return 'cat_other_exp';
  }

  /// استخراج البنود الفردية والأصناف مع أسعارها من أسطر الفاتورة
  List<ReceiptLineItem> _extractLineItems(List<String> lines) {
    final List<ReceiptLineItem> items = [];
    // تعبير نمطي لمطابقة صيغة: [اسم الصنف] [السعر]
    final itemPattern = RegExp(r'^(.+?)\s+([0-9]+(?:\.[0-9]{1,2})?)$');

    for (final line in lines) {
      // استبعاد أسطر الملخص والمجاميع
      final lower = line.toLowerCase();
      if (lower.contains('total') ||
          lower.contains('المجموع') ||
          lower.contains('الإجمالي') ||
          lower.contains('vat') ||
          lower.contains('ضريبة') ||
          lower.contains('cash') ||
          lower.contains('change') ||
          lower.contains('subtotal')) {
        continue;
      }

      final match = itemPattern.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!.trim();
        final price = double.tryParse(match.group(2)!);
        if (name.length > 2 && price != null && price > 0 && price < 10000) {
          items.add(ReceiptLineItem(name: name, price: price));
        }
      }
    }

    return items;
  }
}
