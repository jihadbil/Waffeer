import 'package:flutter/material.dart';

/// ويدجت أيقونة التصنيف بتصميم عصري ذي زوايا انسيابية وتدرج ناعم
class CategoryIconWidget extends StatelessWidget {
  final IconData iconData;
  final Color color;
  final double size;
  final double iconSize;

  const CategoryIconWidget({
    super.key,
    required this.iconData,
    required this.color,
    this.size = 48,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.22 : 0.16),
            color.withValues(alpha: isDark ? 0.10 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(iconData, color: color, size: iconSize),
      ),
    );
  }
}
