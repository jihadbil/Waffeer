import '../../data/models/category_model.dart';

/// محرك مطابقة التصنيفات الذكي لتطبيق "وفير"
///
/// يوفر:
/// 1. تطبيع النصوص العربية (إزالة التشكيل، توحيد الهمزات والتاء المربوطة والياء).
/// 2. قاموس المرادفات والمصطلحات المالية الشائعة (مفرد/جمع/عامية).
/// 3. مطابقة دقيقة أو تقريبية بناءً على المعرف، الاسم، أو سياق المعاملة.
class CategoryMatcher {
  CategoryMatcher._();

  /// تطبيع النص العربي لإجراء مقارنات دقيقة غير حساسة لاختلافات الإملاء
  static String normalizeArabic(String input) {
    if (input.isEmpty) return '';

    var text = input.trim().toLowerCase();

    // 1. إزالة التشكيل (Tashkeel / Diacritics)
    text = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

    // 2. توحيد أشكال الألف (أ، إ، آ، ٱ -> ا)
    text = text.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // 3. توحيد التاء المربوطة والهاء (ة -> ه)
    text = text.replaceAll('ة', 'ه');

    // 4. توحيد الياء والألف المقصورة (ى -> ي)
    text = text.replaceAll('ى', 'ي');

    // 5. توحيد وتسهيل الهمزات (ؤ، ئ -> ء)
    text = text.replaceAll(RegExp(r'[ؤئ]'), 'ء');

    // 6. استبدال علامات الترقيم والرموز بمسافة
    text = text.replaceAll(RegExp(r'[\-_/\\,،.;:!؟()\[\]{}"]'), ' ');

    // 7. إزالة المسافات المكررة
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// قاموس المرادفات المالية الشائعة المصنفة بحسب المعرفات الافتراضية
  static final Map<String, List<String>> _synonyms = {
    // دخل: هدايا ومكافآت
    'cat_gift': [
      'هديه', 'هدايا', 'مكافاه', 'مكافات', 'مكافئه', 'مكافئات',
      'عيديه', 'عيدية', 'جايزه', 'جوائز', 'جائزه', 'هبه', 'هبات',
      'اكراميه', 'اكراميات', 'بونص', 'gift', 'gifts', 'reward', 'rewards',
      'bonus', 'present',
    ],
    // دخل: راتب شهري
    'cat_salary': [
      'راتب', 'رواتب', 'معاش', 'معاشات', 'مرتب', 'مرتبات',
      'اجر', 'اجور', 'بدل', 'بدلات', 'راتبي', 'مستحقات',
      'salary', 'payroll', 'wage', 'wages',
    ],
    // دخل: عمل حر ومشاريع
    'cat_freelance': [
      'مشروع', 'مشاريع', 'فريلانس', 'عمل حر', 'اعمال حره',
      'استشاره', 'استشارات', 'خدمه', 'خدمات', 'مبيعات', 'بيع',
      'freelance', 'project', 'projects', 'consulting',
    ],
    // دخل: استثمار وأرباح
    'cat_investment': [
      'استثمار', 'استثمارات', 'ارباح', 'ربح', 'اسهم', 'سهم',
      'تداول', 'عوائد', 'عائد', 'توزيعات', 'كريبتو', 'عملات',
      'investment', 'investments', 'profit', 'profits', 'stocks', 'dividends',
    ],
    // مصروف: طعام ومطاعم
    'cat_food': [
      'طعام', 'اكل', 'مطعم', 'مطاعم', 'كافيه', 'كافيهات', 'مقهي', 'مقاهي',
      'قهوه', 'قهوة', 'شاي', 'غداء', 'غدا', 'عشاء', 'فطور', 'فطار',
      'وجبه', 'وجبات', 'سناك', 'بقاله', 'بقالة', 'تموينات', 'سوبرماركت',
      'ماركت', 'شاورما', 'برجر', 'بيتزا', 'حلويات', 'عصير', 'مشروبات',
      'food', 'restaurant', 'restaurants', 'cafe', 'coffee', 'groceries',
    ],
    // مصروف: مواصلات وبنزين
    'cat_transport': [
      'مواصلات', 'نقل', 'بنزين', 'وقود', 'غاز', 'تاكسي', 'تكسي',
      'اوبر', 'كريم', 'باص', 'حافله', 'مترو', 'قطار', 'طيران',
      'تذكره', 'تذاكر', 'سياره', 'سيارات', 'زيت', 'صيانه سياره',
      'مواقف', 'باركنج', 'transport', 'transportation', 'taxi', 'uber',
      'careem', 'gas', 'fuel', 'flight',
    ],
    // مصروف: تسوق ومقاضي
    'cat_shopping': [
      'تسوق', 'مقاضي', 'ملابس', 'ثياب', 'حذاء', 'احذيه', 'جزمه',
      'شنطه', 'شنط', 'ساعه', 'عطور', 'مكياج', 'شراء', 'سوق', 'مول',
      'مشتريات', 'الكترونيات', 'shopping', 'clothes', 'shoes', 'fashion',
    ],
    // مصروف: سكن وإيجار
    'cat_housing': [
      'سكن', 'ايجار', 'بيت', 'شقه', 'منزل', 'صيانه منزل',
      'اثاث', 'ديكور', 'rent', 'housing', 'apartment', 'home',
    ],
    // مصروف: فواتير ومرافق
    'cat_bills': [
      'فاتوره', 'فواتير', 'كهرباء', 'كهربا', 'ماء', 'مياه',
      'نت', 'انترنت', 'شحن', 'هاتف', 'اتصالات', 'جوال', 'رصيد',
      'قسط', 'اقساط', 'اشتراك', 'اشتراكات', 'bill', 'bills',
      'utilities', 'electricity', 'water', 'internet', 'subscription',
    ],
    // مصروف: صحة وعلاج
    'cat_health': [
      'صحه', 'صحة', 'علاج', 'طبيب', 'دكتور', 'مستشفي', 'مستشفى',
      'عياده', 'عيادة', 'صيدليه', 'صيدلية', 'دواء', 'ادويه', 'ادوية',
      'فحص', 'تحاليل', 'نظاره', 'نظارات', 'اسنان', 'medical', 'health',
      'pharmacy', 'medicine', 'hospital', 'doctor',
    ],
    // مصروف: ترفيه وأنشطة
    'cat_entertainment': [
      'ترفيه', 'انشطه', 'انشطة', 'سينما', 'فيلم', 'افلام',
      'العاب', 'رحله', 'رحلات', 'سفر', 'سياحه', 'شاليه',
      'منتزه', 'ملاهي', 'بلايستيشن', 'جيم', 'رياضه', 'نادي',
      'entertainment', 'cinema', 'games', 'trip', 'travel', 'gym',
    ],
    // مصروف: تعليم وتطوير
    'cat_education': [
      'تعليم', 'تطوير', 'دراسه', 'دراسة', 'مدرسه', 'مدرسة',
      'جامعه', 'جامعة', 'كتاب', 'كتب', 'كورس', 'كورسات',
      'دوره', 'دورات', 'تدريب', 'قرطاسيه', 'education', 'school',
      'university', 'course', 'books',
    ],
  };

  /// البحث عن أفضل تصنيف يطابق المعطيات من بين قائمة التصنيفات المتاحة
  static CategoryModel findBestCategory({
    required List<CategoryModel> categories,
    required CategoryType targetType,
    String? categoryId,
    String? categoryName,
    String? fallbackQuery,
  }) {
    // 1. استبعاد التصنيفات غير المتطابقة في النوع أولاً
    final candidates = categories.where((c) => c.type == targetType).toList();
    if (candidates.isEmpty) {
      // إن لم تتوفر تصنيفات من نفس النوع، استخدم كل التصنيفات
      if (categories.isNotEmpty) return categories.first;
      throw StateError('Categories list cannot be empty');
    }

    // 2. المطابقة بالمعرف المباشر (Direct Category ID Match)
    if (categoryId != null && categoryId.trim().isNotEmpty) {
      final cleanId = categoryId.trim();
      final exactId = candidates.where((c) => c.id == cleanId).firstOrNull;
      if (exactId != null) return exactId;
    }

    // 3. المطابقة بواسطة الاسم أو الاستعلام
    final queriesToTry = <String>[];
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      queriesToTry.add(categoryName.trim());
    }
    if (fallbackQuery != null && fallbackQuery.trim().isNotEmpty) {
      queriesToTry.add(fallbackQuery.trim());
    }

    for (final rawQuery in queriesToTry) {
      final normalizedQuery = normalizeArabic(rawQuery);
      if (normalizedQuery.isEmpty) continue;

      // أ) مطابقة تامة مع اسم التصنيف (عربي أو إنجليزي)
      for (final c in candidates) {
        final normAr = normalizeArabic(c.nameAr);
        final normEn = c.nameEn.trim().toLowerCase();
        if (normAr == normalizedQuery || normEn == normalizedQuery) {
          return c;
        }
      }

      // ب) فحص الكلمات الفردية في الاستعلام عبر قاموس المرادفات
      final tokens = normalizedQuery.split(' ').where((t) => t.length > 1).toList();
      for (final token in tokens) {
        for (final entry in _synonyms.entries) {
          final synList = entry.value;
          if (synList.contains(token)) {
            final matchedCat = candidates.where((c) => c.id == entry.key).firstOrNull;
            if (matchedCat != null) return matchedCat;
          }
        }
      }

      // ج) فحص احتواء النص أو الكلمات (Substring & Token Matching)
      for (final c in candidates) {
        final normAr = normalizeArabic(c.nameAr);
        final normEn = c.nameEn.trim().toLowerCase();

        // احتواء جزئي كامل
        if (normAr.contains(normalizedQuery) ||
            normalizedQuery.contains(normAr) ||
            normEn.contains(normalizedQuery) ||
            normalizedQuery.contains(normEn)) {
          return c;
        }

        // تقاطع الكلمات (Token Overlap)
        final catTokens = normAr.split(' ').where((t) => t.length > 2);
        for (final catToken in catTokens) {
          if (tokens.contains(catToken)) {
            return c;
          }
        }
      }
    }

    // 4. البديل الذكي الآمن (Safe Fallback Category):
    // تجنب الإسناد العشوائي لأول تصنيف، وبدلاً من ذلك استخدام تصنيف "أخرى" إذا وجد
    final otherFallbackId = targetType == CategoryType.income ? 'cat_other_inc' : 'cat_other_exp';
    final otherCat = candidates.where((c) => c.id == otherFallbackId).firstOrNull;
    if (otherCat != null) return otherCat;

    // بحث عن تصنيف يحمل كلمة "أخرى" أو "other"
    final namedOther = candidates.where((c) {
      final n = normalizeArabic(c.nameAr);
      return n.contains('اخري') || c.nameEn.toLowerCase().contains('other');
    }).firstOrNull;
    if (namedOther != null) return namedOther;

    // الخيار الأخير: أول تصنيف في القائمة المرشحة
    return candidates.first;
  }
}
