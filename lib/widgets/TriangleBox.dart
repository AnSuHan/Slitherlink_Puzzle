// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ThemeColor.dart';
import '../provider/TriangleProvider.dart';

/// A single triangle cell in the Slitherlink triangle grid.
///
/// Edge semantics (shared with `TriangleProvider` / `TrianglePuzzle`):
///   Up ▲:   e0 = base (bottom horizontal)
///           e1 = left diagonal (apex ↘ bottom-left)
///           e2 = right diagonal (apex ↘ bottom-right)
///   Down ▽: e0 = top (horizontal)
///           e1 = left diagonal (top-left ↘ apex)
///           e2 = right diagonal (top-right ↘ apex)
// ignore: must_be_immutable
class TriangleBox extends StatefulWidget {
  final int row;
  final int idx;
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

  /// Width of one triangle's bounding box. An equilateral triangle has
  /// height w * sqrt(3)/2 ≈ w * 0.866.
  static const double cellSize = 50.0;
  static const double heightRatio = 0.866;

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
              // deferToChild → only claim hits that pass the painter's
              // triangle-interior check. Clicks in the rectangle's corners
              // (outside the triangle) fall through to the Stack neighbour.
              behavior: HitTestBehavior.deferToChild,
              onTapUp: (details) => _handleTap(details, provider),
              child: CustomPaint(
                size: const Size(cellSize, cellSize * heightRatio),
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
    const double w = cellSize;
    const double h = cellSize * heightRatio;

    final int edgeIdx = _hitTestEdge(pos, w, h);
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

    final int value =
        edgeIdx == 0 ? widget.edge0 : edgeIdx == 1 ? widget.edge1 : widget.edge2;
    provider.updateEdge(widget.row, widget.idx, edgeIdx, value);
  }

  /// Pick the edge (0, 1, 2) whose line segment is closest to the tap point.
  /// The painter's hitTest has already verified the tap is inside the triangle
  /// before this method runs.
  int _hitTestEdge(Offset pos, double w, double h) {
    return pickClosestEdge(widget.isUp, pos, w, h);
  }

  /// Pure-geometry picker exposed for unit tests. Returns the index (0/1/2)
  /// of the edge whose segment is closest to [pos] inside a triangle of
  /// orientation [isUp] sized (w, h).
  ///
  /// Edge layout (matches the painter):
  ///   Up:   e0 = p1-p2 (base),   e1 = p0-p1 (left),  e2 = p0-p2 (right)
  ///   Down: e0 = p0-p1 (top),    e1 = p0-p2 (left),  e2 = p1-p2 (right)
  @visibleForTesting
  static int pickClosestEdge(bool isUp, Offset pos, double w, double h) {
    final verts = _TrianglePainter.vertices(isUp, w, h);
    final p0 = verts[0], p1 = verts[1], p2 = verts[2];

    final double d0 = isUp
        ? _distToSegment(pos, p1, p2)
        : _distToSegment(pos, p0, p1);
    final double d1 = isUp
        ? _distToSegment(pos, p0, p1)
        : _distToSegment(pos, p0, p2);
    final double d2 = isUp
        ? _distToSegment(pos, p0, p2)
        : _distToSegment(pos, p1, p2);

    if (d0 <= d1 && d0 <= d2) return 0;
    if (d1 <= d2) return 1;
    return 2;
  }

  /// Pure-geometry interior test exposed for unit tests. Mirrors what the
  /// painter's hitTest uses to drop taps that fall in the bounding-box
  /// corners (so deferToChild can pass them to the underlying neighbour).
  @visibleForTesting
  static bool pointInTriangle(bool isUp, Offset pos, double w, double h) {
    final verts = _TrianglePainter.vertices(isUp, w, h);
    return _TrianglePainter._pointInTriangle(pos, verts[0], verts[1], verts[2]);
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final double dx = b.dx - a.dx;
    final double dy = b.dy - a.dy;
    final double lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (p - a).distance;
    double t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final proj = Offset(a.dx + t * dx, a.dy + t * dy);
    return (p - proj).distance;
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

  /// Triangle vertex positions inside a (w, h) box.
  ///   Up:   p0 = apex top, p1 = bot-left,  p2 = bot-right
  ///   Down: p0 = top-left, p1 = top-right, p2 = apex bottom
  static List<Offset> vertices(bool isUp, double w, double h) {
    if (isUp) {
      return [Offset(w / 2, 0), Offset(0, h), Offset(w, h)];
    }
    return [const Offset(0, 0), Offset(w, 0), Offset(w / 2, h)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final verts = vertices(isUp, w, h);
    final p0 = verts[0], p1 = verts[1], p2 = verts[2];

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, bgPaint);

    final edgePaint = Paint()
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    if (isUp) {
      // e0 base (p1-p2), e1 left diagonal (p0-p1), e2 right diagonal (p0-p2)
      edgePaint.color = edgeColorFn(edge0);
      canvas.drawLine(p1, p2, edgePaint);
      edgePaint.color = edgeColorFn(edge1);
      canvas.drawLine(p0, p1, edgePaint);
      edgePaint.color = edgeColorFn(edge2);
      canvas.drawLine(p0, p2, edgePaint);
    } else {
      // e0 top (p0-p1), e1 left diagonal (p0-p2), e2 right diagonal (p1-p2)
      edgePaint.color = edgeColorFn(edge0);
      canvas.drawLine(p0, p1, edgePaint);
      edgePaint.color = edgeColorFn(edge1);
      canvas.drawLine(p0, p2, edgePaint);
      edgePaint.color = edgeColorFn(edge2);
      canvas.drawLine(p1, p2, edgePaint);
    }

    final dotPaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p0, 3, dotPaint);
    canvas.drawCircle(p1, 3, dotPaint);
    canvas.drawCircle(p2, 3, dotPaint);

    if (num >= 0) {
      final textSpan = TextSpan(
        text: num.toString(),
        style: TextStyle(color: numColor, fontSize: 14, fontWeight: FontWeight.w500),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final double cx = (p0.dx + p1.dx + p2.dx) / 3;
      final double cy = (p0.dy + p1.dy + p2.dy) / 3;
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
    }
  }

  /// Return true only when the tap is inside the triangle. Clicks in the
  /// rectangular bounding box but outside the triangle fall through to the
  /// next Stack child so overlapping neighbours can still receive taps.
  @override
  bool? hitTest(Offset position) {
    const double w = TriangleBoxState.cellSize;
    const double h = TriangleBoxState.cellSize * TriangleBoxState.heightRatio;
    final verts = vertices(isUp, w, h);
    return _pointInTriangle(position, verts[0], verts[1], verts[2]);
  }

  static double _sign(Offset p, Offset a, Offset b) {
    return (p.dx - b.dx) * (a.dy - b.dy) - (a.dx - b.dx) * (p.dy - b.dy);
  }

  static bool _pointInTriangle(Offset p, Offset a, Offset b, Offset c) {
    final double d1 = _sign(p, a, b);
    final double d2 = _sign(p, b, c);
    final double d3 = _sign(p, c, a);
    final bool hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    final bool hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
    return !(hasNeg && hasPos);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) {
    return old.edge0 != edge0 ||
        old.edge1 != edge1 ||
        old.edge2 != edge2 ||
        old.num != num ||
        old.isUp != isUp;
  }
}
