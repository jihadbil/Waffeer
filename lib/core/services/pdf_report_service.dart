import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/wallet_model.dart';
import '../utils/date_formatter.dart';
import '../utils/currency_formatter.dart';

class PdfReportService {
  static Future<void> generateAndShareReport({
    required String periodTitle,
    required List<TransactionModel> transactions,
    required Map<String, CategoryModel> categoryMap,
    required Map<String, WalletModel> walletMap,
    required double totalIncome,
    required double totalExpense,
    required String currencyCode,
    required bool isArabic,
  }) async {
    final pdf = pw.Document();

    // Load Cairo Arabic Font using Printing package
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBoldFont = await PdfGoogleFonts.cairoBold();

    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? ((netSavings / totalIncome) * 100).clamp(0.0, 100.0) : 0.0;

    // Calculate category breakdown
    final Map<String, double> categoryTotals = {};
    for (final tx in transactions.where((t) => t.type == TransactionType.expense)) {
      categoryTotals[tx.categoryId] = (categoryTotals[tx.categoryId] ?? 0.0) + tx.amount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBoldFont,
        ),
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(
          periodTitle: periodTitle,
          isArabic: isArabic,
          fontBold: arabicBoldFont,
        ),
        footer: (context) => _buildPdfFooter(
          context: context,
          isArabic: isArabic,
          font: arabicFont,
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          // Summary KPI Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricCard(
                  title: isArabic ? 'إجمالي الدخل' : 'Total Income',
                  value: CurrencyFormatter.format(totalIncome, currencyCode: currencyCode, isArabic: isArabic),
                  color: PdfColors.green700,
                  fontBold: arabicBoldFont,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildMetricCard(
                  title: isArabic ? 'إجمالي المصاريف' : 'Total Expenses',
                  value: CurrencyFormatter.format(totalExpense, currencyCode: currencyCode, isArabic: isArabic),
                  color: PdfColors.red700,
                  fontBold: arabicBoldFont,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildMetricCard(
                  title: isArabic ? 'صافي التوفير' : 'Net Savings',
                  value: CurrencyFormatter.format(netSavings, currencyCode: currencyCode, isArabic: isArabic),
                  color: netSavings >= 0 ? PdfColors.blue700 : PdfColors.red700,
                  fontBold: arabicBoldFont,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildMetricCard(
                  title: isArabic ? 'نسبة الادخار' : 'Savings Rate',
                  value: '${savingsRate.toStringAsFixed(1)}%',
                  color: PdfColors.teal700,
                  fontBold: arabicBoldFont,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Category Breakdown Table
          if (categoryTotals.isNotEmpty) ...[
            pw.Text(
              isArabic ? '📊 توزيع المصاريف حسب التصنيف' : '📊 Category Breakdown',
              style: pw.TextStyle(font: arabicBoldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            _buildCategoryTable(
              categoryTotals: categoryTotals,
              categoryMap: categoryMap,
              totalExpense: totalExpense,
              currencyCode: currencyCode,
              isArabic: isArabic,
              fontBold: arabicBoldFont,
            ),
            pw.SizedBox(height: 24),
          ],

          // Detailed Transactions Table
          pw.Text(
            isArabic ? '📝 سجل المعاملات التفصيلي' : '📝 Detailed Transactions Log',
            style: pw.TextStyle(font: arabicBoldFont, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          _buildTransactionsTable(
            transactions: transactions,
            categoryMap: categoryMap,
            walletMap: walletMap,
            currencyCode: currencyCode,
            isArabic: isArabic,
            fontBold: arabicBoldFont,
          ),
        ],
      ),
    );

    final fileName = 'Waffeer_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
  }

  static pw.Widget _buildPdfHeader({
    required String periodTitle,
    required bool isArabic,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isArabic ? 'تطبيق وفير - التقرير المالي' : 'Waffeer - Financial Report',
                style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue800),
              ),
              pw.Text(
                periodTitle,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Text(
            DateFormatter.formatDate(DateTime.now(), isArabic: isArabic),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter({
    required pw.Context context,
    required bool isArabic,
    required pw.Font font,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            isArabic ? 'تم الإنشاء بواسطة تطبيق وفير (Waffeer)' : 'Generated by Waffeer Finance App',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricCard({
    required String title,
    required String value,
    required PdfColor color,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: color.luminance > 0.5 ? PdfColors.grey100 : PdfColor(color.red, color.green, color.blue, 0.08),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(font: fontBold, fontSize: 11, color: color),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCategoryTable({
    required Map<String, double> categoryTotals,
    required Map<String, CategoryModel> categoryMap,
    required double totalExpense,
    required String currencyCode,
    required bool isArabic,
    required pw.Font fontBold,
  }) {
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell(isArabic ? 'التصنيف' : 'Category', fontBold),
            _tableHeaderCell(isArabic ? 'المبلغ' : 'Amount', fontBold),
            _tableHeaderCell(isArabic ? 'النسبة' : 'Percentage', fontBold),
          ],
        ),
        ...sortedEntries.map((e) {
          final cat = categoryMap[e.key];
          final percent = totalExpense > 0 ? (e.value / totalExpense * 100) : 0.0;
          return pw.TableRow(
            children: [
              _tableBodyCell(cat?.localizedName(isArabic) ?? (isArabic ? 'أخرى' : 'Other')),
              _tableBodyCell(CurrencyFormatter.format(e.value, currencyCode: currencyCode, isArabic: isArabic)),
              _tableBodyCell('${percent.toStringAsFixed(1)}%'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable({
    required List<TransactionModel> transactions,
    required Map<String, CategoryModel> categoryMap,
    required Map<String, WalletModel> walletMap,
    required String currencyCode,
    required bool isArabic,
    required pw.Font fontBold,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell(isArabic ? 'التاريخ' : 'Date', fontBold),
            _tableHeaderCell(isArabic ? 'البيان والتصنيف' : 'Description & Category', fontBold),
            _tableHeaderCell(isArabic ? 'الحساب' : 'Account', fontBold),
            _tableHeaderCell(isArabic ? 'المبلغ' : 'Amount', fontBold),
          ],
        ),
        ...transactions.take(100).map((tx) {
          final cat = categoryMap[tx.categoryId];
          final wallet = walletMap[tx.walletId];
          final sign = tx.type == TransactionType.expense ? '-' : (tx.type == TransactionType.income ? '+' : '');

          return pw.TableRow(
            children: [
              _tableBodyCell(DateFormatter.formatDate(tx.dateTime, isArabic: isArabic)),
              _tableBodyCell('${tx.title ?? cat?.localizedName(isArabic) ?? ""} (${cat?.localizedName(isArabic) ?? ""})'),
              _tableBodyCell(wallet?.localizedName(isArabic) ?? tx.walletId),
              _tableBodyCell(
                '$sign${CurrencyFormatter.format(tx.amount, currencyCode: tx.currencyCode, isArabic: isArabic)}',
                color: tx.type == TransactionType.expense
                    ? PdfColors.red700
                    : (tx.type == TransactionType.income ? PdfColors.green700 : PdfColors.blue700),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.black),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableBodyCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
