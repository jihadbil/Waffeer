import 'package:flutter_test/flutter_test.dart';
import 'package:waffeer/core/services/receipt_scanner_service.dart';
import 'package:waffeer/data/models/receipt_model.dart';

/// اختبارات نموذج الفاتورة ParsedReceipt وعمليات الاستخراج الأساسية
void main() {
  // 1. اختبار تهيئة نموذج الفاتورة والخصائص المشتقة
  test('ParsedReceipt model instantiates and properties work', () {
    const receipt = ParsedReceipt(
      imagePath: '/test/image.jpg',
      totalAmount: 150.75,
      merchantName: 'Al Baik',
      suggestedCategoryId: 'cat_food',
      confidenceScore: 0.9,
    );

    expect(receipt.hasExtractedAmount, isTrue);
    expect(receipt.hasExtractedMerchant, isTrue);
    expect(receipt.totalAmount, equals(150.75));
    expect(receipt.merchantName, equals('Al Baik'));
  });

  // 2. اختبار كشف المبلغ والتاريخ مع نصوص العملات
  test('ReceiptScannerService detects total with currency text', () {
    final service = ReceiptScannerService.instance;
    const text = 'المجموع الكلي: 240.00 ر.س\nتاريخ: 2025/01/01';
    final lines = text.split('\n');

    final parsed = service.parseReceiptText(
      rawText: text,
      lines: lines,
      imagePath: '/test/receipt.jpg',
    );

    expect(parsed.totalAmount, equals(240.00));
    expect(parsed.dateTime?.year, equals(2025));
  });
}
