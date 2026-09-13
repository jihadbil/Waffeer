import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String imagePath;
  final String? title;

  const ReceiptViewerDialog({super.key, required this.imagePath, this.title});

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title ?? 'فاتورة / إيصال',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (exists)
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () {
                Share.shareXFiles([XFile(imagePath)], text: title);
              },
            ),
        ],
      ),
      body: Center(
        child: exists
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(file, fit: BoxFit.contain),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'تعذر العثور على صورة الفاتورة',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
      ),
    );
  }
}
