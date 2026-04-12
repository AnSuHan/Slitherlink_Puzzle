// ignore_for_file: file_names
import 'dart:math';
import 'dart:collection';

import 'SlitherlinkGenerator.dart' show Difficulty;

/// Slitherlink puzzle on a hexagonal grid (offset coordinates, even-row offset).
///
/// Each hexagon has 6 edges and 6 vertices.
/// Clue numbers range 0-6.
class HexagonPuzzle {
  final int rows;
  final int cols;

  /// solution[r][c]: number of active edges around hexagon (0-6)
  late List<List<int>> solution;

  /// clue[r][c]: displayed hint (-1 = hidden, 0-6 = revealed)
  late List<List<int>> clue;

  /// Active edges stored as encoded vertex pairs
  late Set<int> activeEdges;

  HexagonPuzzle(this.rows, this.cols) {
    solution = List.generate(rows, (_) => List.filled(cols, 0));
    clue = List.generate(rows, (_) => List.filled(cols, -1));
    activeEdges = {};
  }

  /// Convert to edge format for the app.
  /// Format: for each cell (r,c), store 6 edge values (0 or 1)
  /// Edge order: top, topRight, bottomRight, bottom, bottomLeft, topLeft
  List<List<int>> toEdgeFormat() {
    List<List<int>> result = [];
    for (int r = 0; r < rows; r++) {
      List<int> rowEdges = [];
      for (int c = 0; c < cols; c++) {
        List<List<int>> edges = getEdgeVertices(r, c);
        for (var e in edges) {
          int code = HexagonGenerator.encodeEdgeStatic(e[0], e[1]);
          rowEdges.add(activeEdges.contains(code) ? 1 : 0);
        }
      }
      result.add(rowEdges);
    }
    return result;
  }

  /// Get 6 edge vertex pairs for hexagon at (r, c).
  /// Uses flat-top hexagonal grid with even-row offset.
  ///
  /// Vertex numbering: each hex has 6 unique vertices, but shared with neighbors.
  /// We use a global vertex index scheme:
  ///   For hex at (r, c), the 6 vertices (starting from top, clockwise):
  ///   v0=top, v1=topRight, v2=bottomRight, v3=bottom, v4=bottomLeft, v5=topLeft
  List<List<int>> getEdgeVertices(int r, int c) {
    List<int> v = HexagonGenerator.hexVertices(r, c, cols);
    return [
      [v[0], v[1]], // top edge
      [v[1], v[2]], // topRight edge
      [v[2], v[3]], // bottomRight edge
      [v[3], v[4]], // bottom edge
      [v[4], v[5]], // bottomLeft edge
      [v[5], v[0]], // topLeft edge
    ];
  }
}

/// Generates Slitherlink puzzles on a hexagonal grid.
class HexagonGenerator {
  final int rows;
  final int cols;
  final Random _random;

  HexagonGenerator(this.rows, this.cols, {int? seed})
      : _random = seed != null ? Random(seed) : Random();

  static int encodeEdgeStatic(int a, int b) {
    int lo = min(a, b);
    int hi = max(a, b);
    return lo * 100000 + hi;
  }

  int _encodeEdge(int a, int b) => encodeEdgeStatic(a, b);

  /// Compute the 6 vertex indices for hex at (r, c).
  /// Uses a systematic vertex numbering scheme.
  ///
  /// For flat-top hex in offset coordinates (even-row offset):
  /// Each vertex is shared by up to 3 hexagons.
  /// We assign unique vertex IDs based on position.
  ///
  /// Vertex layout per hex (flat-top):
  ///      v0
  ///   v5    v1
  ///   v4    v2
  ///      v3
  ///
  /// Global vertex indexing: row r has 2 vertex rows.
  /// Top vertices of hex row r: vRow = 2*r
  /// Bottom vertices of hex row r: vRow = 2*r + 1
  /// Each vertex row has (cols + 1) vertices, but offset rows shift by 0.5
  ///
  /// Simpler approach: assign each hex 2 unique vertices (top and bottom),
  /// share the 4 side vertices with neighbors.
  static List<int> hexVertices(int r, int c, int cols) {
    // Use a vertex grid where each hex contributes its top and bottom vertex.
    // Side vertices are shared between horizontal neighbors.
    //
    // Vertex scheme:
    // For hex (r, c), in even-row offset coordinates:
    // - Top vertex: unique to this hex
    // - Bottom vertex: unique to this hex
    // - TopLeft, TopRight: shared with hex above
    // - BottomLeft, BottomRight: shared with hex below
    //
    // Global index: Each hex row has 2 vertex sub-rows.
    // Sub-row 0 (side vertices): has (cols+1) vertices
    // Sub-row 1 (peak vertices): has cols vertices
    //
    // For hex row r:
    //   side row top: vertexRow = 2*r, indices 0..cols
    //   peak row: vertexRow = 2*r+1, indices 0..cols-1
    //   side row bottom: vertexRow = 2*(r+1), indices 0..cols

    int sideWidth = cols + 1;
    int peakWidth = cols;
    int rowStride = sideWidth + peakWidth; // vertices per hex row

    bool evenRow = r % 2 == 0;

    // Side vertices (top of this hex row)
    int sideBase = r * rowStride;
    // Peak vertices (top and bottom peaks)
    int peakBase = r * rowStride + sideWidth;
    // Side vertices (bottom of this hex row)
    int sideBaseBottom = (r + 1) * rowStride;

    int v0, v1, v2, v3, v4, v5;

    if (evenRow) {
      // Even row: no offset
      v0 = peakBase + c;                    // top peak
      v1 = sideBase + c + 1;               // top-right side
      v2 = sideBaseBottom + c + 1;          // bottom-right side
      v3 = peakBase + peakWidth + sideWidth + c; // bottom peak (next row's peak)
      v4 = sideBaseBottom + c;              // bottom-left side
      v5 = sideBase + c;                    // top-left side
    } else {
      // Odd row: offset by +0.5, so vertex sharing shifts
      v0 = peakBase + c;
      v1 = sideBase + c + 1;
      v2 = sideBaseBottom + c + 1;
      v3 = peakBase + peakWidth + sideWidth + c;
      v4 = sideBaseBottom + c;
      v5 = sideBase + c;
    }

    return [v0, v1, v2, v3, v4, v5];
  }

  /// Get the 6 edges of hex at (r, c)
  List<int> _hexEdges(int r, int c) {
    List<int> v = hexVertices(r, c, cols);
    return [
      _encodeEdge(v[0], v[1]),
      _encodeEdge(v[1], v[2]),
      _encodeEdge(v[2], v[3]),
      _encodeEdge(v[3], v[4]),
      _encodeEdge(v[4], v[5]),
      _encodeEdge(v[5], v[0]),
    ];
  }

  /// Get neighboring hexagons (offset coordinates, even-row offset)
  List<List<int>> _cellNeighbors(int r, int c) {
    List<List<int>> result = [];
    bool evenRow = r % 2 == 0;

    // 6 hex neighbors in offset coordinates
    List<List<int>> offsets;
    if (evenRow) {
      offsets = [
        [-1, -1], [-1, 0],  // top-left, top-right
        [0, -1], [0, 1],    // left, right
        [1, -1], [1, 0],    // bottom-left, bottom-right
      ];
    } else {
      offsets = [
        [-1, 0], [-1, 1],   // top-left, top-right
        [0, -1], [0, 1],    // left, right
        [1, 0], [1, 1],     // bottom-left, bottom-right
      ];
    }

    for (var o in offsets) {
      int nr = r + o[0], nc = c + o[1];
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        result.add([nr, nc]);
      }
    }
    return result;
  }

  /// Generate a complete puzzle
  HexagonPuzzle generate({Difficulty difficulty = Difficulty.normal}) {
    for (int attempt = 0; attempt < 1000; attempt++) {
      HexagonPuzzle puzzle = HexagonPuzzle(rows, cols);
      Set<int> edges = _generateLoop();
      if (edges.length < 6) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < 0.60) continue;

      _buildClue(puzzle, difficulty);
      return puzzle;
    }
    throw Exception('Failed to generate hexagon puzzle after 1000 attempts');
  }

  HexagonPuzzle generateSolution() {
    for (int attempt = 0; attempt < 1000; attempt++) {
      HexagonPuzzle puzzle = HexagonPuzzle(rows, cols);
      Set<int> edges = _generateLoop();
      if (edges.length < 6) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < 0.60) continue;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          puzzle.clue[r][c] = puzzle.solution[r][c];
        }
      }
      return puzzle;
    }
    throw Exception('Failed to generate hexagon puzzle after 1000 attempts');
  }

  double _cellCoverage(HexagonPuzzle puzzle) {
    int touched = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (puzzle.solution[r][c] > 0) touched++;
      }
    }
    return touched / (rows * cols);
  }

  /// Generate loop by growing simply-connected region
  Set<int> _generateLoop() {
    int totalCells = rows * cols;
    List<List<bool>> inside = List.generate(rows, (_) => List.filled(cols, false));

    int sr = _random.nextInt(rows);
    int sc = _random.nextInt(cols);
    inside[sr][sc] = true;

    int target = max(1, (totalCells * (0.25 + _random.nextDouble() * 0.20)).round());
    int size = 1;
    int curR = sr, curC = sc;

    Set<int> frontier = {};
    for (var n in _cellNeighbors(sr, sc)) {
      frontier.add(n[0] * cols + n[1]);
    }

    while (size < target && frontier.isNotEmpty) {
      List<List<int>> neighbors = _cellNeighbors(curR, curC);
      neighbors.shuffle(_random);

      bool extended = false;
      for (var n in neighbors) {
        int nr = n[0], nc = n[1];
        if (inside[nr][nc]) continue;

        int insideCount = 0;
        for (var nn in _cellNeighbors(nr, nc)) {
          if (inside[nn[0]][nn[1]]) insideCount++;
        }
        if (insideCount > 1) continue;

        inside[nr][nc] = true;
        if (!_outsideConnected(inside)) {
          inside[nr][nc] = false;
          continue;
        }

        curR = nr;
        curC = nc;
        size++;
        extended = true;
        frontier.remove(nr * cols + nc);
        for (var fn in _cellNeighbors(nr, nc)) {
          if (!inside[fn[0]][fn[1]]) {
            frontier.add(fn[0] * cols + fn[1]);
          }
        }
        break;
      }

      if (!extended) {
        var fList = frontier.toList();
        fList.shuffle(_random);
        bool found = false;
        for (int encoded in fList) {
          int r = encoded ~/ cols, c = encoded % cols;
          frontier.remove(encoded);
          if (inside[r][c]) continue;

          int insideCount = 0;
          for (var nn in _cellNeighbors(r, c)) {
            if (inside[nn[0]][nn[1]]) insideCount++;
          }
          if (insideCount > 1) continue;

          inside[r][c] = true;
          if (!_outsideConnected(inside)) {
            inside[r][c] = false;
            continue;
          }

          curR = r;
          curC = c;
          size++;
          found = true;
          for (var fn in _cellNeighbors(r, c)) {
            if (!inside[fn[0]][fn[1]]) {
              frontier.add(fn[0] * cols + fn[1]);
            }
          }
          break;
        }
        if (!found) break;
      }
    }

    return _extractBoundaryEdges(inside);
  }

  bool _outsideConnected(List<List<bool>> inside) {
    int startR = -1, startC = -1;

    for (int c = 0; c < cols && startR == -1; c++) {
      if (!inside[0][c]) { startR = 0; startC = c; }
      if (startR == -1 && !inside[rows - 1][c]) { startR = rows - 1; startC = c; }
    }
    for (int r = 0; r < rows && startR == -1; r++) {
      if (!inside[r][0]) { startR = r; startC = 0; }
      if (startR == -1 && !inside[r][cols - 1]) { startR = r; startC = cols - 1; }
    }

    if (startR == -1) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (!inside[r][c]) return false;
        }
      }
      return true;
    }

    List<List<bool>> visited = List.generate(rows, (_) => List.filled(cols, false));
    visited[startR][startC] = true;
    Queue<int> queue = Queue();
    queue.add(startR * cols + startC);
    int visitedCount = 1;

    while (queue.isNotEmpty) {
      int enc = queue.removeFirst();
      int r = enc ~/ cols, c = enc % cols;
      for (var n in _cellNeighbors(r, c)) {
        int nr = n[0], nc = n[1];
        if (!inside[nr][nc] && !visited[nr][nc]) {
          visited[nr][nc] = true;
          queue.add(nr * cols + nc);
          visitedCount++;
        }
      }
    }

    int outsideCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!inside[r][c]) outsideCount++;
      }
    }
    return visitedCount == outsideCount;
  }

  Set<int> _extractBoundaryEdges(List<List<bool>> inside) {
    Set<int> edges = {};

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!inside[r][c]) continue;

        List<int> hexEdges = _hexEdges(r, c);
        List<List<int>> neighbors = _cellNeighbors(r, c);

        for (int edgeCode in hexEdges) {
          bool isBoundary = true;
          for (var n in neighbors) {
            List<int> nEdges = _hexEdges(n[0], n[1]);
            if (nEdges.contains(edgeCode) && inside[n[0]][n[1]]) {
              isBoundary = false;
              break;
            }
          }
          if (isBoundary) {
            edges.add(edgeCode);
          }
        }
      }
    }

    return edges;
  }

  void _computeSolution(HexagonPuzzle puzzle) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int count = 0;
        List<int> hexEdges = _hexEdges(r, c);
        for (int e in hexEdges) {
          if (puzzle.activeEdges.contains(e)) count++;
        }
        puzzle.solution[r][c] = count;
      }
    }
  }

  void _buildClue(HexagonPuzzle puzzle, Difficulty difficulty) {
    int total = rows * cols;
    int toReveal = (total * difficulty.hintRatio).round();

    List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([r, c]);
      }
    }
    cells.shuffle(_random);

    for (int j = 0; j < toReveal && j < cells.length; j++) {
      puzzle.clue[cells[j][0]][cells[j][1]] = puzzle.solution[cells[j][0]][cells[j][1]];
    }
  }
}
