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

  int _cycleEdge(int current) {
    if (current == 0 || current == -3) return 1;
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
    final r = cellSize;
    final w = r * 2;
    final h = r * sqrt(3);

    return Consumer<HexagonProvider>(
      builder: (context, provider, child) {
        return AnimatedBuilder(
          animation: _hintAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTapUp: (details) => _handleTap(details, provider, w, h),
              child: CustomPaint(
                size: Size(w, h),
                painter: _HexagonPainter(
                  edges: widget.edges,
                  num: widget.num,
                  edgeColorFn: _edgeColor,
                  bgColor: ThemeColor().getColor()["box"] ?? Colors.black,
                  numColor: ThemeColor().getColor()["number"] ?? Colors.white,
                ),
              ),
            );
          },
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
  /// Divide the hexagon into 6 sectors from center.
  int _hitTestEdge(Offset pos, double w, double h) {
    double cx = w / 2;
    double cy = h / 2;
    double dx = pos.dx - cx;
    double dy = pos.dy - cy;

    // Angle from center (0 = right, counterclockwise)
    double angle = atan2(-dy, dx); // flip y for screen coords
    if (angle < 0) angle += 2 * pi;

    // Map angle to edge index:
    // 0=top (60-120°), 1=topRight (0-60°), 2=bottomRight (300-360°),
    // 3=bottom (240-300°), 4=bottomLeft (180-240°), 5=topLeft (120-180°)
    if (angle >= pi / 3 && angle < 2 * pi / 3) return 0;       // top
    if (angle >= 0 && angle < pi / 3) return 1;                 // topRight
    if (angle >= 5 * pi / 3 && angle < 2 * pi) return 2;       // bottomRight
    if (angle >= 4 * pi / 3 && angle < 5 * pi / 3) return 3;   // bottom
    if (angle >= pi && angle < 4 * pi / 3) return 4;            // bottomLeft
    if (angle >= 2 * pi / 3 && angle < pi) return 5;            // topLeft

    return 0;
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
    final r = size.width / 2;

    // Flat-top hexagon vertices (starting from top, clockwise)
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
    // Edge i connects vertex[i] to vertex[(i+1)%6]
    for (int i = 0; i < 6; i++) {
      edgePaint.color = edgeColorFn(edges[i]);
      canvas.drawLine(vertices[i], vertices[(i + 1) % 6], edgePaint);
    }

    // Draw vertex dots
    final dotPaint = Paint()..color = Colors.grey..style = PaintingStyle.fill;
    for (var v in vertices) {
      canvas.drawCircle(v, 3, dotPaint);
    }

    // Draw number
    if (num >= 0) {
      final textSpan = TextSpan(
        text: num.toString(),
        style: TextStyle(color: numColor, fontSize: 14, fontWeight: FontWeight.w500),
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
    for (int i = 0; i < 6; i++) {
      if (old.edges[i] != edges[i]) return true;
    }
    return old.num != num;
  }
}
