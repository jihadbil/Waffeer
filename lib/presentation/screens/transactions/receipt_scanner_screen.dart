import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/currencies.dart';
import '../../../core/services/receipt_scanner_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/receipt_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/category_icon_widget.dart';
import '../../widgets/receipt_viewer_dialog.dart';
import 'add_edit_transaction_screen.dart';

/// شاشة مسح الفواتير والإيصالات الذكية ومراجعة البيانات المستخرجة
///
/// تتيح هذه الشاشة للمستخدم:
/// 1. التقاط صورة الفاتورة بالكاميرا أو اختيارها من المعرض.
/// 2. معالجة الفاتورة مع تأثير ليزر متحرك (Laser Scan Animation).
/// 3. مراجعة وتعديل البيانات المستخرجة (المبلغ، المتجر، التاريخ، التصنيف، المحفظة).
/// 4. استخدام البيانات في شاشة إضافة المعاملة أو الحفظ الفوري بنقرة واحدة.
class ReceiptScannerScreen extends StatefulWidget {
  /// ملف الصورة المبدئي في حال تم تمريره من شاشة أخرى
  final File? initialImageFile;

  const ReceiptScannerScreen({super.key, this.initialImageFile});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with SingleTickerProviderStateMixin {
  /// أداة التقاط واختيار الصور من الكاميرا والمعرض
  final ImagePicker _picker = ImagePicker();

  /// نسخة خدمة التعرف الضوئي على النصوص
  final ReceiptScannerService _scannerService = ReceiptScannerService.instance;

  /// ملف صورة الفاتورة المحددة حالياً
  File? _imageFile;

  /// حالة المعالجة الحالية (جاري المسح واستخراج البيانات)
  bool _isProcessing = false;

  /// نموذج بيانات الفاتورة بعد اكتمال التحليل
  ParsedReceipt? _parsedReceipt;

  // متحكمات حقول الإدخال القابلة للتعديل
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedWalletId;
  bool _showRawText = false;

  // أنيميشن خط الليزر الخاص بالمسح الضوئي
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _merchantController = TextEditingController();

    // إعداد متحكم حركة خط الليزر للمسح
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    // التهيئة بعد اكتمال بناء الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = context.read<WalletProvider>();
      if (walletProvider.wallets.isNotEmpty) {
        _selectedWalletId =
            walletProvider.defaultWallet?.id ?? walletProvider.wallets.first.id;
      }

      if (widget.initialImageFile != null) {
        _processImage(widget.initialImageFile!);
      } else {
        // عرض نافذة اختيار مصدر الصورة تلقائياً عند فتح الشاشة لأول مرة
        _showImageSourceDialog();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _laserAnimController.dispose();
    super.dispose();
  }

  /// عرض نافذة منبثقة سفلية للاختيار بين الكاميرا ومعرض الصور
  Future<void> _showImageSourceDialog() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر السحب
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isArabic ? 'مسح الفاتورة أو الإيصال' : 'Scan Receipt or Bill',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'اختر طريقة التقاط صورة الفاتورة للتعرف على البيانات آلياً'
                    : 'Choose how to capture your receipt for automatic data extraction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // خيار الكاميرا
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndScanImage(ImageSource.camera);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              color: AppColors.primary,
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isArabic ? 'التقاط بالكاميرا' : 'Camera',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // خيار معرض الصور
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndScanImage(ImageSource.gallery);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              color: AppColors.secondary,
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isArabic ? 'من المعرض' : 'Gallery',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }

  /// التقاط صورة أو اختيارها من المعرض وبدء عملية المعالجة الذكية
  Future<void> _pickAndScanImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90);
      if (picked != null) {
        final file = File(picked.path);
        await _processImage(file);
      }
    } catch (e) {
      if (mounted) {
        final isArabic = context.read<SettingsProvider>().isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تعذر فتح الكاميرا أو الصورة، يرجى المحاولة مجدداً'
                  : 'Unable to open camera or photo, please try again',
            ),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  /// معالجة صورة الفاتورة عبر محرك OCR وتحديث حقول النموذج
  Future<void> _processImage(File file) async {
    setState(() {
      _imageFile = file;
      _isProcessing = true;
      _parsedReceipt = null;
    });

    final settings = context.read<SettingsProvider>();
    final catProvider = context.read<CategoryProvider>();

    try {
      // استدعاء خدمة التعرف الضوئي (مع دعم Gemini Vision والتراجع لـ ML Kit)
      final parsed = await _scannerService.scanReceipt(
        file,
        apiKey: settings.isAiEnabled ? settings.aiApiKey : null,
        categories: catProvider.categories,
        isArabic: settings.isArabic,
      );

      if (!mounted) return;
      String? matchedCategoryId = parsed.suggestedCategoryId;

      // مطابقة التصنيف مع قائمة التصنيفات المسجلة في التطبيق
      if (matchedCategoryId != null) {
        final exists = catProvider.expenseCategories.any(
          (c) => c.id == matchedCategoryId,
        );
        if (!exists && catProvider.expenseCategories.isNotEmpty) {
          matchedCategoryId = catProvider.expenseCategories.first.id;
        }
      } else if (catProvider.expenseCategories.isNotEmpty) {
        matchedCategoryId = catProvider.expenseCategories.first.id;
      }

      setState(() {
        _parsedReceipt = parsed;
        _isProcessing = false;

        // تعبئة حقل المبلغ
        if (parsed.totalAmount != null) {
          _amountController.text = parsed.totalAmount!.toStringAsFixed(
            parsed.totalAmount! % 1 == 0 ? 0 : 2,
          );
        } else {
          _amountController.clear();
        }

        // تعبئة حقول المتجر والتاريخ والتصنيف
        _merchantController.text = parsed.merchantName ?? '';
        _selectedDate = parsed.dateTime ?? DateTime.now();
        _selectedCategoryId = matchedCategoryId;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        final isArabic = context.read<SettingsProvider>().isArabic;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'حدث خطأ أثناء قراءة الفاتورة، يمكنك إدخال البيانات يدوياً'
                  : 'Error parsing receipt, you can enter details manually',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }

  /// نقل البيانات المستخرجة إلى شاشة إضافة المعاملة المفصلة [AddEditTransactionScreen]
  Future<void> _useInAddTransaction() async {
    final amount = double.tryParse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    String? permanentReceiptPath;
    if (_imageFile != null) {
      permanentReceiptPath = await ReceiptScannerService.persistReceiptImage(_imageFile!.path);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(
          initialType: TransactionType.expense,
          initialAmount: amount,
          initialTitle: _merchantController.text.trim().isNotEmpty
              ? _merchantController.text.trim()
              : null,
          initialCategoryId: _selectedCategoryId,
          initialDate: _selectedDate,
          initialReceiptImagePath: permanentReceiptPath,
        ),
      ),
    );
  }

  /// الحفظ الفوري والسريع للمعاملة دون مغادرة الشاشة
  Future<void> _quickSaveTransaction() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يرجى إدخال المبلغ الإجمالي'
                : 'Please enter the total amount',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'المبلغ غير صالح' : 'Invalid amount'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (_selectedCategoryId == null || _selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يرجى اختيار المحفظة والتصنيف'
                : 'Please select wallet and category',
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final txProvider = context.read<TransactionProvider>();
    final walletProvider = context.read<WalletProvider>();

    try {
      // حفظ صورة الإيصال الدائمة في مجلد المستندات
      String? permanentReceiptPath;
      if (_imageFile != null) {
        permanentReceiptPath = await ReceiptScannerService.persistReceiptImage(_imageFile!.path);
      }

      // إضافة المعاملة في قاعدة البيانات
      await txProvider.addTransaction(
        amount: amount,
        type: TransactionType.expense,
        categoryId: _selectedCategoryId!,
        walletId: _selectedWalletId!,
        dateTime: _selectedDate,
        title: _merchantController.text.trim().isNotEmpty
            ? _merchantController.text.trim()
            : (isArabic ? 'فاتورة مشتريات' : 'Purchase Receipt'),
        receiptImagePath: permanentReceiptPath,
        currencyCode: settings.currencyCode,
      );

      // تحديث أرصدة المحافظ
      await walletProvider.loadWallets(settings.currencyCode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'تم حفظ المعاملة بنجاح بتاريخ ${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)} ✓'
                        : 'Transaction saved for ${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)} ✓',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'حدث خطأ أثناء الحفظ' : 'Error saving transaction',
            ),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catProvider = context.watch<CategoryProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final currencySymbol = Currencies.getByCode(settings.currencyCode).symbol;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.document_scanner_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isArabic ? 'مسح الفاتورة الذكي' : 'Smart Receipt Scanner',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            tooltip: isArabic ? 'صورة جديدة' : 'New Photo',
            onPressed: _showImageSourceDialog,
          ),
        ],
      ),
      body: _imageFile == null
          ? _buildEmptyState(isArabic, isDark)
          : _isProcessing
          ? _buildProcessingState(isArabic, isDark)
          : _buildResultView(
              isArabic,
              isDark,
              currencySymbol,
              catProvider,
              walletProvider,
            ),
    );
  }

  /// واجهة الحالة الأولية قبل التقاط أي صورة (ترحيبية وتوجيهية)
  Widget _buildEmptyState(bool isArabic, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.secondary.withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isArabic
                  ? 'المسح الضوئي الذكي للفواتير'
                  : 'Smart AI Receipt Scanner',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isArabic
                  ? 'التقط صورة للفاتورة أو الإيصال، وسيقوم وفير باستخراج المبلغ واسم المتجر والتاريخ والتصنيف تلقائياً وبدقة عالية.'
                  : 'Snap a photo of your receipt and Waffeer will automatically extract total amount, merchant, date, and category with high accuracy.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            // زر الكاميرا
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _pickAndScanImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(
                  isArabic ? 'التقاط صورة بالكاميرا' : 'Take Photo with Camera',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // زر المعرض
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _pickAndScanImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(
                  isArabic
                      ? 'اختيار من معرض الصور'
                      : 'Choose from Photo Gallery',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// واجهة حالة المعالجة مع أنيميشن ليزر المسح الضوئي
  Widget _buildProcessingState(bool isArabic, bool isDark) {
    return Stack(
      children: [
        // خلفية الصورة الملتقطة
        if (_imageFile != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.35,
              child: Image.file(_imageFile!, fit: BoxFit.cover),
            ),
          ),
        Container(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
        ),
        // خط الليزر المتحرك أعلى وأسفل الفاتورة
        AnimatedBuilder(
          animation: _laserAnimation,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * _laserAnimation.value,
              left: 20,
              right: 20,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  boxShadow: const [],
                ),
              ),
            );
          },
        ),
        // بطاقة تنبيه المعالجة
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic
                      ? 'جاري قراءة الفاتورة الذكية...'
                      : 'Analyzing Receipt with AI...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isArabic
                      ? 'استخراج المجموع، المتجر، التاريخ والتصنيف'
                      : 'Extracting total amount, merchant, date & category',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// واجهة مراجعة وتعديل النتائج بعد اكتمال استخراج البيانات
  Widget _buildResultView(
    bool isArabic,
    bool isDark,
    String currencySymbol,
    CategoryProvider catProvider,
    WalletProvider walletProvider,
  ) {
    final hasAmount = _parsedReceipt?.hasExtractedAmount ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. بطاقة معاينة صورة الفاتورة ومؤشر دقة التعرف
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : const Color(0xFFF5F8F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                // صورة الفاتورة المصغرة قابلة للنقر للتكبير
                GestureDetector(
                  onTap: () {
                    if (_imageFile != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReceiptViewerDialog(
                            imagePath: _imageFile!.path,
                            title: _merchantController.text.isNotEmpty
                                ? _merchantController.text
                                : (isArabic
                                      ? 'صورة الفاتورة'
                                      : 'Receipt Image'),
                          ),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // شارة حالة التعرف
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: hasAmount
                                  ? AppColors.income.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasAmount
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  size: 14,
                                  color: hasAmount
                                      ? AppColors.income
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasAmount
                                      ? (isArabic
                                            ? 'تم التعرف بنجاح'
                                            : 'Recognized')
                                      : (isArabic
                                            ? 'يرجى مراجعة المبلغ'
                                            : 'Check Amount'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hasAmount
                                        ? AppColors.income
                                        : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isArabic
                            ? 'انقر على الصورة للتكبير والمعاينة'
                            : 'Tap photo to zoom and inspect',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                // زر إعادة المسح
                IconButton.outlined(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: isArabic ? 'إعادة المسح' : 'Rescan',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. بطاقة المبلغ الإجمالي المستخرج (بارزة وقابلة للتعديل)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.expense.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isArabic
                          ? 'المبلغ الإجمالي المستخرج'
                          : 'Extracted Total Amount',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.expense,
                      ),
                    ),
                    if (_parsedReceipt?.taxAmount != null)
                      Text(
                        '${isArabic ? 'الضريبة:' : 'VAT:'} ${_parsedReceipt!.taxAmount!.toStringAsFixed(2)} $currencySymbol',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      currencySymbol,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.expense,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintStyle: TextStyle(
                            color: AppColors.expense.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. حقل اسم المتجر أو الوصف
          Text(
            isArabic ? 'اسم المتجر أو الوصف' : 'Merchant / Description',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _merchantController,
            decoration: InputDecoration(
              hintText: isArabic ? 'مثال: أسواق كارفور' : 'e.g. Starbucks',
              prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
              suffixIcon: _merchantController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () =>
                          setState(() => _merchantController.clear()),
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),

          // 4. تاريخ ووقت الفاتورة
          Text(
            isArabic ? 'تاريخ الفاتورة' : 'Receipt Date & Time',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (pickedDate != null && mounted) {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_selectedDate),
                );
                if (mounted) {
                  setState(() {
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime?.hour ?? _selectedDate.hour,
                      pickedTime?.minute ?? _selectedDate.minute,
                    );
                  });
                }
              }
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)}  •  ${DateFormatter.formatTime(_selectedDate, isArabic: isArabic)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (DateTime.now().difference(_selectedDate).inDays.abs() > 30)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'تاريخ الفاتورة قديم (${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)}). ستُسجل المعاملة في ذلك الشهر.'
                          : 'Receipt date is old (${DateFormatter.formatShort(_selectedDate, isArabic: isArabic)}). Will be booked under that month.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selectedDate = DateTime.now()),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isArabic ? 'استخدم اليوم' : 'Use Today',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),

          // 5. قائمة اختيار التصنيف المقترح
          Text(
            isArabic ? 'التصنيف المقترح' : 'Suggested Category',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategoryId,
            items: catProvider.expenseCategories.map((cat) {
              return DropdownMenuItem(
                value: cat.id,
                child: Row(
                  children: [
                    CategoryIconWidget(
                      iconData: cat.iconData,
                      color: cat.color,
                      size: 28,
                      iconSize: 16,
                    ),
                    const SizedBox(width: 10),
                    Text(cat.localizedName(isArabic)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedCategoryId = val),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 6. قائمة اختيار محفظة الدفع للحفظ السريع
          Text(
            isArabic ? 'المحفظة / الحساب للدفع' : 'Payment Wallet',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedWalletId,
            items: walletProvider.wallets.map((w) {
              return DropdownMenuItem(
                value: w.id,
                child: Row(
                  children: [
                    Icon(w.iconData, color: w.color, size: 20),
                    const SizedBox(width: 10),
                    Text(w.localizedName(isArabic)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedWalletId = val),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 7. البنود الفردية المكتشفة في الفاتورة (إن وجدت)
          if (_parsedReceipt?.lineItems.isNotEmpty ?? false) ...[
            Text(
              isArabic ? 'البنود المكتشفة في الفاتورة' : 'Detected Line Items',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : const Color(0xFFF5F8F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _parsedReceipt!.lineItems.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                itemBuilder: (ctx, idx) {
                  final item = _parsedReceipt!.lineItems[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${item.price.toStringAsFixed(2)} $currencySymbol',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 8. النص الخام المقروء بالكامل (قابلة للتوسيع والطي مع زر نسخ)
          if (_parsedReceipt?.rawText.isNotEmpty ?? false) ...[
            InkWell(
              onTap: () => setState(() => _showRawText = !_showRawText),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkCard : const Color(0xFFEAF1ED))
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isArabic
                          ? 'النص المقروء بالكامل (OCR)'
                          : 'Full Scanned Text (OCR)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showRawText
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            if (_showRawText) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF163C30)
                      : const Color(0xFFF5F8F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic
                              ? 'نص الفاتورة المستخرج:'
                              : 'Extracted Text:',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _parsedReceipt!.rawText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic ? 'تم نسخ النص ✓' : 'Text copied ✓',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _parsedReceipt!.rawText,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],

          // 9. أزرار الإجراءات (تعبئة المعاملة / الحفظ الفوري)
          Row(
            children: [
              // زر تعبئة شاشة المعاملة
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _useInAddTransaction,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(
                      isArabic ? 'تعبئة المعاملة' : 'Fill Transaction',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // زر الحفظ الفوري المباشر
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _quickSaveTransaction,
                    icon: const Icon(
                      Icons.flash_on_rounded,
                      color: AppColors.income,
                      size: 18,
                    ),
                    label: Text(
                      isArabic ? 'حفظ فوري' : 'Quick Save',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.income,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.income,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
