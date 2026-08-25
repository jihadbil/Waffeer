import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_icon_widget.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إدارة التصنيفات' : 'Categories Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: [
            Tab(text: isArabic ? 'تصنيفات المصاريف' : 'Expense Categories'),
            Tab(text: isArabic ? 'تصنيفات المداخيل' : 'Income Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(catProvider.expenseCategories, CategoryType.expense, isArabic),
          _buildCategoryList(catProvider.incomeCategories, CategoryType.income, isArabic),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context),
        icon: const Icon(Icons.add),
        label: Text(isArabic ? 'إضافة تصنيف' : 'Add Category'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCategoryList(List<CategoryModel> list, CategoryType type, bool isArabic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final cat = list[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              CategoryIconWidget(
                iconData: cat.iconData,
                color: cat.color,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.localizedName(isArabic),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      isArabic ? cat.nameEn : cat.nameAr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (!cat.isDefault)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 20),
                  onPressed: () => context.read<CategoryProvider>().deleteCategory(cat.id),
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
    int selectedIcon = 0xe57a; // restaurant
    CategoryType selectedType = _tabController.index == 0 ? CategoryType.expense : CategoryType.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'إضافة تصنيف جديد' : 'Add New Category',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: arController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اسم التصنيف بالعربية' : 'Name in Arabic',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: enController,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'اسم التصنيف بالإنجليزية' : 'Name in English',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Type
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(isArabic ? 'مصروف' : 'Expense'),
                          selected: selectedType == CategoryType.expense,
                          onSelected: (val) => setModalState(() => selectedType = CategoryType.expense),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(isArabic ? 'دخل' : 'Income'),
                          selected: selectedType == CategoryType.income,
                          onSelected: (val) => setModalState(() => selectedType = CategoryType.income),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final nameAr = arController.text.trim();
                          final nameEn = enController.text.trim();
                          if (nameAr.isNotEmpty || nameEn.isNotEmpty) {
                            context.read<CategoryProvider>().addCategory(
                              nameAr: nameAr.isNotEmpty ? nameAr : nameEn,
                              nameEn: nameEn.isNotEmpty ? nameEn : nameAr,
                              iconCodePoint: selectedIcon,
                              colorValue: selectedColor,
                              type: selectedType,
                            );
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isArabic ? 'حفظ التصنيف' : 'Save Category'),
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
