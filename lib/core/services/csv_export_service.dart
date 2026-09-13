import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/wallet_model.dart';
import '../utils/date_formatter.dart';

class CsvExportService {
  static Future<void> exportTransactionsToCsv({
    required List<TransactionModel> transactions,
    required Map<String, CategoryModel> categoryMap,
    required Map<String, WalletModel> walletMap,
    required bool isArabic,
    String? title,
  }) async {
    final List<List<dynamic>> rows = [];

    // Header Row
    if (isArabic) {
      rows.add([
        'المعرف',
        'التاريخ والوقت',
        'النوع',
        'التصنيف',
        'المحفظة / الحساب',
        'إلى محفظة (تحويل)',
        'المبلغ',
        'العملة',
        'العنوان',
        'الملاحظات',
      ]);
    } else {
      rows.add([
        'ID',
        'Date & Time',
        'Type',
        'Category',
        'Wallet',
        'To Wallet (Transfer)',
        'Amount',
        'Currency',
        'Title',
        'Note',
      ]);
    }

    // Data Rows
    for (final tx in transactions) {
      final cat = categoryMap[tx.categoryId];
      final wallet = walletMap[tx.walletId];
      final toWallet = tx.toWalletId != null ? walletMap[tx.toWalletId] : null;

      String typeLabel;
      switch (tx.type) {
        case TransactionType.expense:
          typeLabel = isArabic ? 'مصروف' : 'Expense';
          break;
        case TransactionType.income:
          typeLabel = isArabic ? 'دخل' : 'Income';
          break;
        case TransactionType.transfer:
          typeLabel = isArabic ? 'تحويل' : 'Transfer';
          break;
      }

      rows.add([
        tx.id,
        DateFormatter.formatDateTime(tx.dateTime, isArabic: isArabic),
        typeLabel,
        cat?.localizedName(isArabic) ?? (isArabic ? 'أخرى' : 'Other'),
        wallet?.localizedName(isArabic) ?? tx.walletId,
        toWallet?.localizedName(isArabic) ?? (tx.toWalletId ?? ''),
        tx.amount,
        tx.currencyCode,
        tx.title ?? '',
        tx.note ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    // Add UTF-8 BOM for Excel to open Arabic CSV files properly
    final utf8Bom = [0xEF, 0xBB, 0xBF];
    final tempDir = await getTemporaryDirectory();
    final fileName = 'Waffeer_Export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${tempDir.path}/$fileName');

    final bytes = utf8Bom + utf8.encode(csvData);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: title ?? (isArabic ? 'تقرير المعاملات المالية - وفير' : 'Waffeer Financial Transactions Report'),
    );
  }
}
