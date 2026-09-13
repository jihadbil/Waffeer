import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/settings_provider.dart';

/// شاشة إدارة وإعدادات الذكاء الاصطناعي ومفتاح Google Gemini API
class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late TextEditingController _keyController;
  bool _obscureKey = true;
  bool? _testResult;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _keyController = TextEditingController(text: settings.aiApiKey);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _testKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _testResult = false;
        _testMessage = 'يرجى إدخال مفتاح الـ API أولاً.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    final ai = context.read<AiProvider>();
    final isArabic = context.read<SettingsProvider>().isArabic;

    final success = await ai.testKey(key);
    if (!mounted) return;

    setState(() {
      _testResult = success;
      if (success) {
        _testMessage = isArabic
            ? '✅ تم الاتصال بنجاح! المفتاح فعال ونموذج Gemini جاهز للاستخدام.'
            : '✅ Connection successful! Gemini model is ready to use.';
      } else {
        _testMessage = isArabic
            ? '❌ فشل الاتصال. تأكد من صحة المفتاح واتصالك بالإنترنت. يمكنك الحصول على مفتاح صالح مجاناً من Google AI Studio.'
            : '❌ Connection failed. Check key validity and internet connection.';
      }
    });
  }

  Future<void> _saveSettings() async {
    final settings = context.read<SettingsProvider>();
    final isArabic = settings.isArabic;
    final key = _keyController.text.trim();

    await settings.setAiApiKey(key);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(
          isArabic ? 'تم حفظ إعدادات الذكاء الاصطناعي بنجاح' : 'AI settings saved successfully',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ai = context.watch<AiProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'إعدادات الذكاء الاصطناعي' : 'AI Settings',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          // 1. بطاقة تفعيل الذكاء الاصطناعي
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'تفعيل الذكاء الاصطناعي' : 'Enable AI Features',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        isArabic
                            ? 'يشمل المستشار المالي، قراءة الفواتير، والتسجيل السريع'
                            : 'Includes Advisor, OCR Vision, and Smart Logger',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: settings.isAiEnabled,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) => settings.setAiEnabled(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. إدخال مفتاح API
          Text(
            isArabic ? 'مفتاح Google Gemini API' : 'Google Gemini API Key',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: TextField(
              controller: _keyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'AQ... أو AIzaSy...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded),
                      tooltip: isArabic ? 'لصق من الحافظة' : 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setState(() {
                            _keyController.text = data!.text!.trim();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. أزرار الفحص والحفظ
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ai.isTestingKey ? null : _testKey,
                  icon: ai.isTestingKey
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: Text(isArabic ? 'اختبار الاتصال' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(isArabic ? 'حفظ المفتاح' : 'Save Key'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),

          // نتيجة الفحص
          if (_testMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_testResult == true)
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_testResult == true) ? AppColors.primary : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (_testResult == true) ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: (_testResult == true) ? AppColors.primary : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _testMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: (_testResult == true) ? AppColors.primary : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 4. بطاقة التوجيه للحصول على مفتاح مجاني
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  Colors.blue.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'كيف تحصل على مفتاح API مجاني؟' : 'How to get a free API Key?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isArabic
                      ? '1. افتح موقع Google AI Studio:\n   aistudio.google.com/app/apikey\n2. سجل الدخول بحساب Google الخاص بك.\n3. اضغط على "Create API Key".\n4. انسخ المفتاح والصقه هنا في التطبيق.'
                      : '1. Visit Google AI Studio:\n   aistudio.google.com/app/apikey\n2. Sign in with Google.\n3. Click "Create API Key".\n4. Copy and paste it here.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. بطاقة الخصوصية والأمان
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard.withValues(alpha: 0.5) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.teal, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'الخصوصية أولاً: بياناتك المالية مشفرة وتُعالج بأرقام مجردة بدون أي معلومات شخصية أو هوية بنكية.'
                        : 'Privacy First: Financial data is fully anonymized without any personal or banking credentials.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
