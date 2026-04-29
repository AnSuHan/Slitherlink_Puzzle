// ignore_for_file: file_names
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ThemeColor.dart';
import '../provider/TrihexProvider.dart';

/// Single-canvas renderer for the trihexagonal puzzle.
///
/// Hex and triangle cells are intermingled, so per-cell `Positioned`
/// widgets would need a non-trivial absolute layout. Painting everything
/// onto one `CustomPaint` is cleaner — every cell draws its own
/// perimeter from shared edge IDs in `TrihexProvider.edgeState`, and a
/// single hit-test routine maps a tap to the nearest edge segment.
///
/// The painter consumes a snapshot built once per provider state from
/// `_TrihexLayout`. Layout is pure geometry (vertex coordinates per
/// edge ID, cell centres, clue text) and recomputed only when the
/// puzzle dimensions change — `_TrihexLayout._isSameShape` keeps it
/// stable across edge updates.
class TrihexBox extends StatefulWidget {
  /// Hex radius in painter units. The smaller-hex (cell) circumradius is
  /// then `R * sqrt(3) / 2 = W / 2`. Triangles inscribed at hex grid
  /// vertices have side ≈ `W / 2`. Public so the scene can reuse it for
  /// fit-to-screen sizing.
  static const double cellSize = 30.0;

  const TrihexBox({Key? key}) : super(key: key);

  @override
  TrihexBoxState createState() => TrihexBoxState();
}

class TrihexBoxState extends State<TrihexBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _hintAnimation;
  late Animation<Color?> _wrongAnimation;

  /// Tap tolerance from edge midpoint (in canvas pixels). Anything
  /// outside this radius is ignored.
  static const double _hitRadius = 18.0;

  _TrihexLayout? _layout;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _hintAnimation = ColorTween(begin: Colors.blue, end: Colors.yellow)
        .animate(_controller);
    _wrongAnimation = ColorTween(begin: Colors.black, end: Colors.red)
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _edgeColor(int value) {
    if (value == -3) return _hintAnimation.value ?? Colors.transparent;
    if (value == -5) return _wrongAnimation.value ?? Colors.transparent;
    String key = "line_";
    if (value <= 0) {
      switch (value) {
        case 0:  key += "normal"; break;
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
    return ThemeColor().lineColor[key] ?? Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrihexProvider>(
      builder: (context, provider, child) {
        if (provider.rows == 0) {
          return const SizedBox.shrink();
        }
        if (_layout == null || !_layout!._isSameShape(provider)) {
          _layout = _TrihexLayout.build(provider, TrihexBox.cellSize);
        }
        final layout = _layout!;
        final colors = ThemeColor().getColor();
        final bgColor = colors["box"] ?? Colors.black;
        final numColor = colors["number"] ?? Colors.white;

        final bool hasAnimEdge = provider.edgeState.values
            .any((v) => v == -3 || v == -5);

        Widget painted = CustomPaint(
          size: Size(layout.canvasW, layout.canvasH),
          painter: _TrihexPainter(
            layout: layout,
            edgeState: Map<int, int>.from(provider.edgeState),
            edgeColorFn: _edgeColor,
            bgColor: bgColor,
            numColor: numColor,
          ),
        );
        if (hasAnimEdge) {
          painted = AnimatedBuilder(
            animation: _hintAnimation,
            builder: (_, __) => CustomPaint(
              size: Size(layout.canvasW, layout.canvasH),
              painter: _TrihexPainter(
                layout: layout,
                edgeState: Map<int, int>.from(provider.edgeState),
                edgeColorFn: _edgeColor,
                bgColor: bgColor,
                numColor: numColor,
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: GestureDetector(
            onTapUp: (details) =>
                _handleTap(details.localPosition, provider, layout),
            child: SizedBox(
              width: layout.canvasW,
              height: layout.canvasH,
              child: painted,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(
      Offset pos, TrihexProvider provider, _TrihexLayout layout) {
    int? closestEdge;
    double bestDist = _hitRadius;
    layout.edgeMidpoints.forEach((edgeId, mid) {
      final d = (pos - mid).distance;
      if (d < bestDist) {
        bestDist = d;
        closestEdge = edgeId;
      }
    });
    if (closestEdge == null) return;
    final cur = provider.edgeValue(closestEdge!);
    final next = provider.cycleEdge(cur);
    provider.updateEdge(closestEdge!, next);
  }
}

/// Pre-computed geometry for the painter and hit-tester. Cell positions
/// and per-edge midpoints are evaluated once per puzzle shape.
class _TrihexLayout {
  final int rows;
  final int cols;
  final int triCount;

  /// Trihex vertex ID → canvas (x, y).
  final Map<int, Offset> vertexPos;

  /// Trihex edge ID → midpoint (x, y) for hit-testing.
  final Map<int, Offset> edgeMidpoints;

  /// Each hex cell's perimeter as 6 trihex vertex IDs in cyclic order,
  /// plus its centre and clue.
  final List<_HexCellGeom> hexCells;

  /// Each triangle cell's perimeter as 3 trihex vertex IDs, plus centre
  /// and clue.
  final List<_TriCellGeom> triCells;

  /// Edges that don't belong to any triangle (grid rim) — drawn from a
  /// hex cell only.
  final List<int> rimEdges;

  final double canvasW;
  final double canvasH;

  _TrihexLayout({
    required this.rows,
    required this.cols,
    required this.triCount,
    required this.vertexPos,
    required this.edgeMidpoints,
    required this.hexCells,
    required this.triCells,
    required this.rimEdges,
    required this.canvasW,
    required this.canvasH,
  });

  bool _isSameShape(TrihexProvider provider) =>
      provider.rows == rows &&
      provider.cols == cols &&
      provider.puzzle.triangleIds.length == triCount;

  static _TrihexLayout build(TrihexProvider provider, double R) {
    final rows = provider.rows;
    final cols = provider.cols;
    final puzzle = provider.puzzle;
    final gen = provider.gen;

    final double w = R * sqrt(3); // hex width (flat-to-flat horizontal)
    final double padding = R;

    Offset hexCenter(int r, int c) {
      final double x = padding + w * c + (r & 1) * (w / 2) + w / 2;
      final double y = padding + R * 1.5 * r + R;
      return Offset(x, y);
    }

    // Original hex vertex positions (pointy-top).
    Offset hexVertex(int r, int c, int vi) {
      final ctr = hexCenter(r, c);
      switch (vi) {
        case 0: return Offset(ctr.dx, ctr.dy - R);
        case 1: return Offset(ctr.dx + w / 2, ctr.dy - R / 2);
        case 2: return Offset(ctr.dx + w / 2, ctr.dy + R / 2);
        case 3: return Offset(ctr.dx, ctr.dy + R);
        case 4: return Offset(ctr.dx - w / 2, ctr.dy + R / 2);
        case 5: return Offset(ctr.dx - w / 2, ctr.dy - R / 2);
      }
      return ctr;
    }

    // The smaller-hex corner positions (midpoints of original hex edges)
    // map 1:1 to trihex vertex IDs returned by `hexCellVerticesOf`.
    final Map<int, Offset> vertexPos = {};
    final Map<int, Offset> edgeMidpoints = {};
    final List<_HexCellGeom> hexCells = [];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final List<int> mids = gen.hexCellVerticesOf(r, c);
        final List<Offset> pts = [];
        for (int i = 0; i < 6; i++) {
          final a = hexVertex(r, c, i);
          final b = hexVertex(r, c, (i + 1) % 6);
          final m = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          vertexPos[mids[i]] = m;
          pts.add(m);
        }
        final List<int> edges = gen.hexCellEdgesOf(r, c);
        for (int i = 0; i < 6; i++) {
          final a = pts[i];
          final b = pts[(i + 1) % 6];
          edgeMidpoints[edges[i]] =
              Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        }
        hexCells.add(_HexCellGeom(
          r: r,
          c: c,
          centre: hexCenter(r, c),
          vertexIds: List<int>.from(mids),
          edgeIds: List<int>.from(edges),
          clue: puzzle.hexClue[r][c],
        ));
      }
    }

    final List<_TriCellGeom> triCells = [];
    final tri = gen.enumerateTriangles();
    for (final id in puzzle.triangleIds) {
      final rep = tri.rep[id]!;
      final List<int> tv = gen.triangleVerticesOf(rep[0], rep[1], rep[2]);
      final List<int> te = gen.triangleEdgesOf(rep[0], rep[1], rep[2]);
      final List<Offset> pts = [
        vertexPos[tv[0]]!,
        vertexPos[tv[1]]!,
        vertexPos[tv[2]]!,
      ];
      final ctr = Offset(
        (pts[0].dx + pts[1].dx + pts[2].dx) / 3,
        (pts[0].dy + pts[1].dy + pts[2].dy) / 3,
      );
      // Triangle perimeter edges: te[0] = mPrev-mNext, te[1] = mPrev-mFar,
      // te[2] = mNext-mFar — record midpoints for hit-test.
      edgeMidpoints[te[0]] = Offset(
          (pts[0].dx + pts[1].dx) / 2, (pts[0].dy + pts[1].dy) / 2);
      edgeMidpoints[te[1]] = Offset(
          (pts[0].dx + pts[2].dx) / 2, (pts[0].dy + pts[2].dy) / 2);
      edgeMidpoints[te[2]] = Offset(
          (pts[1].dx + pts[2].dx) / 2, (pts[1].dy + pts[2].dy) / 2);
      triCells.add(_TriCellGeom(
        triId: id,
        centre: ctr,
        vertexIds: tv,
        edgeIds: te,
        clue: puzzle.triClue[id] ?? -1,
      ));
    }

    // Rim edges are hex-perimeter edges that no triangle owns. They're
    // already in `edgeMidpoints` from the hex pass, so all that's left
    // is to know which IDs belong only to a hex.
    final Set<int> triEdgeIds = {};
    for (final t in triCells) {
      triEdgeIds.addAll(t.edgeIds);
    }
    final List<int> rimEdges = [];
    for (final h in hexCells) {
      for (final e in h.edgeIds) {
        if (!triEdgeIds.contains(e)) rimEdges.add(e);
      }
    }

    final double canvasW =
        padding * 2 + w * cols + w / 2; // half-step for odd row inset
    final double canvasH = padding * 2 + R * 1.5 * rows + R * 0.5;

    return _TrihexLayout(
      rows: rows,
      cols: cols,
      triCount: puzzle.triangleIds.length,
      vertexPos: vertexPos,
      edgeMidpoints: edgeMidpoints,
      hexCells: hexCells,
      triCells: triCells,
      rimEdges: rimEdges,
      canvasW: canvasW,
      canvasH: canvasH,
    );
  }
}

class _HexCellGeom {
  final int r;
  final int c;
  final Offset centre;
  final List<int> vertexIds; // 6, cyclic
  final List<int> edgeIds;   // 6, cyclic
  final int clue;
  _HexCellGeom({
    required this.r,
    required this.c,
    required this.centre,
    required this.vertexIds,
    required this.edgeIds,
    required this.clue,
  });
}

class _TriCellGeom {
  final int triId;
  final Offset centre;
  final List<int> vertexIds; // 3
  final List<int> edgeIds;   // 3 (te[0]=v0-v1, te[1]=v0-v2, te[2]=v1-v2)
  final int clue;
  _TriCellGeom({
    required this.triId,
    required this.centre,
    required this.vertexIds,
    required this.edgeIds,
    required this.clue,
  });
}

class _TrihexPainter extends CustomPainter {
  final _TrihexLayout layout;
  final Map<int, int> edgeState;
  final Color Function(int) edgeColorFn;
  final Color bgColor;
  final Color numColor;

  _TrihexPainter({
    required this.layout,
    required this.edgeState,
    required this.edgeColorFn,
    required this.bgColor,
    required this.numColor,
  });

  int _edgeValue(int id) => edgeState[id] ?? 0;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..style = PaintingStyle.fill..color = bgColor;
    // Cell fills.
    for (final h in layout.hexCells) {
      final path = Path()
        ..moveTo(layout.vertexPos[h.vertexIds[0]]!.dx,
            layout.vertexPos[h.vertexIds[0]]!.dy);
      for (int i = 1; i < 6; i++) {
        path.lineTo(layout.vertexPos[h.vertexIds[i]]!.dx,
            layout.vertexPos[h.vertexIds[i]]!.dy);
      }
      path.close();
      canvas.drawPath(path, bgPaint);
    }
    for (final t in layout.triCells) {
      final p0 = layout.vertexPos[t.vertexIds[0]]!;
      final p1 = layout.vertexPos[t.vertexIds[1]]!;
      final p2 = layout.vertexPos[t.vertexIds[2]]!;
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, bgPaint);
    }

    // Edges. Drawn once per ID so shared hex/triangle edges share state.
    final edgePaint = Paint()
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final xPaint = Paint()
      ..color = numColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final Set<int> drawn = {};
    void drawEdge(int edgeId, Offset a, Offset b) {
      if (!drawn.add(edgeId)) return;
      final v = _edgeValue(edgeId);
      edgePaint.color = edgeColorFn(v);
      canvas.drawLine(a, b, edgePaint);
      if (v == -4) {
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        const double xr = 4.0;
        canvas.drawLine(mid.translate(-xr, -xr), mid.translate(xr, xr), xPaint);
        canvas.drawLine(mid.translate(-xr, xr), mid.translate(xr, -xr), xPaint);
      }
    }

    for (final h in layout.hexCells) {
      for (int i = 0; i < 6; i++) {
        final a = layout.vertexPos[h.vertexIds[i]]!;
        final b = layout.vertexPos[h.vertexIds[(i + 1) % 6]]!;
        drawEdge(h.edgeIds[i], a, b);
      }
    }
    for (final t in layout.triCells) {
      // Triangle perimeter ordering: te[0] v0-v1, te[1] v0-v2, te[2] v1-v2.
      final p0 = layout.vertexPos[t.vertexIds[0]]!;
      final p1 = layout.vertexPos[t.vertexIds[1]]!;
      final p2 = layout.vertexPos[t.vertexIds[2]]!;
      drawEdge(t.edgeIds[0], p0, p1);
      drawEdge(t.edgeIds[1], p0, p2);
      drawEdge(t.edgeIds[2], p1, p2);
    }

    // Vertex dots.
    final dotPaint = Paint()..style = PaintingStyle.fill..color = Colors.grey;
    for (final v in layout.vertexPos.values) {
      canvas.drawCircle(v, 2.5, dotPaint);
    }

    // Clue numbers (hex max 6, tri max 3).
    void drawClue(Offset c, int clue, double fontSize, int activeNeighbours,
        int target) {
      if (clue < 0) return;
      final Color textColor = (target >= 0 && activeNeighbours == target)
          ? numColor.withOpacity(0.35)
          : numColor;
      final textSpan = TextSpan(
        text: clue.toString(),
        style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w500),
      );
      final textPainter =
          TextPainter(text: textSpan, textDirection: TextDirection.ltr)
            ..layout();
      textPainter.paint(
          canvas, Offset(c.dx - textPainter.width / 2,
              c.dy - textPainter.height / 2));
    }

    for (final h in layout.hexCells) {
      int active = 0;
      for (final e in h.edgeIds) {
        if (_edgeValue(e) >= 1) active++;
      }
      drawClue(h.centre, h.clue, 12, active, h.clue);
    }
    for (final t in layout.triCells) {
      int active = 0;
      for (final e in t.edgeIds) {
        if (_edgeValue(e) >= 1) active++;
      }
      drawClue(t.centre, t.clue, 10, active, t.clue);
    }
  }

  @override
  bool shouldRepaint(covariant _TrihexPainter old) =>
      old.edgeState.length != edgeState.length ||
      !_mapsEqual(old.edgeState, edgeState);

  static bool _mapsEqual(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }
}
