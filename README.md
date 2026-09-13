# وفير — Waffeer

تطبيق إدارة مالية شخصية يعمل محلياً ويدعم العربية والإنجليزية. يساعد على تسجيل المعاملات بسرعة، متابعة الميزانيات، تخطيط الادخار، ومراجعة المصروفات دون الحاجة إلى إنشاء حساب.

## التصميم والمعاملات المتكررة

- ثيم أخضر موحّد للشاشات، مع وضع داكن وخط Cairo مضمّن محلياً في `assets/fonts` وترخيصه OFL.
- المعاملة المتكررة تدعم المصروف والدخل والتكرار السنوي: تسجيل عند الضغط، تذكير ينتظر التأكيد، أو تسجيل تلقائي.
- التسجيل التلقائي يعالج الاستحقاقات عند بدء التطبيق واستئنافه، وكل دقيقة أثناء الاستخدام. لا ينفذ خصماً في الخلفية والتطبيق مغلق؛ تُستكمل المواعيد الفائتة عند فتحه.
- الإيقاف المؤقت يتجاوز فترة التوقف عند الاستئناف. إلغاء قيد تلقائي يحفظ علامة تمنع إعادة إنشائه تلقائياً.
- قاعدة البيانات بالإصدار 4 ترحّل الجداول القديمة إلى النظام الموحد بوضع التذكير، وتحافظ على المعاملات والأرصدة. النسخ الاحتياطية تشمل القوالب وسجل تنفيذها.

التحقق: `flutter analyze` و`flutter test`. اختبارات `test/routine_database_test.dart` تستخدم قاعدة SQLite معزولة، وتغطي الترحيل والتزامن والتراجع والفشل الجزئي. اختبارات `test/app_design_test.dart` تفحص الشاشات بالعربية في الوضعين الفاتح والداكن وتحفظ صور المعاينة في `build/ui_previews`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
