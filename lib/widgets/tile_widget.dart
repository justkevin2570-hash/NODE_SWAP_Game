import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TileWidget extends StatelessWidget {
  final int value;
  final bool isSelected;
  final bool isHinted;
  final bool isWon;
  final VoidCallback onTap;

  const TileWidget({
    super.key,
    required this.value,
    required this.onTap,
    this.isSelected = false,
    this.isHinted = false,
    this.isWon = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color fillColor = value == 1
        ? const Color(0xFF1A237E)
        : const Color(0xFFE8EAF6);

    final Color borderColor = isSelected
        ? Colors.amber
        : isHinted
            ? Colors.greenAccent
            : value == 1
                ? const Color(0xFF3949AB)
                : const Color(0xFFBDBDBD);

    final double borderWidth = (isSelected || isHinted) ? 3.0 : 1.0;

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.all(3),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : isHinted
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ],
      ),
      child: Center(
        child: Icon(
          value == 1 ? Icons.circle : Icons.circle_outlined,
          color: value == 1
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.15),
          size: 18,
        ),
      ),
    );

    if (isHinted) {
      tile = Shimmer.fromColors(
        baseColor: fillColor,
        highlightColor: Colors.greenAccent.withValues(alpha: 0.8),
        child: tile,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: tile,
      ),
    );
  }
}
