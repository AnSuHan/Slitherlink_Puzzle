// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ThemeColor.dart';
import '../provider/TriangleProvider.dart';

/// A single triangle cell in the Slitherlink triangle grid.
/// Up triangles ▲ have edges: 0=top, 1=left, 2=right
/// Down triangles ▽ have edges: 0=bottom, 1=left, 2=right
// ignore: must_be_immutable
class TriangleBox extends StatefulWidget {
  final int row;
  final int idx; // triangle index within row (0..2*cols-1)
  final bool isUp;

  /// Edge values: 0=normal, 1+=selected, -1=disable, -3=hint, -4=x, -5=wrong hint
  var edge0 = 0, edge1 = 0, edge2 = 0;
  var num = 0;

  TriangleBox({
    Key? key,
    required this.row,
    required this.idx,
    required this.isUp,
  }) : super(key: key);

  @override
  TriangleBoxState createState() => TriangleBoxState();
}

class TriangleBoxState extends State<TriangleBox> with SingleTickerProviderStateMixin {
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

  static const double cellSize = 50.0;
  static const double edgeThickness = 8.0;

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
    return Consumer<TriangleProvider>(
      builder: (context, provider, child) {
        return AnimatedBuilder(
          animation: _hintAnimation,
          builder: (context, child) {
            return GestureDetector(
              onTapUp: (details) => _handleTap(details, provider),
              child: CustomPaint(
                size: const Size(cellSize, cellSize * 0.866),
                painter: _TrianglePainter(
                  isUp: widget.isUp,
                  edge0: widget.edge0,
                  edge1: widget.edge1,
                  edge2: widget.edge2,
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

  void _handleTap(TapUpDetails details, TriangleProvider provider) {
    final pos = details.localPosition;
    final w = cellSize;
    final h = cellSize * 0.866;

    // Determine which edge was tapped based on position within the triangle
    int edgeIdx = _hitTestEdge(pos, w, h);
    if (edgeIdx < 0) return;

    setState(() {
      switch (edgeIdx) {
        case 0:
          widget.edge0 = _cycleEdge(widget.edge0);
          break;
        case 1:
          widget.edge1 = _cycleEdge(widget.edge1);
          break;
        case 2:
          widget.edge2 = _cycleEdge(widget.edge2);
          break;
      }
    });

    int value = edgeIdx == 0 ? widget.edge0 : edgeIdx == 1 ? widget.edge1 : widget.edge2;
    provider.updateEdge(widget.row, widget.idx, edgeIdx, value);
  }

  /// Hit test: which edge (0, 1, 2) was tapped?
  int _hitTestEdge(Offset pos, double w, double h) {
    // For up triangle ▲: edge0=top(horizontal), edge1=left(diagonal), edge2=right(diagonal)
    // For down triangle ▽: edge0=bottom(horizontal), edge1=left(diagonal), edge2=right(diagonal)
    double x = pos.dx;
    double y = pos.dy;
    double cx = w / 2;

    if (widget.isUp) {
      // Top edge region: upper 1/3
      if (y < h * 0.33) return 0;
      // Left edge: left of center
      if (x < cx) return 1;
      // Right edge: right of center
      return 2;
    } else {
      // Bottom edge region: lower 1/3
      if (y > h * 0.67) return 0;
      // Left edge: left of center
      if (x < cx) return 1;
      // Right edge: right of center
      return 2;
    }
  }
}

class _TrianglePainter extends CustomPainter {
  final bool isUp;
  final int edge0, edge1, edge2;
  final int num;
  final Color Function(int) edgeColorFn;
  final Color bgColor;
  final Color numColor;

  _TrianglePainter({
    required this.isUp,
    required this.edge0,
    required this.edge1,
    required this.edge2,
    required this.num,
    required this.edgeColorFn,
    required this.bgColor,
    required this.numColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Triangle vertices
    Offset p0, p1, p2;
    if (isUp) {
      p0 = Offset(w / 2, 0);     // top
      p1 = Offset(0, h);         // bottom-left
      p2 = Offset(w, h);         // bottom-right
    } else {
      p0 = Offset(0, 0);         // top-left
      p1 = Offset(w, 0);         // top-right
      p2 = Offset(w / 2, h);     // bottom
    }

    // Fill triangle
    final bgPaint = Paint()..color = bgColor..style = PaintingStyle.fill;
    final path = Path()..moveTo(p0.dx, p0.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close();
    canvas.drawPath(path, bgPaint);

    // Draw edges
    final edgePaint = Paint()..strokeWidth = 4.0..strokeCap = StrokeCap.round;

    // Edge 0: top/bottom horizontal edge
    if (isUp) {
      // edge0 = bottom (p1 to p2)
      edgePaint.color = edgeColorFn(edge0);
      canvas.drawLine(p1, p2, edgePaint);
      // edge1 = left (p0 to p1)
      edgePaint.color = edgeColorFn(edge1);
      canvas.drawLine(p0, p1, edgePaint);
      // edge2 = right (p0 to p2)
      edgePaint.color = edgeColorFn(edge2);
      canvas.drawLine(p0, p2, edgePaint);
    } else {
      // edge0 = top (p0 to p1)
      edgePaint.color = edgeColorFn(edge0);
      canvas.drawLine(p0, p1, edgePaint);
      // edge1 = left (p0 to p2)
      edgePaint.color = edgeColorFn(edge1);
      canvas.drawLine(p0, p2, edgePaint);
      // edge2 = right (p1 to p2)
      edgePaint.color = edgeColorFn(edge2);
      canvas.drawLine(p1, p2, edgePaint);
    }

    // Draw vertices (dots)
    final dotPaint = Paint()..color = Colors.grey..style = PaintingStyle.fill;
    canvas.drawCircle(p0, 3, dotPaint);
    canvas.drawCircle(p1, 3, dotPaint);
    canvas.drawCircle(p2, 3, dotPaint);

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

      // Center of triangle
      double cx = (p0.dx + p1.dx + p2.dx) / 3;
      double cy = (p0.dy + p1.dy + p2.dy) / 3;
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) {
    return old.edge0 != edge0 || old.edge1 != edge1 || old.edge2 != edge2 ||
        old.num != num || old.isUp != isUp;
  }
}
