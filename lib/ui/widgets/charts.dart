import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../logic/budget_math.dart';
import '../../logic/money.dart';
import '../theme.dart';
import 'common.dart';

/// Month progress bar with a tick showing where even spending would be.
class MonthBar extends StatelessWidget {
  const MonthBar({
    super.key,
    required this.spentFraction,
    required this.paceFraction,
    required this.fillColor,
    required this.trackColor,
    required this.edgeColor,
    required this.semanticsLabel,
  });

  final double spentFraction;
  final double paceFraction;
  final Color fillColor;
  final Color trackColor;

  /// Colour of the outline around the tick; the surface the bar sits on.
  final Color edgeColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final fill = spentFraction.clamp(0.0, 1.0);
    final pace = paceFraction.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 28,
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              const tickWidth = 4.0;
              final tickLeft = (width * pace - tickWidth / 2).clamp(
                0.0,
                width - tickWidth,
              );
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: fill),
                    duration: motion(context, 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Container(
                      height: 14,
                      width: width * value,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                  Positioned(
                    left: tickLeft,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: tickWidth,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: edgeColor, width: 1.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A plain progress bar used for budgets and top categories.
class SimpleBar extends StatelessWidget {
  const SimpleBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.trackColor,
    this.height = 10,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Container(
              height: height,
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: f),
              duration: motion(context, 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Container(
                height: height,
                width: box.maxWidth * value,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonutSlice {
  const DonutSlice(this.value, this.color);
  final double value;
  final Color color;
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.trackColor,
    required this.center,
    required this.semanticsLabel,
    this.size = 190,
  });

  final List<DonutSlice> slices;
  final Color trackColor;
  final Widget center;
  final String semanticsLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                size: Size(size, size),
                painter: _DonutPainter(slices, trackColor),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.2),
              child: ExcludeSemantics(child: Center(child: center)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.trackColor);

  final List<DonutSlice> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.14;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    paint.color = trackColor;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, paint);

    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    final gap = slices.length > 1 ? 0.045 : 0.0;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * math.pi * 2;
      paint.color = s.color;
      canvas.drawArc(
        arcRect,
        start + gap / 2,
        math.max(0.0, sweep - gap),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.trackColor != trackColor || !_sameSlices(old.slices, slices);

  static bool _sameSlices(List<DonutSlice> a, List<DonutSlice> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].color != b[i].color) return false;
    }
    return true;
  }
}

/// Seven bars, one per day. Tap a bar to read its amount.
class WeekBars extends StatefulWidget {
  const WeekBars({super.key, required this.days, required this.format});

  final List<DayTotal> days;
  final String Function(int cents) format;

  @override
  State<WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<WeekBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final days = widget.days;
    final selected = _selected ?? days.length - 1;
    final peak = days.fold<int>(0, (m, d) => math.max(m, d.cents));
    const chartHeight = 120.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              label:
                  '${weekdayShort[days[i].day.weekday - 1]}, ${widget.format(days[i].cents)} spent',
              excludeSemantics: true,
              onTap: () => setState(() => _selected = i),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selected = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 22,
                        child: i == selected
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.format(days[i].cents),
                                  style: text.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(
                        height: chartHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              end: peak == 0
                                  ? 6.0
                                  : math.max(
                                      6.0,
                                      chartHeight * days[i].cents / peak,
                                    ),
                            ),
                            duration: motion(context, 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, h, _) => Container(
                              height: h,
                              decoration: BoxDecoration(
                                color: i == selected
                                    ? cs.primary
                                    : cs.primary.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weekdayShort[days[i].day.weekday - 1].substring(0, 1),
                        style: text.labelLarge?.copyWith(
                          color: i == selected
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
