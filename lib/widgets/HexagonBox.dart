// ignore_for_file: file_names
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ThemeColor.dart';
import '../provider/HexagonProvider.dart';

/// A single hexagon cell in the Slitherlink hexagonal grid.
/// 6 edges: 0=top, 1=topRight, 2=bottomRight, 3=bottom, 4=bottomLeft, 5=topLeft
// ignore: must_be_immutable
class HexagonBox extends StatefulWidget {
  final int row;
  final int col;

  /// Edge values: 0=normal, 1+=selected, -1=disable, -3=hint, -4=x, -5=wrong hint
  var edges = List.filled(6, 0);
  var num = 0;

  HexagonBox({
    Key? key,
    required this.row,
    required this.col,
  }) : super(key: key);

  @override
  HexagonBoxState createState() => HexagonBoxState();
}

class HexagonBoxState extends State<HexagonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _hintAnimation;
  late Animation<Color?> _wrongAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _hintAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.yellow,
    ).animate(_controller);

    _wrongAnimation = ColorTween(
      begin: Colors.black,
      end: Colors.red,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double cellSize = 40.0; // radius

  // 0/-3 → fresh chain colour
  // colour/-5 → -4 (X)
  // -1 → -2 (mark "I disagree with the auto-disable")
  // -2 → -1 (revert to auto-disabled)
  // -4 → 0
  int _cycleEdge(int current) {
    if (current == 0 || current == -3) return ThemeColor().getNormalRandom();
    if (current >= 1 || current == -5) return -4;
    if (current == -1) return -2;
    if (current == -2) return -1;
    if (current == -4) return 0;
    return 0;
  }

  Color _edgeColor(int value) {
    if (value == -3) return _hintAnimation.value ?? Colors.transparent;
    if (value == -5) return _wrongAnimation.value ?? Colors.transparent;
    String key = "line_";
    if (value <= 0) {
      switch (value) {
        case 0: key += "normal"; break;
        case -1: key += "disable"; break;
        case -2: key += "wrong"; break;
        case -4: key += "x"; break;
        default: key += "normal";
      }
    } else if (value < 10) {
      key += "0$value";
    } else {
      key += value.toString();
    }
    return ThemeColor().lineColor[key]!;
  }

  @override
  Widget build(BuildContext context) {
    // Pointy-top hexagon: width = R·√3, height = 2R.
    final r = cellSize;
    final w = r * sqrt(3);
    final h = r * 2;

    return Consumer<HexagonProvider>(
      builder: (context, provider, child) {
        final bool hasAnimEdge =
            widget.edges.any((e) => e == -3 || e == -5);
        Widget painted = CustomPaint(
          size: Size(w, h),
          painter: _HexagonPainter(
            edges: List<int>.from(widget.edges),
            num: widget.num,
            edgeColorFn: _edgeColor,
            bgColor: ThemeColor().getColor()["box"] ?? Colors.black,
            numColor: ThemeColor().getColor()["number"] ?? Colors.white,
          ),
        );
        if (hasAnimEdge) {
          painted = AnimatedBuilder(
            animation: _hintAnimation,
            builder: (_, __) => CustomPaint(
              size: Size(w, h),
              painter: _HexagonPainter(
                edges: List<int>.from(widget.edges),
                num: widget.num,
                edgeColorFn: _edgeColor,
                bgColor: ThemeColor().getColor()["box"] ?? Colors.black,
                numColor: ThemeColor().getColor()["number"] ?? Colors.white,
              ),
            ),
          );
        }
        return RepaintBoundary(
          child: GestureDetector(
            onTapUp: (details) => _handleTap(details, provider, w, h),
            child: painted,
          ),
        );
      },
    );
  }

  void _handleTap(TapUpDetails details, HexagonProvider provider, double w, double h) {
    final pos = details.localPosition;
    int edgeIdx = _hitTestEdge(pos, w, h);
    if (edgeIdx < 0) return;

    setState(() {
      widget.edges[edgeIdx] = _cycleEdge(widget.edges[edgeIdx]);
    });

    provider.updateEdge(widget.row, widget.col, edgeIdx, widget.edges[edgeIdx]);
  }

  /// Determine which of the 6 edges was tapped.
  /// Pointy-top: edge midpoints are at angles 60°, 0°, 300°, 240°, 180°, 120°
  /// for edges 0..5 respectively. Each edge spans 60°.
  int _hitTestEdge(Offset pos, double w, double h) {
    double cx = w / 2;
    double cy = h / 2;
    double dx = pos.dx - cx;
    double dy = pos.dy - cy;

    double angle = atan2(-dy, dx); // flip y for screen coords
    if (angle < 0) angle += 2 * pi;

    if (angle >= pi / 6 && angle < pi / 2) return 0;          // 30-90  top-right slant
    if (angle < pi / 6 || angle >= 11 * pi / 6) return 1;     // -30-30 right vertical
    if (angle >= 3 * pi / 2 && angle < 11 * pi / 6) return 2; // 270-330 bottom-right slant
    if (angle >= 7 * pi / 6 && angle < 3 * pi / 2) return 3;  // 210-270 bottom-left slant
    if (angle >= 5 * pi / 6 && angle < 7 * pi / 6) return 4;  // 150-210 left vertical
    return 5;                                                  // 90-150 top-left slant
  }
}

class _HexagonPainter extends CustomPainter {
  final List<int> edges;
  final int num;
  final Color Function(int) edgeColorFn;
  final Color bgColor;
  final Color numColor;

  _HexagonPainter({
    required this.edges,
    required this.num,
    required this.edgeColorFn,
    required this.bgColor,
    required this.numColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Pointy-top: vertex-distance R = half of box height.
    final r = size.height / 2;

    // Pointy-top hexagon vertices (starting from top, clockwise)
    List<Offset> vertices = [];
    for (int i = 0; i < 6; i++) {
      double angle = (60 * i - 90) * pi / 180;
      vertices.add(Offset(cx + r * cos(angle), cy + r * sin(angle)));
    }

    // Fill hexagon
    final bgPaint = Paint()..color = bgColor..style = PaintingStyle.fill;
    final path = Path()..moveTo(vertices[0].dx, vertices[0].dy);
    for (int i = 1; i < 6; i++) {
      path.lineTo(vertices[i].dx, vertices[i].dy);
    }
    path.close();
    canvas.drawPath(path, bgPaint);

    // Draw edges
    final edgePaint = Paint()..strokeWidth = 4.0..strokeCap = StrokeCap.round;
    final xPaint = Paint()
      ..color = numColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    // Edge i connects vertex[i] to vertex[(i+1)%6]
    for (int i = 0; i < 6; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % 6];
      edgePaint.color = edgeColorFn(edges[i]);
      canvas.drawLine(a, b, edgePaint);
      if (edges[i] == -4) {
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        const double xr = 4.0;
        canvas.drawLine(mid.translate(-xr, -xr), mid.translate(xr, xr), xPaint);
        canvas.drawLine(mid.translate(-xr, xr), mid.translate(xr, -xr), xPaint);
      }
    }

    // Draw vertex dots
    final dotPaint = Paint()..color = Colors.grey..style = PaintingStyle.fill;
    for (var v in vertices) {
      canvas.drawCircle(v, 3, dotPaint);
    }

    // Draw number
    if (num >= 0) {
      int active = 0;
      for (int e = 0; e < 6; e++) {
        if (edges[e] >= 1) active++;
      }
      // Cell rule is satisfied → remaining edges are auto-disabled. Dim the
      // number so the player can see this cell is done.
      final Color textColor =
          active == num ? numColor.withOpacity(0.35) : numColor;
      final textSpan = TextSpan(
        text: num.toString(),
        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter old) {
    // Hint (-3) and wrong-flash (-5) colours come from a closure that closes
    // over the AnimationController's value. The edges array doesn't change
    // between ticks, so without this check `shouldRepaint` would freeze the
    // gradient on whatever frame the painter was last rebuilt on.
    for (int i = 0; i < 6; i++) {
      if (edges[i] == -3 || edges[i] == -5) return true;
    }
    for (int i = 0; i < 6; i++) {
      if (old.edges[i] != edges[i]) return true;
    }
    return old.num != num;
  }
}
