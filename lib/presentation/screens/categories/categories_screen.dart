import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_icon_widget.dart';

/// شاشة إدارة وتخصيص التصنيفات المالية بتصميم Fintech Luxury 2.0
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final catProvider = context.watch<CategoryProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'إدارة التصنيفات' : 'Categories Management',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textDarkMuted
              : AppColors.textLightMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 13.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
            fontSize: 13,
          ),
          onTap: (_) => HapticFeedback.selectionClick(),
          tabs: [
            Tab(text: isArabic ? 'تصنيفات المصاريف' : 'Expense Categories'),
            Tab(text: isArabic ? 'تصنيفات المداخيل' : 'Income Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(
            catProvider.expenseCategories,
            CategoryType.expense,
            isArabic,
          ),
          _buildCategoryList(
            catProvider.incomeCategories,
            CategoryType.income,
            isArabic,
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: const [],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showAddCategoryDialog(context);
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            isArabic ? 'إضافة تصنيف' : 'Add Category',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    List<CategoryModel> list,
    CategoryType type,
    bool isArabic,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 84),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final cat = list[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow: const [],
          ),
          child: Row(
            children: [
              CategoryIconWidget(
                iconData: cat.iconData,
                color: cat.color,
                size: 46,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.localizedName(isArabic),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    Text(
                      isArabic ? cat.nameEn : cat.nameAr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              if (!cat.isDefault)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense,
                    size: 20,
                  ),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    try {
                      await context.read<CategoryProvider>().deleteCategory(
                        cat.id,
                      );
                    } on StateError {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isArabic
                                ? 'لا يمكن حذف تصنيف مستخدم في معاملات أو ميزانيات أو مصروفات دورية.'
                                : 'This category is in use by transactions, budgets, or routines.',
                          ),
                          backgroundColor: AppColors.expense,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final isArabic = context.read<SettingsProvider>().isArabic;
    final arController = TextEditingController();
    final enController = TextEditingController();
    int selectedColor = 0xFF3B82F6;
    int selectedIcon = Icons.restaurant.codePoint;
    CategoryType selectedType = _tabController.index == 0
        ? CategoryType.expense
        : CategoryType.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(ctx).cardTheme.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isArabic ? 'إضافة تصنيف جديد' : 'Add New Category',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: arController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اسم التصنيف' : 'Category Name',
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(ctx)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: Text(
                          isArabic
                              ? 'خيارات إضافية (الاسم بالإنجليزي)'
                              : 'Additional options (English Name)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          TextField(
                            controller: enController,
                            decoration: InputDecoration(
                              labelText: isArabic
                                  ? 'الاسم بالإنجليزية (اختياري)'
                                  : 'English Name (Optional)',
                              hintText: 'e.g., Shopping, Freelance',
                              prefixIcon: const Icon(Icons.language, size: 18),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(
                            isArabic ? 'مصروف' : 'Expense',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: selectedType == CategoryType.expense,
                          selectedColor: AppColors.expense.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (val) => setModalState(
                            () => selectedType = CategoryType.expense,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: Text(
                            isArabic ? 'دخل' : 'Income',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: selectedType == CategoryType.income,
                          selectedColor: AppColors.income.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (val) => setModalState(
                            () => selectedType = CategoryType.income,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final main = arController.text.trim();
                          final secondary = enController.text.trim();
                          if (main.isEmpty && secondary.isEmpty) return;

                          final nameAr = main.isNotEmpty ? main : secondary;
                          final nameEn = secondary.isNotEmpty
                              ? secondary
                              : nameAr;

                          HapticFeedback.mediumImpact();
                          await ctx.read<CategoryProvider>().addCategory(
                            nameAr: nameAr,
                            nameEn: nameEn,
                            iconCodePoint: selectedIcon,
                            colorValue: selectedColor,
                            type: selectedType,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isArabic ? 'حفظ التصنيف ✓' : 'Save Category ✓',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
