import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

class BackupService {
  /// Exports full database to JSON file and opens share sheet
  static Future<BackupResult> createAndShareBackup(bool isArabic) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final fullData = await dbHelper.exportFullDatabase();

      final jsonString = const JsonEncoder.withIndent('  ').convert(fullData);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'Waffeer_Backup_$timestamp.wafbackup';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: isArabic
            ? 'نسخة احتياطية لتطبيق وفير'
            : 'Waffeer Finance App Backup',
      );

      return BackupResult(
        success: true,
        message: isArabic
            ? 'تم إنشاء النسخة الاحتياطية بنجاح'
            : 'Backup created successfully',
        filePath: file.path,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: isArabic
            ? 'فشل إنشاء النسخة الاحتياطية: $e'
            : 'Failed to create backup: $e',
      );
    }
  }

  /// Picks a backup file and restores database
  static Future<BackupResult> restoreFromBackupFile(bool isArabic) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wafbackup', 'json'],
      );

      if (result == null || result.files.single.path == null) {
        return BackupResult(
          success: false,
          message: isArabic ? 'لم يتم اختيار أي ملف' : 'No file selected',
        );
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString(encoding: utf8);
      final Map<String, dynamic> backupData = jsonDecode(content);

      if (backupData['app'] != 'Waffeer' || backupData['data'] == null) {
        return BackupResult(
          success: false,
          message: isArabic
              ? 'ملف النسخة الاحتياطية غير صالح أو تالف'
              : 'Invalid or corrupted backup file',
        );
      }

      final success = await DatabaseHelper.instance.importFullDatabase(
        backupData,
      );

      if (success) {
        return BackupResult(
          success: true,
          message: isArabic
              ? 'تمت استعادة البيانات بنجاح!'
              : 'Data restored successfully!',
        );
      } else {
        return BackupResult(
          success: false,
          message: isArabic
              ? 'فشل استيراد البيانات إلى قاعدة البيانات'
              : 'Failed to import data into database',
        );
      }
    } catch (e) {
      return BackupResult(
        success: false,
        message: isArabic
            ? 'حدث خطأ أثناء الاستعادة: $e'
            : 'Error during restore: $e',
      );
    }
  }
}
