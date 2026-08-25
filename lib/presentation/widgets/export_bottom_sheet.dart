import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';

class ExportBottomSheet extends StatefulWidget {
  const ExportBottomSheet({super.key});

  @override
  State<ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<ExportBottomSheet> {
  String _selectedFormat = 'pdf'; // 'pdf' or 'csv'
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isAllTime = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'تصدير ومشاركة التقرير المالي' : 'Export & Share Financial Report',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Format Selection
          Text(
            isArabic ? 'صيغة التصدير' : 'Export Format',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFormatCard(
                  id: 'pdf',
                  title: isArabic ? 'تقرير PDF رسمي' : 'Official PDF Report',
                  subtitle: isArabic ? 'كشف حساب منسق وجداول' : 'Formatted Statement & Tables',
                  icon: Icons.picture_as_pdf_rounded,
                  color: Colors.redAccent,
                  isSelected: _selectedFormat == 'pdf',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormatCard(
                  id: 'csv',
                  title: isArabic ? 'جدول Excel / CSV' : 'Excel / CSV Sheet',
                  subtitle: isArabic ? 'بيانات رقمية قابلة للتحليل' : 'Raw Data for Spreadsheets',
                  icon: Icons.table_chart_rounded,
                  color: Colors.green,
                  isSelected: _selectedFormat == 'csv',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Period Selection
          Text(
            isArabic ? 'الفترة الزمنية' : 'Time Period',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              ChoiceChip(
                label: Text(isArabic ? 'هذا الشهر' : 'Selected Month'),
                selected: !_isAllTime,
                onSelected: (val) {
                  setState(() => _isAllTime = false);
                },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: Text(isArabic ? 'كل المعاملات' : 'All Time'),
                selected: _isAllTime,
                onSelected: (val) {
                  setState(() => _isAllTime = true);
                },
              ),
            ],
          ),

          if (!_isAllTime) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(isArabic ? Icons.chevron_right : Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                      });
                    },
                  ),
                  Text(
                    DateFormatter.formatMonthYear(_selectedMonth, isArabic: isArabic),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: Icon(isArabic ? Icons.chevron_left : Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Export Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded, color: Colors.white),
              label: Text(
                _isExporting
                    ? (isArabic ? 'جاري تجهيز التقرير...' : 'Generating Report...')
                    : (isArabic ? 'تصدير ومشاركة الآن' : 'Export & Share Now'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              onPressed: _isExporting ? null : () => _performExport(context),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFormatCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.1)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? color : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport(BuildContext context) async {
    setState(() => _isExporting = true);

    final txProvider = context.read<TransactionProvider>();
    final catProvider = context.read<CategoryProvider>();
    final walletProvider = context.read<WalletProvider>();
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;

    // Filter transactions by chosen range
    final allTxs = txProvider.transactions;
    final filtered = _isAllTime
        ? allTxs
        : allTxs.where((t) => t.dateTime.year == _selectedMonth.year && t.dateTime.month == _selectedMonth.month).toList();

    final catMap = {for (var c in catProvider.categories) c.id: c};
    final walletMap = {for (var w in walletProvider.wallets) w.id: w};

    final periodTitle = _isAllTime
        ? (isArabic ? 'كافة المعاملات التاريخية' : 'All Historical Transactions')
        : DateFormatter.formatMonthYear(_selectedMonth, isArabic: isArabic);

    final totalIncome = filtered
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = filtered
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_selectedFormat == 'pdf') {
        await PdfReportService.generateAndShareReport(
          periodTitle: periodTitle,
          transactions: filtered,
          categoryMap: catMap,
          walletMap: walletMap,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          currencyCode: settings.currencyCode,
          isArabic: isArabic,
        );
      } else {
        await CsvExportService.exportTransactionsToCsv(
          transactions: filtered,
          categoryMap: catMap,
          walletMap: walletMap,
          isArabic: isArabic,
          title: '${isArabic ? "تقرير المعاملات" : "Transactions Report"} - $periodTitle',
        );
      }

      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'فشل التصدير: $e' : 'Export failed: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
