// ignore_for_file: file_names
import 'dart:math';
import 'dart:collection';

import 'SlitherlinkGenerator.dart' show Difficulty;

/// Slitherlink puzzle on the 3.6.3.6 trihexagonal tiling.
///
/// The tiling is the **medial graph of the honeycomb**: take the hex grid
/// from `HexagonGenerator` (rows × cols pointy-top hexes, even-row offset)
/// and place a trihex vertex at the midpoint of every hex edge. Each
/// original hexagon shrinks to a smaller hex cell connecting its 6
/// midpoints; each interior hex-grid vertex (one shared by three in-grid
/// hexes) becomes a triangle cell connecting the three midpoints around it.
///
/// Topology guarantees:
///   • Hex cells and triangle cells alternate around every trihex vertex.
///   • Every trihex edge is shared by exactly one hex cell and one
///     triangle cell — except along the outer boundary of the rows × cols
///     hex region, where only a hex cell sits on one side.
///   • Hex clue ∈ 0..6, triangle clue ∈ 0..3.
///
/// Vertex IDs (`int`): canonical encoding of the unordered pair of
/// hex-grid vertex IDs that bound the original hex edge whose midpoint
/// the trihex vertex sits on. Hex-grid vertex IDs come from
/// `HexagonGenerator.hexVertices` so the schemes line up — the same
/// stride/offset arithmetic is used here.
///
/// Edge IDs (`int`): canonical encoding of the unordered pair of trihex
/// vertex IDs the edge connects. Triangle and hex cells share an ID space.
class TrihexPuzzle {
  final int rows;
  final int cols;

  /// hexSolution[r][c]: number of active edges around hex cell (r, c), 0..6
  late List<List<int>> hexSolution;

  /// hexClue[r][c]: revealed clue (-1 hidden, 0..6 revealed)
  late List<List<int>> hexClue;

  /// Triangle cells keyed by their hex-grid vertex ID (the original honeycomb
  /// vertex they sit at). Only interior vertices — those shared by three
  /// in-grid hexes — are present.
  late Map<int, int> triSolution;
  late Map<int, int> triClue;

  /// Stable list of triangle vertex IDs in canonical (sorted) order.
  /// Provider/serialization layers iterate this for deterministic output.
  late List<int> triangleIds;

  /// Active edges (encoded trihex edges).
  late Set<int> activeEdges;

  TrihexPuzzle(this.rows, this.cols) {
    hexSolution = List.generate(rows, (_) => List.filled(cols, 0));
    hexClue = List.generate(rows, (_) => List.filled(cols, -1));
    triSolution = {};
    triClue = {};
    triangleIds = [];
    activeEdges = {};
  }

  /// Canonical encoding of an unordered pair (a, b).
  static int encodePair(int a, int b) {
    final int lo = a < b ? a : b;
    final int hi = a < b ? b : a;
    return lo * 100000 + hi;
  }

  /// Trihex edge ID — encodes two trihex vertex IDs (each itself an
  /// encoded pair). Vertex IDs can reach ~stride² ≈ 10⁴ at puzzle sizes
  /// we care about, so encodePair gives values < 10⁹ and the product
  /// stays inside the 63-bit positive range.
  static int encodeEdge(int tva, int tvb) {
    final int lo = tva < tvb ? tva : tvb;
    final int hi = tva < tvb ? tvb : tva;
    return lo * 1000000000 + hi;
  }
}

/// Generates Slitherlink puzzles on the trihex tiling.
class TrihexGenerator {
  final int rows;
  final int cols;
  final Random _random;

  TrihexGenerator(this.rows, this.cols, {int? seed})
      : _random = seed != null ? Random(seed) : Random();

  // --- Hex grid geometry (matches HexagonGenerator) -------------------------

  int get _hexStride => 2 * cols + 4;

  int _hexVertexEnc(int k, int m) => m * _hexStride + (k + 1);

  /// 6 hex-grid vertex IDs for hex (r, c), order: top, upper-right,
  /// lower-right, bottom, lower-left, upper-left. Same as
  /// `HexagonGenerator.hexVertices`.
  List<int> _hexVertices(int r, int c) {
    final int off = r & 1;
    final int ck = 2 * c + off;
    final int cm = 3 * r + 2;
    return [
      _hexVertexEnc(ck, cm - 2),
      _hexVertexEnc(ck + 1, cm - 1),
      _hexVertexEnc(ck + 1, cm + 1),
      _hexVertexEnc(ck, cm + 2),
      _hexVertexEnc(ck - 1, cm + 1),
      _hexVertexEnc(ck - 1, cm - 1),
    ];
  }

  /// 6 trihex vertices (= midpoints of hex edges) of hex (r, c), in the
  /// same cyclic order as `_hexVertices`.
  ///   m_i = midpoint of hex edge between v_i and v_{(i+1) mod 6}.
  List<int> _hexMidpoints(int r, int c) {
    final List<int> v = _hexVertices(r, c);
    return [
      TrihexPuzzle.encodePair(v[0], v[1]),
      TrihexPuzzle.encodePair(v[1], v[2]),
      TrihexPuzzle.encodePair(v[2], v[3]),
      TrihexPuzzle.encodePair(v[3], v[4]),
      TrihexPuzzle.encodePair(v[4], v[5]),
      TrihexPuzzle.encodePair(v[5], v[0]),
    ];
  }

  /// 6 trihex edges of hex (r, c), in the same cyclic order. Edge i goes
  /// from m_i to m_{(i+1) mod 6} and lies "across" hex-grid vertex
  /// v_{(i+1) mod 6} — so the triangle on the far side of this edge,
  /// when present, sits at v_{(i+1) mod 6}.
  List<int> _hexCellEdges(int r, int c) {
    final List<int> m = _hexMidpoints(r, c);
    return [
      TrihexPuzzle.encodeEdge(m[0], m[1]),
      TrihexPuzzle.encodeEdge(m[1], m[2]),
      TrihexPuzzle.encodeEdge(m[2], m[3]),
      TrihexPuzzle.encodeEdge(m[3], m[4]),
      TrihexPuzzle.encodeEdge(m[4], m[5]),
      TrihexPuzzle.encodeEdge(m[5], m[0]),
    ];
  }

  /// The two other in-grid hexes that share hex (r, c)'s vertex `vi`,
  /// where `vi ∈ 0..5` matches `_hexVertices` ordering.
  ///
  /// Vertex sharing (pointy-top, odd-row offset right):
  ///   v0 (top): TL, TR    v1 (UR): TR, R    v2 (LR): R, BR
  ///   v3 (bottom): BL, BR v4 (LL): L, BL    v5 (UL): TL, L
  ///
  /// Returns up to two `[r, c]` pairs (only those in-grid).
  List<List<int>> _vertexSiblings(int r, int c, int vi) {
    final bool even = (r & 1) == 0;
    final List<int> tl = even ? [r - 1, c - 1] : [r - 1, c];
    final List<int> tr = even ? [r - 1, c]     : [r - 1, c + 1];
    final List<int> l  = [r, c - 1];
    final List<int> rr = [r, c + 1];
    final List<int> bl = even ? [r + 1, c - 1] : [r + 1, c];
    final List<int> br = even ? [r + 1, c]     : [r + 1, c + 1];

    List<List<int>> picks;
    switch (vi) {
      case 0: picks = [tl, tr]; break;
      case 1: picks = [tr, rr]; break;
      case 2: picks = [rr, br]; break;
      case 3: picks = [bl, br]; break;
      case 4: picks = [l, bl];  break;
      case 5: picks = [tl, l];  break;
      default: throw ArgumentError('vi must be 0..5');
    }
    final List<List<int>> out = [];
    for (final p in picks) {
      if (p[0] >= 0 && p[0] < rows && p[1] >= 0 && p[1] < cols) {
        out.add(p);
      }
    }
    return out;
  }

  /// True iff the triangle cell at hex (r, c)'s vertex `vi` is "interior"
  /// — i.e., the two sibling hexes are also in-grid. Only interior
  /// vertices become triangle cells.
  bool _hasTriangleAt(int r, int c, int vi) =>
      _vertexSiblings(r, c, vi).length == 2;

  /// Enumerate every interior triangle cell exactly once, by canonical
  /// hex-grid vertex ID. Returns a sorted list for stable iteration plus
  /// a map from vertex ID to one representative `(r, c, vi)` so callers
  /// can recover the three sibling hexes / three edges.
  ({List<int> ids, Map<int, List<int>> rep}) _enumerateTriangles() {
    final Map<int, List<int>> rep = {};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final List<int> v = _hexVertices(r, c);
        for (int vi = 0; vi < 6; vi++) {
          if (!_hasTriangleAt(r, c, vi)) continue;
          rep.putIfAbsent(v[vi], () => [r, c, vi]);
        }
      }
    }
    final List<int> ids = rep.keys.toList()..sort();
    return (ids: ids, rep: rep);
  }

  /// 3 trihex edges of the triangle at vertex ID `triId`, given a
  /// representative hex `(r, c)` that owns vertex `vi == triId`.
  ///
  /// Geometry: the triangle's 3 corners are the midpoints of the 3 hex
  /// edges meeting at the vertex. From hex (r, c), two of those hex
  /// edges are e_{(vi - 1 + 6) % 6} and e_vi (the two edges incident to
  /// v_vi within (r, c)). The third edge belongs to one of the sibling
  /// hexes; we look it up there.
  List<int> _triangleEdges(int r, int c, int vi) {
    // The two midpoints visible from (r, c) at vertex v_vi.
    final List<int> m = _hexMidpoints(r, c);
    final int mPrev = m[(vi + 5) % 6]; // edge between v_{vi-1} and v_vi
    final int mNext = m[vi];           // edge between v_vi and v_{vi+1}

    // The third midpoint sits between the two sibling hexes. Find it via
    // a sibling — its midpoint at the same hex-grid vertex that is NOT
    // shared with (r, c).
    final List<List<int>> sibs = _vertexSiblings(r, c, vi);
    // Pick the sibling that is NOT a row-0 / col-0 neighbour of (r, c)
    // along edge e_{(vi-1)%6} or e_vi — i.e., we want the midpoint that
    // doesn't equal mPrev or mNext.
    int? mFar;
    for (final s in sibs) {
      final int sr = s[0], sc = s[1];
      // Find which vertex of the sibling matches v_vi.
      final List<int> sv = _hexVertices(sr, sc);
      final int targetV = _hexVertices(r, c)[vi];
      int sVi = -1;
      for (int k = 0; k < 6; k++) {
        if (sv[k] == targetV) { sVi = k; break; }
      }
      if (sVi == -1) continue;
      final List<int> sm = _hexMidpoints(sr, sc);
      final int candA = sm[(sVi + 5) % 6];
      final int candB = sm[sVi];
      for (final cand in [candA, candB]) {
        if (cand != mPrev && cand != mNext) { mFar = cand; break; }
      }
      if (mFar != null) break;
    }
    if (mFar == null) {
      throw StateError('Triangle at ($r,$c,$vi) missing third midpoint');
    }
    return [
      TrihexPuzzle.encodeEdge(mPrev, mNext),
      TrihexPuzzle.encodeEdge(mPrev, mFar),
      TrihexPuzzle.encodeEdge(mNext, mFar),
    ];
  }

  // --- Cell adjacency (bipartite hex ↔ triangle) ----------------------------

  /// Cells are addressed by either ('h', r, c) or ('t', triId).
  ///
  /// Hex (r, c)'s neighbours: for edge i ∈ 0..5, the triangle at vertex
  /// v_{(i+1) mod 6} if it exists (otherwise the edge is grid-boundary).
  ///
  /// Triangle at vertex `triId`'s neighbours: the 3 hexes around `triId`.

  List<int> _hexNeighborTriIds(int r, int c) {
    final List<int> v = _hexVertices(r, c);
    final List<int> out = [];
    for (int i = 0; i < 6; i++) {
      final int vi = (i + 1) % 6;
      if (_hasTriangleAt(r, c, vi)) out.add(v[vi]);
    }
    return out;
  }

  /// The 3 sibling hexes around triangle vertex `triId`, given a
  /// representative `(r, c, vi)`. Returns up to 3 `[r, c]` pairs (always
  /// 3 for interior triangles).
  List<List<int>> _triHexNeighbors(int r, int c, int vi) {
    final List<List<int>> sibs = _vertexSiblings(r, c, vi);
    return [[r, c], ...sibs];
  }

  // --- Loop generation ------------------------------------------------------

  /// Generate a complete puzzle.
  TrihexPuzzle generate({Difficulty difficulty = Difficulty.normal}) {
    final tri = _enumerateTriangles();
    for (int attempt = 0; attempt < 1000; attempt++) {
      final TrihexPuzzle puzzle = TrihexPuzzle(rows, cols);
      puzzle.triangleIds = List.of(tri.ids);

      final Set<int> edges = _generateLoop(tri);
      if (edges.length < 6) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle, tri);

      if (_cellCoverage(puzzle, tri) < 0.50) continue;

      _buildClue(puzzle, tri, difficulty);
      return puzzle;
    }
    throw Exception('Failed to generate trihex puzzle after 1000 attempts');
  }

  /// Generate with all clues revealed (for solver / debug).
  TrihexPuzzle generateSolution() {
    final tri = _enumerateTriangles();
    for (int attempt = 0; attempt < 1000; attempt++) {
      final TrihexPuzzle puzzle = TrihexPuzzle(rows, cols);
      puzzle.triangleIds = List.of(tri.ids);

      final Set<int> edges = _generateLoop(tri);
      if (edges.length < 6) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle, tri);

      if (_cellCoverage(puzzle, tri) < 0.50) continue;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          puzzle.hexClue[r][c] = puzzle.hexSolution[r][c];
        }
      }
      for (final id in tri.ids) {
        puzzle.triClue[id] = puzzle.triSolution[id] ?? 0;
      }
      return puzzle;
    }
    throw Exception('Failed to generate trihex puzzle after 1000 attempts');
  }

  /// Fraction of cells (hex + triangle) touched by the loop.
  double _cellCoverage(
      TrihexPuzzle puzzle, ({List<int> ids, Map<int, List<int>> rep}) tri) {
    int touched = 0;
    int total = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        total++;
        if (puzzle.hexSolution[r][c] > 0) touched++;
      }
    }
    for (final id in tri.ids) {
      total++;
      if ((puzzle.triSolution[id] ?? 0) > 0) touched++;
    }
    return total == 0 ? 0 : touched / total;
  }

  /// Grow a connected inside region across the bipartite hex/triangle
  /// graph, then return the boundary edges.
  ///
  /// Cell key encoding (used in inside/visited maps):
  ///   • Hex (r, c)  → r * cols + c              (range [0, rows*cols))
  ///   • Triangle id → rows*cols + index_in_ids  (range [rows*cols, ...))
  Set<int> _generateLoop(({List<int> ids, Map<int, List<int>> rep}) tri) {
    final int hexCount = rows * cols;
    final int triCount = tri.ids.length;
    final int total = hexCount + triCount;
    if (total == 0) return {};

    final Map<int, int> triIndex = {
      for (int i = 0; i < triCount; i++) tri.ids[i]: i
    };

    final List<bool> inside = List.filled(total, false);

    int hexKey(int r, int c) => r * cols + c;

    // Seed with a random hex (hex cells dominate, and starting from one
    // gives the growth a proper bipartite alternation).
    final int sr = _random.nextInt(rows);
    final int sc = _random.nextInt(cols);
    final int seed = hexKey(sr, sc);
    inside[seed] = true;

    final int targetSize =
        max(2, (total * (0.30 + _random.nextDouble() * 0.20)).round());
    int size = 1;
    int curKey = seed;

    final Set<int> frontier = {};
    for (final n in _cellNeighbors(curKey, tri, triIndex)) {
      frontier.add(n);
    }

    while (size < targetSize && frontier.isNotEmpty) {
      final List<int> neigh = _cellNeighbors(curKey, tri, triIndex)
        ..shuffle(_random);

      bool extended = false;
      for (final nKey in neigh) {
        if (inside[nKey]) continue;

        // Thin growth: don't add a cell with >1 inside neighbour.
        int insideAdj = 0;
        for (final nn in _cellNeighbors(nKey, tri, triIndex)) {
          if (inside[nn]) insideAdj++;
        }
        if (insideAdj > 1) continue;

        inside[nKey] = true;
        if (!_outsideConnected(inside, total, tri, triIndex)) {
          inside[nKey] = false;
          continue;
        }

        curKey = nKey;
        size++;
        extended = true;
        frontier.remove(nKey);
        for (final fn in _cellNeighbors(nKey, tri, triIndex)) {
          if (!inside[fn]) frontier.add(fn);
        }
        break;
      }

      if (!extended) {
        final List<int> fList = frontier.toList()..shuffle(_random);
        bool found = false;
        for (final fk in fList) {
          frontier.remove(fk);
          if (inside[fk]) continue;

          int insideAdj = 0;
          for (final nn in _cellNeighbors(fk, tri, triIndex)) {
            if (inside[nn]) insideAdj++;
          }
          if (insideAdj > 1) continue;

          inside[fk] = true;
          if (!_outsideConnected(inside, total, tri, triIndex)) {
            inside[fk] = false;
            continue;
          }

          curKey = fk;
          size++;
          found = true;
          for (final fn in _cellNeighbors(fk, tri, triIndex)) {
            if (!inside[fn]) frontier.add(fn);
          }
          break;
        }
        if (!found) break;
      }
    }

    return _extractBoundaryEdges(inside, tri, triIndex);
  }

  /// Bipartite cell neighbours by cell key.
  List<int> _cellNeighbors(int key,
      ({List<int> ids, Map<int, List<int>> rep}) tri,
      Map<int, int> triIndex) {
    final int hexCount = rows * cols;
    final List<int> out = [];
    if (key < hexCount) {
      final int r = key ~/ cols, c = key % cols;
      for (final tid in _hexNeighborTriIds(r, c)) {
        out.add(hexCount + triIndex[tid]!);
      }
    } else {
      final int idx = key - hexCount;
      final int triId = tri.ids[idx];
      final List<int> rep = tri.rep[triId]!;
      for (final h in _triHexNeighbors(rep[0], rep[1], rep[2])) {
        out.add(h[0] * cols + h[1]);
      }
    }
    return out;
  }

  /// True iff every outside cell can reach an outside cell with a missing
  /// neighbour (i.e. one that touches the grid exterior). For our finite
  /// grid we approximate "exterior" by: any cell with strictly fewer cell
  /// neighbours than the maximum possible (6 for hex, 3 for tri). Hexes
  /// at the rim and rim-touching triangles satisfy this.
  bool _outsideConnected(List<bool> inside, int total,
      ({List<int> ids, Map<int, List<int>> rep}) tri,
      Map<int, int> triIndex) {
    // Find a starter outside cell that is on the rim (a hex with <6
    // triangle neighbours, or a triangle with <3 hex neighbours).
    int start = -1;
    final int hexCount = rows * cols;
    for (int k = 0; k < total; k++) {
      if (inside[k]) continue;
      final int maxN = k < hexCount ? 6 : 3;
      if (_cellNeighbors(k, tri, triIndex).length < maxN) {
        start = k;
        break;
      }
    }
    if (start == -1) {
      // No outside rim cell — either no outside, or outside cells are all
      // strictly interior. All-inside is fine; otherwise it's a hole.
      for (int k = 0; k < total; k++) {
        if (!inside[k]) return false;
      }
      return true;
    }

    final List<bool> visited = List.filled(total, false);
    visited[start] = true;
    final Queue<int> queue = Queue()..add(start);
    int visitedCount = 1;
    while (queue.isNotEmpty) {
      final int k = queue.removeFirst();
      for (final n in _cellNeighbors(k, tri, triIndex)) {
        if (!inside[n] && !visited[n]) {
          visited[n] = true;
          queue.add(n);
          visitedCount++;
        }
      }
    }
    int outsideCount = 0;
    for (int k = 0; k < total; k++) {
      if (!inside[k]) outsideCount++;
    }
    return visitedCount == outsideCount;
  }

  /// Boundary edges = trihex edges separating an inside cell from the
  /// outside (or from "no cell at all" along the grid border).
  Set<int> _extractBoundaryEdges(List<bool> inside,
      ({List<int> ids, Map<int, List<int>> rep}) tri,
      Map<int, int> triIndex) {
    final Set<int> edges = {};
    final int hexCount = rows * cols;

    // Iterate hex cells. For each of their 6 edges, decide if it's
    // boundary by checking the neighbour triangle's inside status (or
    // treating absence as outside).
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int hk = r * cols + c;
        final List<int> hEdges = _hexCellEdges(r, c);
        final List<int> hv = _hexVertices(r, c);
        for (int i = 0; i < 6; i++) {
          final int vi = (i + 1) % 6;
          int neighborCellInside;
          if (_hasTriangleAt(r, c, vi)) {
            final int tid = hv[vi];
            final int tk = hexCount + triIndex[tid]!;
            neighborCellInside = inside[tk] ? 1 : 0;
          } else {
            neighborCellInside = 0; // outside the rows × cols region
          }
          final int meInside = inside[hk] ? 1 : 0;
          if (meInside != neighborCellInside) {
            edges.add(hEdges[i]);
          }
        }
      }
    }
    return edges;
  }

  /// Count active edges around every cell.
  void _computeSolution(
      TrihexPuzzle puzzle, ({List<int> ids, Map<int, List<int>> rep}) tri) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int count = 0;
        for (final e in _hexCellEdges(r, c)) {
          if (puzzle.activeEdges.contains(e)) count++;
        }
        puzzle.hexSolution[r][c] = count;
      }
    }
    for (final id in tri.ids) {
      final rep0 = tri.rep[id]!;
      int count = 0;
      for (final e in _triangleEdges(rep0[0], rep0[1], rep0[2])) {
        if (puzzle.activeEdges.contains(e)) count++;
      }
      puzzle.triSolution[id] = count;
    }
  }

  /// Reveal a fraction of clues based on difficulty. Hex and triangle
  /// cells are mixed and shuffled together so coverage is uniform.
  void _buildClue(TrihexPuzzle puzzle,
      ({List<int> ids, Map<int, List<int>> rep}) tri,
      Difficulty difficulty) {
    // Cell descriptor: kind=0 hex (r,c), kind=1 tri (triId).
    final List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([0, r, c]);
      }
    }
    for (final id in tri.ids) {
      cells.add([1, id, 0]);
    }
    cells.shuffle(_random);

    final int toReveal = (cells.length * difficulty.hintRatio).round();
    for (int j = 0; j < toReveal && j < cells.length; j++) {
      final c = cells[j];
      if (c[0] == 0) {
        puzzle.hexClue[c[1]][c[2]] = puzzle.hexSolution[c[1]][c[2]];
      } else {
        puzzle.triClue[c[1]] = puzzle.triSolution[c[1]] ?? 0;
      }
    }
  }
}
