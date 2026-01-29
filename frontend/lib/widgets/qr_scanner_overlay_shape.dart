import 'package:flutter/material.dart';

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _cutOutSize = cutOutSize;
    final _cutOutBottomOffset = cutOutBottomOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top +
          height / 2 -
          _cutOutSize / 2 +
          _cutOutBottomOffset +
          borderOffset,
      _cutOutSize - borderOffset * 2,
      _cutOutSize - borderOffset * 2,
    );

    canvas.saveLayer(rect, backgroundPaint);

    canvas.drawRect(rect, backgroundPaint);

    // Draw cut out
    final cutOutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      );

    canvas.drawPath(cutOutPath, Paint()..blendMode = BlendMode.clear);

    canvas.restore();

    final r = borderRadius;
    final d = borderLength;
    final l = cutOutRect.left;
    final t = cutOutRect.top;
    final rRight = cutOutRect.right;
    final b = cutOutRect.bottom;

    // Top left
    final path = Path()
      ..moveTo(l, t + d)
      ..lineTo(l, t + r)
      ..arcToPoint(Offset(l + r, t), radius: Radius.circular(r))
      ..lineTo(l + d, t);

    // Top right
    path
      ..moveTo(rRight - d, t)
      ..lineTo(rRight - r, t)
      ..arcToPoint(Offset(rRight, t + r), radius: Radius.circular(r))
      ..lineTo(rRight, t + d);

    // Bottom right
    path
      ..moveTo(rRight, b - d)
      ..lineTo(rRight, b - r)
      ..arcToPoint(Offset(rRight - r, b), radius: Radius.circular(r))
      ..lineTo(rRight - d, b);

    // Bottom left
    path
      ..moveTo(l + d, b)
      ..lineTo(l + r, b)
      ..arcToPoint(Offset(l, b - r), radius: Radius.circular(r))
      ..lineTo(l, b - d);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
      cutOutBottomOffset: cutOutBottomOffset * t,
    );
  }
}
