import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ChartDataPoint {
  final DateTime timestamp;
  final double value;

  const ChartDataPoint({
    required this.timestamp,
    required this.value,
  });
}

/// A high-performance, robust, interactive sensor trend chart with smooth curves,
/// gradient fill, threshold baseline, and touch tooltips.
class InteractiveSensorChart extends StatefulWidget {
  final List<ChartDataPoint> points;
  final String unit;
  final Color primaryColor;
  final double? thresholdValue;
  final String? thresholdLabel;
  final double height;

  const InteractiveSensorChart({
    super.key,
    required this.points,
    required this.unit,
    required this.primaryColor,
    this.thresholdValue,
    this.thresholdLabel,
    this.height = 200,
  });

  @override
  State<InteractiveSensorChart> createState() => _InteractiveSensorChartState();
}

class _InteractiveSensorChartState extends State<InteractiveSensorChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 36, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No telemetry recorded for this timeframe',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Safety: ensure selected index is valid
    if (_selectedIndex != null &&
        (_selectedIndex! < 0 || _selectedIndex! >= widget.points.length)) {
      _selectedIndex = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final selectedPoint = _selectedIndex != null &&
                _selectedIndex! < widget.points.length
            ? widget.points[_selectedIndex!]
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tooltip header on touch
            if (selectedPoint != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${selectedPoint.value.toStringAsFixed(1)} ${widget.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFullTime(selectedPoint.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 28),
            ],

            // Chart Canvas
            GestureDetector(
              onHorizontalDragStart: (details) =>
                  _handleTouch(details.localPosition.dx, width),
              onHorizontalDragUpdate: (details) =>
                  _handleTouch(details.localPosition.dx, width),
              onHorizontalDragEnd: (_) => setState(() => _selectedIndex = null),
              onTapDown: (details) =>
                  _handleTouch(details.localPosition.dx, width),
              onTapUp: (_) => setState(() => _selectedIndex = null),
              child: SizedBox(
                height: widget.height,
                width: width,
                child: CustomPaint(
                  painter: _ChartPainter(
                    points: widget.points,
                    unit: widget.unit,
                    color: widget.primaryColor,
                    threshold: widget.thresholdValue,
                    thresholdLabel: widget.thresholdLabel,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleTouch(double localX, double totalWidth) {
    if (widget.points.isEmpty) return;

    const leftPadding = 36.0;
    const rightPadding = 16.0;
    final chartWidth = totalWidth - leftPadding - rightPadding;
    if (chartWidth <= 0) return;

    final clampedX = (localX - leftPadding).clamp(0.0, chartWidth);
    final ratio = clampedX / chartWidth;
    final maxIdx = widget.points.length - 1;
    final index = maxIdx <= 0 ? 0 : (ratio * maxIdx).round().clamp(0, maxIdx);

    setState(() {
      _selectedIndex = index;
    });
  }

  String _formatFullTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;
  final String unit;
  final Color color;
  final double? threshold;
  final String? thresholdLabel;
  final int? selectedIndex;

  _ChartPainter({
    required this.points,
    required this.unit,
    required this.color,
    this.threshold,
    this.thresholdLabel,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 36.0;
    const rightMargin = 16.0;
    const topMargin = 16.0;
    const bottomMargin = 24.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (points.isEmpty || chartWidth <= 0 || chartHeight <= 0) return;

    // Calculate Min & Max for scaling safely
    double rawMin = points.first.value;
    double rawMax = points.first.value;
    for (final p in points) {
      if (p.value < rawMin) rawMin = p.value;
      if (p.value > rawMax) rawMax = p.value;
    }

    if (threshold != null) {
      rawMin = min(rawMin, threshold!);
      rawMax = max(rawMax, threshold!);
    }

    double diff = rawMax - rawMin;
    if (diff.abs() < 0.001) {
      diff = 1.0;
    }

    double minY = rawMin - diff * 0.15;
    double maxY = rawMax + diff * 0.15;
    final totalRange = (maxY - minY <= 0) ? 1.0 : (maxY - minY);

    // Grid Lines & Labels
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      fontSize: 10,
      color: Colors.grey[500],
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i <= 3; i++) {
      final yNorm = i / 3.0;
      final yPos = topMargin + chartHeight * (1.0 - yNorm);
      final valueLabel = (minY + totalRange * yNorm).toStringAsFixed(1);

      canvas.drawLine(
        Offset(leftMargin, yPos),
        Offset(leftMargin + chartWidth, yPos),
        gridPaint,
      );

      final textSpan = TextSpan(text: valueLabel, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, yPos - 6));
    }

    // Threshold Reference Line
    if (threshold != null && threshold! >= minY && threshold! <= maxY) {
      final threshY = (topMargin + chartHeight * (1.0 - (threshold! - minY) / totalRange)).clamp(topMargin, topMargin + chartHeight);
      final threshPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      double startX = leftMargin;
      while (startX < leftMargin + chartWidth) {
        canvas.drawLine(
          Offset(startX, threshY),
          Offset(min(startX + 6, leftMargin + chartWidth), threshY),
          threshPaint,
        );
        startX += 10;
      }

      if (thresholdLabel != null && thresholdLabel!.isNotEmpty) {
        final labelSpan = TextSpan(
          text: thresholdLabel!,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        );
        final labelPainter = TextPainter(
          text: labelSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(canvas, Offset(leftMargin + 6, threshY - 12));
      }
    }

    // Coordinates mapping
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final xNorm = points.length == 1 ? 0.5 : (i / (points.length - 1));
      final xPos = leftMargin + chartWidth * xNorm;
      final yNorm = ((points[i].value - minY) / totalRange).clamp(0.0, 1.0);
      final yPos = topMargin + chartHeight * (1.0 - yNorm);
      offsets.add(Offset(xPos, yPos));
    }

    // Single point fallback rendering
    if (offsets.length == 1) {
      final pt = offsets.first;
      final circlePaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pt, 5, circlePaint);
      canvas.drawCircle(pt, 9, Paint()..color = color.withValues(alpha: 0.25)..style = PaintingStyle.fill);
    } else {
      // Gradient fill under the curve
      final path = Path();
      path.moveTo(offsets.first.dx, topMargin + chartHeight);
      path.lineTo(offsets.first.dx, offsets.first.dy);

      for (int i = 0; i < offsets.length - 1; i++) {
        final p0 = offsets[i];
        final p1 = offsets[i + 1];
        final cx = (p0.dx + p1.dx) / 2;
        path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }
      path.lineTo(offsets.last.dx, topMargin + chartHeight);
      path.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(leftMargin, topMargin, chartWidth, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, fillPaint);

      // Stroke line
      final strokePath = Path();
      strokePath.moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 0; i < offsets.length - 1; i++) {
        final p0 = offsets[i];
        final p1 = offsets[i + 1];
        final cx = (p0.dx + p1.dx) / 2;
        strokePath.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }

      final strokePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(strokePath, strokePaint);
    }

    // Touch Selection Highlight
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < offsets.length) {
      final selectedOffset = offsets[selectedIndex!];

      // Vertical guide line
      final guidePaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(selectedOffset.dx, topMargin),
        Offset(selectedOffset.dx, topMargin + chartHeight),
        guidePaint,
      );

      // Outer halo & center point
      canvas.drawCircle(
        selectedOffset,
        6,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        selectedOffset,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        selectedOffset,
        2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }

    // X-Axis Timestamp Labels (First, Middle, Last)
    if (points.isNotEmpty) {
      _drawTimestamp(canvas, points.first.timestamp, leftMargin, topMargin + chartHeight + 6, TextAlign.left);
      if (points.length > 2) {
        final midIdx = points.length ~/ 2;
        final midX = leftMargin + chartWidth * 0.5;
        _drawTimestamp(canvas, points[midIdx].timestamp, midX, topMargin + chartHeight + 6, TextAlign.center);
      }
      if (points.length > 1) {
        _drawTimestamp(canvas, points.last.timestamp, leftMargin + chartWidth, topMargin + chartHeight + 6, TextAlign.right);
      }
    }
  }

  void _drawTimestamp(Canvas canvas, DateTime dt, double x, double y, TextAlign align) {
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final span = TextSpan(
      text: timeStr,
      style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500),
    );
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();

    double offsetX = x;
    if (align == TextAlign.center) {
      offsetX = x - painter.width / 2;
    } else if (align == TextAlign.right) {
      offsetX = x - painter.width;
    }

    painter.paint(canvas, Offset(offsetX, y));
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color;
  }
}
