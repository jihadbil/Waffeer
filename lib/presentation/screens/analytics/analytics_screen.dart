import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/category_icon_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/export_bottom_sheet.dart';

/// شاشة الإحصائيات والتحليلات البيانية المتقدمة Waffeer Analytics 2.0
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedPieIndex = -1;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final txProvider = context.watch<TransactionProvider>();
    final catProvider = context.watch<CategoryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final breakdown = txProvider.categoryExpenseBreakdownForMonth(
      _currentMonth,
    );
    final totalExpense = txProvider.expenseForMonth(_currentMonth);
    final totalIncome = txProvider.incomeForMonth(_currentMonth);
    final savingsRate = txProvider.savingsRateForMonth(_currentMonth);
    final trends = txProvider.getMonthlyTrends(6);

    // حساب متوسط الصرف اليومي
    final now = DateTime.now();
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final isCurrentMonth =
        _currentMonth.year == now.year && _currentMonth.month == now.month;
    final divisor = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvgExpense = divisor > 0 ? totalExpense / divisor : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'الإحصائيات والتحليلات' : 'Analytics & Reports',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 22),
            tooltip: isArabic
                ? 'تصدير ومشاركة التقرير'
                : 'Export & Share Report',
            onPressed: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ExportBottomSheet(),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          // 1. شريط التنقل بين الأشهر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    isArabic
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  DateFormatter.formatMonthYear(
                    _currentMonth,
                    isArabic: isArabic,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Cairo',
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isArabic
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                  ),
                  onPressed: isCurrentMonth
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _currentMonth = DateTime(
                              _currentMonth.year,
                              _currentMonth.month + 1,
                            );
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. كروت ملخص الدخل والمصروف
          Row(
            children: [
              Expanded(
                child: _buildSummaryBadge(
                  label: isArabic ? 'إجمالي الدخل' : 'Total Income',
                  amount: CurrencyFormatter.format(
                    totalIncome,
                    currencyCode: settings.currencyCode,
                    isArabic: isArabic,
                  ),
                  color: AppColors.income,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryBadge(
                  label: isArabic ? 'إجمالي المصاريف' : 'Total Expenses',
                  amount: CurrencyFormatter.format(
                    totalExpense,
                    currencyCode: settings.currencyCode,
                    isArabic: isArabic,
                  ),
                  color: AppColors.expense,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. كرت المؤشرات المالية الذكية (معدل الادخار ومتوسط الصرف اليومي)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A302A), const Color(0xFF1A302A)]
                    : [
                        AppColors.primary.withValues(alpha: 0.12),
                        const Color(0xFFEAF1ED),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.35 : 0.25,
                ),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.savings_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isArabic
                              ? 'معدل التوفير والادخار'
                              : 'Monthly Savings Rate',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${savingsRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // شريط تقدم معدل الادخار
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (savingsRate / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.withValues(
                      alpha: isDark ? 0.2 : 0.15,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 7,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic ? 'متوسط الصرف اليومي:' : 'Daily Average:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(
                        dailyAvgExpense,
                        currencyCode: settings.currencyCode,
                        isArabic: isArabic,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. رسم بياني لتوزيع المصاريف (Donut Chart)
          Text(
            isArabic ? 'توزيع المصاريف حسب التصنيف' : 'Expenses Breakdown',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),

          if (breakdown.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: EmptyStateWidget(
                icon: Icons.pie_chart_outline,
                title: isArabic
                    ? 'لا توجد مصاريف مسجلة هذا الشهر'
                    : 'No expenses recorded this month',
              ),
            )
          else ...[
            Container(
              height: 240,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
                boxShadow: const [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 52,
                      sections: _buildPieSections(
                        breakdown,
                        catProvider,
                        totalExpense,
                      ),
                    ),
                  ),
                  // ملخص الدائرة بالمنتصف
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArabic ? 'المجموع' : 'Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          totalExpense,
                          currencyCode: settings.currencyCode,
                          isArabic: isArabic,
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expense,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. تفاصيل بنود النفقات مع أشرطة تقدم ملونة
            Text(
              isArabic ? 'تفاصيل النفقات والتصنيفات' : 'Category Details',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 10),

            ...breakdown.entries.map((entry) {
              final cat = catProvider.getById(entry.key);
              final percentage = totalExpense > 0
                  ? (entry.value / totalExpense * 100)
                  : 0.0;
              final catColor = cat?.color ?? AppColors.expense;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CategoryIconWidget(
                          iconData: cat?.iconData ?? Icons.category,
                          color: catColor,
                          size: 42,
                          iconSize: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat?.localizedName(isArabic) ??
                                    (isArabic ? 'أخرى' : 'Other'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${percentage.toStringAsFixed(1)}% ${isArabic ? "من إجمالي المصاريف" : "of total expenses"}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                            entry.value,
                            currencyCode: settings.currencyCode,
                            isArabic: isArabic,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: AppColors.expense,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // شريط نسبة التصنيف
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: catColor.withValues(
                          alpha: isDark ? 0.15 : 0.10,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(catColor),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 24),

          // 6. رسم بياني لمقارنة الدخل والمصاريف (آخر 6 أشهر)
          Text(
            isArabic
                ? 'مقارنة الدخل والمصاريف (آخر 6 أشهر)'
                : 'Income vs Expenses (Last 6 Months)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // دليل الرسم البياني (Legend)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(
                      color: AppColors.income,
                      label: isArabic ? 'الدخل' : 'Income',
                    ),
                    const SizedBox(width: 24),
                    _buildLegendItem(
                      color: AppColors.expense,
                      label: isArabic ? 'المصاريف' : 'Expenses',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: trends.isEmpty
                          ? 100
                          : (trends
                                    .map(
                                      (t) => t.income > t.expense
                                          ? t.income
                                          : t.expense,
                                    )
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < trends.length) {
                                final m = trends[index].month;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormatter.formatMonth(
                                      m,
                                      isArabic: isArabic,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(trends.length, (i) {
                        final t = trends[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: t.income,
                              color: AppColors.income,
                              width: 9,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            BarChartRodData(
                              toY: t.expense,
                              color: AppColors.expense,
                              width: 9,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBadge({
    required String label,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Cairo',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    Map<String, double> breakdown,
    CategoryProvider catProvider,
    double totalExpense,
  ) {
    final entries = breakdown.entries.toList();
    return List.generate(entries.length, (i) {
      final isTouched = i == _touchedPieIndex;
      final entry = entries[i];
      final cat = catProvider.getById(entry.key);
      final double fontSize = isTouched ? 15 : 11.5;
      final double radius = isTouched ? 65 : 55;
      final percentage = totalExpense > 0
          ? (entry.value / totalExpense * 100)
          : 0.0;

      return PieChartSectionData(
        color: cat?.color ?? AppColors.expense,
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFamily: 'Cairo',
        ),
      );
    });
  }
}
