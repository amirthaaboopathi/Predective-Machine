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

/// A high-performance, interactive sensor trend chart with smooth curves,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final selectedPoint = _selectedIndex != null && _selectedIndex! < widget.points.length
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
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${selectedPoint.value} ${widget.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFullTime(selectedPoint.timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
            ],

            // Canvas Chart
            GestureDetector(
              onPanUpdate: (details) => _handleTouch(details.localPosition.dx, width),
              onPanDown: (details) => _handleTouch(details.localPosition.dx, width),
              onPanEnd: (_) => setState(() => _selectedIndex = null),
              onPanCancel: () => setState(() => _selectedIndex = null),
              child: SizedBox(
                width: width,
                height: widget.height,
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
    if (widget.points.length < 2) return;
    const leftPadding = 36.0;
    const rightPadding = 16.0;
    final chartWidth = totalWidth - leftPadding - rightPadding;
    if (chartWidth <= 0) return;

    final clampedX = (localX - leftPadding).clamp(0.0, chartWidth);
    final ratio = clampedX / chartWidth;
    final index = (ratio * (widget.points.length - 1)).round();

    setState(() {
      _selectedIndex = index.clamp(0, widget.points.length - 1);
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

    // Calculate Min & Max for scaling
    double minY = points.map((p) => p.value).reduce(min);
    double maxY = points.map((p) => p.value).reduce(max);
    if (threshold != null) {
      minY = min(minY, threshold!);
      maxY = max(maxY, threshold!);
    }

    // Add padding to Y range
    final rangeY = (maxY - minY == 0) ? 1.0 : (maxY - minY);
    minY = (minY - rangeY * 0.15).clamp(0.0, double.infinity);
    maxY = maxY + rangeY * 0.15;
    final totalRange = maxY - minY;

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
      final threshY = topMargin + chartHeight * (1.0 - (threshold! - minY) / totalRange);
      final threshPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Draw dashed line
      double startX = leftMargin;
      while (startX < leftMargin + chartWidth) {
        canvas.drawLine(
          Offset(startX, threshY),
          Offset(min(startX + 6, leftMargin + chartWidth), threshY),
          threshPaint,
        );
        startX += 10;
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

    // Gradient fill under the curve
    final path = Path();
    path.moveTo(offsets.first.dx, leftMargin + chartHeight);
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

    // Touch Selection Highlight
    if (selectedIndex != null && selectedIndex! < offsets.length) {
      final selectedOffset = offsets[selectedIndex!];

      // Vertical guide line
      final guidePaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(selectedOffset.dx, topMargin),
        Offset(selectedOffset.dx, topMargin + chartHeight),
        guidePaint,
      );

      // Outer halo
      canvas.drawCircle(
        selectedOffset,
        7,
        Paint()..color = color.withValues(alpha: 0.3),
      );
      // Inner solid point
      canvas.drawCircle(
        selectedOffset,
        4,
        Paint()..color = color,
      );
    }

    // X-Axis Time Labels (Start & End)
    if (points.isNotEmpty) {
      final startTimeStr = _formatShortTime(points.first.timestamp);
      final endTimeStr = _formatShortTime(points.last.timestamp);

      final startPainter = TextPainter(
        text: TextSpan(text: startTimeStr, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      startPainter.paint(canvas, Offset(leftMargin, topMargin + chartHeight + 6));

      final endPainter = TextPainter(
        text: TextSpan(text: endTimeStr, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      endPainter.paint(
        canvas,
        Offset(leftMargin + chartWidth - endPainter.width, topMargin + chartHeight + 6),
      );
    }
  }

  String _formatShortTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color;
  }
}
