import 'package:flutter/material.dart';
import '../models/board_model.dart';

class SymmetryAxisOverlay extends StatelessWidget {
  final SymmetryType type;
  final bool achieved;
  final double boardSize;

  const SymmetryAxisOverlay({
    super.key,
    required this.type,
    required this.achieved,
    required this.boardSize,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: achieved ? 0.0 : 0.4,
        duration: const Duration(milliseconds: 400),
        child: CustomPaint(
          size: Size(boardSize, boardSize),
          painter: _AxisPainter(type: type),
        ),
      ),
    );
  }
}

class _AxisPainter extends CustomPainter {
  final SymmetryType type;

  _AxisPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashLength = 6.0;
    const gapLength = 4.0;

    switch (type) {
      case SymmetryType.horizontal: // 세로 중앙선
        _drawDashedLine(
          canvas,
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          paint,
          dashLength,
          gapLength,
        );
      case SymmetryType.vertical: // 가로 중앙선
        _drawDashedLine(
          canvas,
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          paint,
          dashLength,
          gapLength,
        );
      case SymmetryType.pointSymmetry: // 중심점 마커
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(center, 6, paint..style = PaintingStyle.fill);
        canvas.drawCircle(center, 12, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double drawn = 0;

    while (drawn < totalLength) {
      final segEnd = drawn + dashLen;
      canvas.drawLine(
        start + direction * drawn,
        start + direction * (segEnd.clamp(0, totalLength)),
        paint,
      );
      drawn += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_AxisPainter oldDelegate) => oldDelegate.type != type;
}

class SymmetryStatusBadge extends StatelessWidget {
  final bool achieved;
  final SymmetryType type;

  const SymmetryStatusBadge({
    super.key,
    required this.achieved,
    required this.type,
  });

  String get _label {
    switch (type) {
      case SymmetryType.horizontal:
        return '좌우 대칭';
      case SymmetryType.vertical:
        return '상하 대칭';
      case SymmetryType.pointSymmetry:
        return '점대칭';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: achieved ? Colors.green.shade600 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
        boxShadow: achieved
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            achieved ? Icons.check_circle : Icons.radio_button_unchecked,
            color: achieved ? Colors.white : Colors.grey.shade600,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            achieved ? '$_label 달성!' : '$_label 만들기',
            style: TextStyle(
              color: achieved ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
