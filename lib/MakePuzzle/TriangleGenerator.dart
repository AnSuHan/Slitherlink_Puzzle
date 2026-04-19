// ignore_for_file: file_names
import 'dart:math';
import 'dart:collection';

import 'SlitherlinkGenerator.dart' show Difficulty;

/// Slitherlink puzzle on an equilateral-triangle zigzag grid.
///
/// Geometry (shared with the painter + provider):
///   • Triangle (r, i) occupies the box at (i * w/2, r * h), size (w, h).
///   • Orientation: `isUp(r, i) = (r + i).isEven` — rows alternate which
///     parity points up, so the strip tiles without gaps.
///   • Vertices: a row has `triPerRow + 2` grid points, x = vi * w/2,
///     indexed as v(vr, vi) with `vi ∈ [0, triPerRow + 1]`.
///   • Up ▲(r, i) uses  v(r, i+1) [apex], v(r+1, i) [BL], v(r+1, i+2) [BR].
///   • Down ▽(r, i) uses v(r, i)   [TL],   v(r, i+2)  [TR], v(r+1, i+1) [apex].
///
/// Edge indexing (matches the painter's edge0/1/2):
///   Up:   e0=base, e1=left-diagonal, e2=right-diagonal
///   Down: e0=top,  e1=left-diagonal, e2=right-diagonal
class TrianglePuzzle {
  final int rows;
  final int cols;

  /// Two triangles per column (one up, one down); a row has `2 * cols`.
  int get triPerRow => 2 * cols;
  int get totalCells => rows * triPerRow;

  /// Up-pointing when (row + idx) is even.
  bool isUp(int row, int idx) => (row + idx).isEven;

  /// solution[row][idx]: number of active edges around a triangle (0-3)
  late List<List<int>> solution;

  /// clue[row][idx]: displayed hint (-1 hidden, 0-3 revealed)
  late List<List<int>> clue;

  /// Active edges stored by encoded endpoint pair.
  late Set<int> activeEdges;

  TrianglePuzzle(this.rows, this.cols) {
    solution = List.generate(rows, (_) => List.filled(triPerRow, 0));
    clue = List.generate(rows, (_) => List.filled(triPerRow, -1));
    activeEdges = {};
  }

  /// Canonical encoding of the unordered edge (a, b).
  static int encodeEdge(int a, int b) {
    final int lo = min(a, b);
    final int hi = max(a, b);
    return lo * 100000 + hi;
  }

  /// Width of the vertex grid used to derive stable vertex indices.
  int get _vertexStride => triPerRow + 2;

  int _vertexIndex(int vr, int vi) => vr * _vertexStride + vi;

  /// Ordered [e0, e1, e2] vertex pairs for triangle (row, idx).
  ///
  /// e0 is the horizontal edge (base for Up, top for Down). e1 is the
  /// left diagonal, e2 the right diagonal. The painter and provider both
  /// assume this ordering.
  List<List<int>> edgeVertexPairs(int row, int idx) {
    if (isUp(row, idx)) {
      final int apex = _vertexIndex(row, idx + 1);
      final int bl = _vertexIndex(row + 1, idx);
      final int br = _vertexIndex(row + 1, idx + 2);
      return [
        [bl, br], // e0 base
        [apex, bl], // e1 left diagonal
        [apex, br], // e2 right diagonal
      ];
    }
    final int tl = _vertexIndex(row, idx);
    final int tr = _vertexIndex(row, idx + 2);
    final int apex = _vertexIndex(row + 1, idx + 1);
    return [
      [tl, tr], // e0 top
      [tl, apex], // e1 left diagonal
      [tr, apex], // e2 right diagonal
    ];
  }

  /// Flat edge format consumed by `TriangleProvider`: one list per row,
  /// `triPerRow * 3` ints each (three per triangle in e0/e1/e2 order).
  List<List<int>> toEdgeFormat() {
    final List<List<int>> result = [];
    for (int r = 0; r < rows; r++) {
      final List<int> rowEdges = [];
      for (int idx = 0; idx < triPerRow; idx++) {
        for (final pair in edgeVertexPairs(r, idx)) {
          final int code = encodeEdge(pair[0], pair[1]);
          rowEdges.add(activeEdges.contains(code) ? 1 : 0);
        }
      }
      result.add(rowEdges);
    }
    return result;
  }
}

/// Generates Slitherlink puzzles on the equilateral triangle zigzag grid
/// defined by `TrianglePuzzle`. Edge-sharing and neighbour relations follow
/// the same geometry as the painter, so generated clue numbers line up with
/// what the user sees.
class TriangleGenerator {
  final int rows;
  final int cols;
  final Random _random;

  int get _triPerRow => 2 * cols;
  int get _vertexStride => _triPerRow + 2;

  TriangleGenerator(this.rows, this.cols, {int? seed})
      : _random = seed != null ? Random(seed) : Random();

  int _vertexIndex(int vr, int vi) => vr * _vertexStride + vi;

  bool _isUp(int r, int i) => (r + i).isEven;

  /// Three vertex indices for the triangle at (row, idx) in a stable order.
  List<int> _triangleVertices(int row, int idx) {
    if (_isUp(row, idx)) {
      return [
        _vertexIndex(row, idx + 1),
        _vertexIndex(row + 1, idx),
        _vertexIndex(row + 1, idx + 2),
      ];
    }
    return [
      _vertexIndex(row, idx),
      _vertexIndex(row, idx + 2),
      _vertexIndex(row + 1, idx + 1),
    ];
  }

  /// The three encoded edges of triangle (row, idx).
  List<int> _triangleEdges(int row, int idx) {
    final v = _triangleVertices(row, idx);
    return [
      TrianglePuzzle.encodeEdge(v[0], v[1]),
      TrianglePuzzle.encodeEdge(v[1], v[2]),
      TrianglePuzzle.encodeEdge(v[0], v[2]),
    ];
  }

  /// Triangles that share an edge with (row, idx).
  ///
  /// Each triangle has at most three neighbours: two in the same row
  /// (left and right, which flip orientation) and one above or below
  /// (sharing the horizontal edge).
  List<List<int>> _cellNeighbors(int row, int idx) {
    final List<List<int>> out = [];
    if (idx - 1 >= 0) out.add([row, idx - 1]);
    if (idx + 1 < _triPerRow) out.add([row, idx + 1]);
    if (_isUp(row, idx)) {
      if (row + 1 < rows) out.add([row + 1, idx]);
    } else {
      if (row - 1 >= 0) out.add([row - 1, idx]);
    }
    return out;
  }

  /// Minimum ratio of triangles that must have at least one active edge.
  /// Bumped from 0.70 → 0.90 so the boundary snakes through nearly the whole
  /// grid instead of leaving large empty pockets.
  static const double _minCoverage = 0.50;

  /// Generate a complete puzzle.
  TrianglePuzzle generate({Difficulty difficulty = Difficulty.normal}) {
    for (int attempt = 0; attempt < 3000; attempt++) {
      final TrianglePuzzle puzzle = TrianglePuzzle(rows, cols);

      final Set<int> edges = _generateLoop();
      if (edges.length < 3) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < _minCoverage) continue;

      _buildClue(puzzle, difficulty);
      return puzzle;
    }
    throw Exception('Failed to generate triangle puzzle after 3000 attempts');
  }

  /// Generate with all solution numbers revealed.
  TrianglePuzzle generateSolution() {
    for (int attempt = 0; attempt < 3000; attempt++) {
      final TrianglePuzzle puzzle = TrianglePuzzle(rows, cols);
      final Set<int> edges = _generateLoop();
      if (edges.length < 3) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < _minCoverage) continue;

      for (int r = 0; r < rows; r++) {
        for (int i = 0; i < _triPerRow; i++) {
          puzzle.clue[r][i] = puzzle.solution[r][i];
        }
      }
      return puzzle;
    }
    throw Exception('Failed to generate triangle puzzle after 3000 attempts');
  }

  double _cellCoverage(TrianglePuzzle puzzle) {
    int touched = 0;
    final int total = rows * _triPerRow;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (puzzle.solution[r][i] > 0) touched++;
      }
    }
    return touched / total;
  }

  /// Build a simply-connected inside region and return its boundary edges.
  ///
  /// Inverted growth: start with the entire grid marked inside and then carve
  /// out a thin outside corridor from a random border cell. A thin outside
  /// means nearly every outside cell is adjacent to inside (touched) and
  /// nearly every inside cell on the corridor's fringe is also touched, so
  /// cell coverage stays very high. We keep the inside region connected so
  /// the boundary stays a single loop.
  Set<int> _generateLoop() {
    final int totalCells = rows * _triPerRow;
    final List<List<bool>> inside =
        List.generate(rows, (_) => List.filled(_triPerRow, true));

    // Seed the outside on a border cell. Any cell in row 0, row rows-1,
    // column 0, or column _triPerRow-1 works.
    final int sr = _random.nextInt(2) == 0 ? 0 : rows - 1;
    final int si = _random.nextInt(_triPerRow);
    inside[sr][si] = false;
    int outsideSize = 1;

    final Set<int> frontier = {};
    for (final n in _cellNeighbors(sr, si)) {
      frontier.add(n[0] * _triPerRow + n[1]);
    }

    // Target outside size ~20-35% of cells (thin corridor) — leaves inside
    // at 65-80% and coverage very close to 100%.
    final int target =
        max(2, (totalCells * (0.20 + _random.nextDouble() * 0.15)).round());

    while (outsideSize < target && frontier.isNotEmpty) {
      final fList = frontier.toList()..shuffle(_random);
      // Prefer frontier cells with the fewest inside-neighbours that are
      // still inside — keeps the outside corridor thin rather than blobby.
      fList.sort((a, b) {
        final ar = a ~/ _triPerRow, ai = a % _triPerRow;
        final br = b ~/ _triPerRow, bi = b % _triPerRow;
        return _outsideNeighbourCount(inside, ar, ai)
            .compareTo(_outsideNeighbourCount(inside, br, bi));
      });
      // Invert the comparator so cells touching more outside cells (snake-tip
      // extension points) get picked first.
      final ordered = fList.reversed.toList();

      bool flipped = false;
      for (final encoded in ordered) {
        final int r = encoded ~/ _triPerRow, i = encoded % _triPerRow;
        if (!inside[r][i]) {
          frontier.remove(encoded);
          continue;
        }

        inside[r][i] = false;
        if (!_insideConnected(inside)) {
          inside[r][i] = true;
          continue;
        }

        frontier.remove(encoded);
        outsideSize++;
        flipped = true;
        for (final fn in _cellNeighbors(r, i)) {
          if (inside[fn[0]][fn[1]]) {
            frontier.add(fn[0] * _triPerRow + fn[1]);
          }
        }
        break;
      }
      if (!flipped) break;
    }

    return _extractBoundaryEdges(inside);
  }

  int _outsideNeighbourCount(List<List<bool>> inside, int r, int i) {
    int count = 0;
    for (final n in _cellNeighbors(r, i)) {
      if (!inside[n[0]][n[1]]) count++;
    }
    return count;
  }

  /// True iff the inside region is a single connected piece. Mirror of
  /// `_outsideConnected` — used when we grow the outside corridor to ensure
  /// we never split the inside into two islands.
  bool _insideConnected(List<List<bool>> inside) {
    int startR = -1, startI = -1;
    for (int r = 0; r < rows && startR == -1; r++) {
      for (int i = 0; i < _triPerRow && startR == -1; i++) {
        if (inside[r][i]) {
          startR = r;
          startI = i;
        }
      }
    }
    if (startR == -1) return false; // nothing inside → degenerate

    final List<List<bool>> visited =
        List.generate(rows, (_) => List.filled(_triPerRow, false));
    visited[startR][startI] = true;
    final Queue<int> queue = Queue();
    queue.add(startR * _triPerRow + startI);
    int visitedCount = 1;

    while (queue.isNotEmpty) {
      final int enc = queue.removeFirst();
      final int r = enc ~/ _triPerRow, i = enc % _triPerRow;
      for (final n in _cellNeighbors(r, i)) {
        final int nr = n[0], ni = n[1];
        if (inside[nr][ni] && !visited[nr][ni]) {
          visited[nr][ni] = true;
          queue.add(nr * _triPerRow + ni);
          visitedCount++;
        }
      }
    }

    int insideCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (inside[r][i]) insideCount++;
      }
    }
    return visitedCount == insideCount;
  }

  double _coverageFromInside(List<List<bool>> inside) {
    int touched = 0;
    final int total = rows * _triPerRow;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (inside[r][i]) {
          for (final n in _cellNeighbors(r, i)) {
            if (!inside[n[0]][n[1]]) {
              touched++;
              break;
            }
          }
        } else {
          for (final n in _cellNeighbors(r, i)) {
            if (inside[n[0]][n[1]]) {
              touched++;
              break;
            }
          }
        }
      }
    }
    return touched / total;
  }

  bool _outsideConnected(List<List<bool>> inside) {
    int startR = -1, startI = -1;

    for (int i = 0; i < _triPerRow && startR == -1; i++) {
      if (!inside[0][i]) {
        startR = 0;
        startI = i;
      }
      if (startR == -1 && !inside[rows - 1][i]) {
        startR = rows - 1;
        startI = i;
      }
    }
    for (int r = 0; r < rows && startR == -1; r++) {
      if (!inside[r][0]) {
        startR = r;
        startI = 0;
      }
      if (startR == -1 && !inside[r][_triPerRow - 1]) {
        startR = r;
        startI = _triPerRow - 1;
      }
    }

    if (startR == -1) {
      for (int r = 0; r < rows; r++) {
        for (int i = 0; i < _triPerRow; i++) {
          if (!inside[r][i]) return false;
        }
      }
      return true;
    }

    final List<List<bool>> visited =
        List.generate(rows, (_) => List.filled(_triPerRow, false));
    visited[startR][startI] = true;
    final Queue<int> queue = Queue();
    queue.add(startR * _triPerRow + startI);
    int visitedCount = 1;

    while (queue.isNotEmpty) {
      final int enc = queue.removeFirst();
      final int r = enc ~/ _triPerRow, i = enc % _triPerRow;
      for (final n in _cellNeighbors(r, i)) {
        final int nr = n[0], ni = n[1];
        if (!inside[nr][ni] && !visited[nr][ni]) {
          visited[nr][ni] = true;
          queue.add(nr * _triPerRow + ni);
          visitedCount++;
        }
      }
    }

    int outsideCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (!inside[r][i]) outsideCount++;
      }
    }
    return visitedCount == outsideCount;
  }

  /// An edge is on the boundary iff exactly one of the triangles that share
  /// it is inside the region.
  Set<int> _extractBoundaryEdges(List<List<bool>> inside) {
    final Set<int> edges = {};

    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (!inside[r][i]) continue;

        final List<int> triEdges = _triangleEdges(r, i);
        final List<List<int>> neighbors = _cellNeighbors(r, i);

        for (final int edgeCode in triEdges) {
          bool isBoundary = true;
          for (final n in neighbors) {
            final List<int> nEdges = _triangleEdges(n[0], n[1]);
            if (nEdges.contains(edgeCode) && inside[n[0]][n[1]]) {
              isBoundary = false;
              break;
            }
          }
          if (isBoundary) edges.add(edgeCode);
        }
      }
    }

    return edges;
  }

  void _computeSolution(TrianglePuzzle puzzle) {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        int count = 0;
        for (final int e in _triangleEdges(r, i)) {
          if (puzzle.activeEdges.contains(e)) count++;
        }
        puzzle.solution[r][i] = count;
      }
    }
  }

  void _buildClue(TrianglePuzzle puzzle, Difficulty difficulty) {
    final int total = rows * _triPerRow;
    final int toReveal = (total * difficulty.hintRatio).round();

    final List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        cells.add([r, i]);
      }
    }
    cells.shuffle(_random);

    for (int j = 0; j < toReveal && j < cells.length; j++) {
      puzzle.clue[cells[j][0]][cells[j][1]] =
          puzzle.solution[cells[j][0]][cells[j][1]];
    }
  }
}
