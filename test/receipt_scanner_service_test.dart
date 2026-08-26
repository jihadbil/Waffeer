import 'package:flutter_test/flutter_test.dart';
import 'package:waffeer/core/services/receipt_scanner_service.dart';

/// اختبارات وحدة شاملة للتحقق من دقة وموثوقية خدمة التعرف الذكي على الفواتير [ReceiptScannerService]
void main() {
  group('ReceiptScannerService Tests', () {
    final service = ReceiptScannerService.instance;

    // 1. اختبار استخراج بيانات فاتورة سوبرماركت عربية بأرقام مشرقية
    test('Parses Arabic Supermarket Receipt with Eastern Arabic Numerals', () {
      const rawText = '''
أسواق كارفور السعودية
فاتورة ضريبية مبسطة
الرقم الضريبي: 300123456700003
التاريخ: ٢٠٢٤/١١/١٥ ١٤:٣٠
حليب المراعي ٢ لتر 14.50
أرز بسمتي ٥ كجم 45.00
المجموع الفرعي: 59.50
ضريبة القيمة المضافة: 8.93
المجموع الكلي: ٦٨٫٤٣
شكرا لزيارتكم
''';

      final lines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final result = service.parseReceiptText(
        rawText: rawText,
        lines: lines,
        imagePath: '/mock/path/receipt1.jpg',
      );

      // التحقق من اسم المتجر
      expect(result.merchantName, contains('أسواق كارفور'));
      // التحقق من تحويل الأرقام المشرقية وحساب المجموع الكلي
      expect(result.totalAmount, closeTo(68.43, 0.01));
      // التحقق من استخراج التاريخ بدقة
      expect(result.dateTime?.year, equals(2024));
      expect(result.dateTime?.month, equals(11));
      expect(result.dateTime?.day, equals(15));
      // التحقق من التنبؤ بتصنيف التسوق والمقاضي
      expect(result.suggestedCategoryId, equals('cat_shopping'));
      expect(result.hasExtractedAmount, isTrue);
    });

    // 2. اختبار استخراج بيانات فاتورة مقهى باللغة الإنجليزية
    test('Parses English Cafe Receipt with Total Due', () {
      const rawText = '''
STARBUCKS COFFEE
Branch #482 Riyadh
Tax Invoice
Date: 2025-02-10 09:15 AM
1x Iced Spanish Latte 22.00
1x Croissant Cheese 14.00
Subtotal: 36.00
VAT 15%: 5.40
Total Due: 41.40 SAR
Paid by Apple Pay
Thank you!
''';

      final lines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final result = service.parseReceiptText(
        rawText: rawText,
        lines: lines,
        imagePath: '/mock/path/starbucks.jpg',
      );

      // التحقق من اسم المتجر والمبلغ الإجمالي
      expect(result.merchantName, equals('STARBUCKS COFFEE'));
      expect(result.totalAmount, closeTo(41.40, 0.01));
      // التحقق من التاريخ والوقت
      expect(result.dateTime?.year, equals(2025));
      expect(result.dateTime?.month, equals(2));
      expect(result.dateTime?.day, equals(10));
      expect(result.dateTime?.hour, equals(9));
      expect(result.dateTime?.minute, equals(15));
      // التحقق من تصنيف المطاعم والمقاهي
      expect(result.suggestedCategoryId, equals('cat_food'));
    });

    // 3. اختبار استخراج بيانات فاتورة محطة وقود ومحروقات
    test('Parses Gas Station Fuel Receipt', () {
      const rawText = '''
محطة الدريس للمحروقات
فاتورة مبيعات
التاريخ: 12-08-2024
بنزين 91 ممتاز 85.00
الإجمالي: 85.00 ريال
الدفع: مدى
''';

      final lines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final result = service.parseReceiptText(
        rawText: rawText,
        lines: lines,
        imagePath: '/mock/path/fuel.jpg',
      );

      expect(result.merchantName, contains('محطة الدريس'));
      expect(result.totalAmount, closeTo(85.00, 0.01));
      expect(result.dateTime?.year, equals(2024));
      expect(result.dateTime?.month, equals(8));
      expect(result.dateTime?.day, equals(12));
      expect(result.suggestedCategoryId, equals('cat_transport'));
    });

    // 4. اختبار استخراج بيانات فاتورة صيدلية وعلاج
    test('Parses Pharmacy Receipt', () {
      const rawText = '''
صيدلية النهدي
فاتورة شراء
التاريخ: 2024/09/20
بنادول أدفانس 18.50
فيتامين سي 35.00
المبلغ المطلوب: 53.50
''';

      final lines = rawText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final result = service.parseReceiptText(
        rawText: rawText,
        lines: lines,
        imagePath: '/mock/path/nahdi.jpg',
      );

      expect(result.merchantName, contains('صيدلية النهدي'));
      expect(result.totalAmount, closeTo(53.50, 0.01));
      expect(result.suggestedCategoryId, equals('cat_health'));
    });
  });
}
