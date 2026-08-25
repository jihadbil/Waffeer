import 'package:flutter/material.dart';

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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: color,
          size: iconSize,
        ),
      ),
    );
  }
}
