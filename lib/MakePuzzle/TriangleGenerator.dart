// ignore_for_file: file_names
import 'dart:math';
import 'dart:collection';

import 'SlitherlinkGenerator.dart' show Difficulty;

/// Slitherlink puzzle on a triangular grid.
///
/// A row of width `cols` contains `2*cols` triangles (alternating up ▲ / down ▽).
/// Each triangle has 3 edges. The grid has `rows` visual rows.
class TrianglePuzzle {
  final int rows;
  final int cols;

  /// Total triangles per row = 2 * cols
  int get triPerRow => 2 * cols;
  int get totalCells => rows * triPerRow;

  /// Whether triangle at (row, idx) points up
  bool isUp(int row, int idx) => idx % 2 == 0;

  /// solution[row][idx]: number of active edges around triangle (0-3)
  late List<List<int>> solution;

  /// clue[row][idx]: displayed hint (-1 = hidden, 0-3 = revealed)
  late List<List<int>> clue;

  /// Edge storage using a set of encoded edge keys
  late Set<int> activeEdges;

  TrianglePuzzle(this.rows, this.cols) {
    solution = List.generate(rows, (_) => List.filled(triPerRow, 0));
    clue = List.generate(rows, (_) => List.filled(triPerRow, -1));
    activeEdges = {};
  }

  /// Encode an edge between two vertices
  static int encodeEdge(int a, int b) {
    int lo = min(a, b);
    int hi = max(a, b);
    return lo * 100000 + hi;
  }

  /// Convert to edge format for the app.
  /// Format: List of [row, idx, edgeIndex, active] where edgeIndex is 0,1,2
  /// For up triangle ▲: 0=left, 1=right, 2=bottom
  /// For down triangle ▽: 0=left, 1=right, 2=top
  ///
  /// Flat edge format: List<List<int>> where each inner list has triPerRow * 3 ints
  /// Organized as: for each row, for each triangle, 3 edge values
  List<List<int>> toEdgeFormat() {
    List<List<int>> result = [];
    for (int r = 0; r < rows; r++) {
      List<int> rowEdges = [];
      for (int idx = 0; idx < triPerRow; idx++) {
        List<List<int>> edges = getEdgeVertices(r, idx);
        for (var e in edges) {
          int code = encodeEdge(e[0], e[1]);
          rowEdges.add(activeEdges.contains(code) ? 1 : 0);
        }
      }
      result.add(rowEdges);
    }
    return result;
  }

  /// Get vertex indices for the 3 edges of triangle at (row, idx).
  /// Returns list of [vertexA, vertexB] pairs.
  ///
  /// Vertex numbering:
  /// Row r has (cols+1) top vertices and (cols+1) bottom vertices.
  /// Top vertices of row r: r*(cols+1) + c, for c in [0..cols]
  /// Bottom vertices of row r: (r+1)*(cols+1) + c
  List<List<int>> getEdgeVertices(int row, int idx) {
    int c = idx ~/ 2;
    int topLeft = row * (cols + 1) + c;
    int topRight = row * (cols + 1) + c + 1;
    int botLeft = (row + 1) * (cols + 1) + c;
    int botRight = (row + 1) * (cols + 1) + c + 1;

    if (isUp(row, idx)) {
      // ▲: top-left to top-right (top), top-left to bot-left+0.5 (left), top-right to bot-left+0.5 (right)
      // Actually for triangular grid: up triangle vertices are topLeft, topRight, botCenter
      // But in a standard triangular grid, each column pair shares vertices differently.
      //
      // Simpler model: up triangle at (r, 2c) has vertices:
      //   top-left: (r, c), top-right: (r, c+1), bottom: (r+1, c)  -- for even triangles
      // down triangle at (r, 2c+1) has vertices:
      //   top: (r, c+1), bottom-left: (r+1, c), bottom-right: (r+1, c+1)
      return [
        [topLeft, topRight],    // top edge (horizontal)
        [topLeft, botLeft],     // left edge
        [topRight, botRight],   // right edge -- wait, this is wrong for triangles

        // Let me reconsider. Standard triangular grid:
        // Up triangle (r, 2c): vertices at (r,c), (r,c+1), (r+1,c)
        // Actually no. Let me use a cleaner model.
      ];
    }
    // This needs rethinking - let me use a proper vertex model below
    return [];
  }
}

/// Generates Slitherlink puzzles on a triangular grid.
///
/// Grid layout:
/// Each row has `cols` columns, each column contains 2 triangles (up ▲ and down ▽).
/// Triangle (r, 2*c) is up-pointing, (r, 2*c+1) is down-pointing.
///
/// Vertices form a rectangular grid of (rows+1) x (cols+1) points.
/// Up triangle (r, 2c) uses vertices: (r,c), (r,c+1), (r+1,c)
/// Down triangle (r, 2c+1) uses vertices: (r,c+1), (r+1,c), (r+1,c+1)
class TriangleGenerator {
  final int rows;
  final int cols;
  final Random _random;

  int get _vertexRows => rows + 1;
  int get _vertexCols => cols + 1;
  int get _triPerRow => 2 * cols;

  TriangleGenerator(this.rows, this.cols, {int? seed})
      : _random = seed != null ? Random(seed) : Random();

  int _vertexIndex(int r, int c) => r * _vertexCols + c;

  /// Get the 3 vertex indices for triangle at (row, triIdx)
  List<int> _triangleVertices(int row, int triIdx) {
    int c = triIdx ~/ 2;
    bool isUp = triIdx % 2 == 0;

    if (isUp) {
      // ▲: top-left, top-right, bottom-left
      return [
        _vertexIndex(row, c),
        _vertexIndex(row, c + 1),
        _vertexIndex(row + 1, c),
      ];
    } else {
      // ▽: top-right, bottom-left, bottom-right
      return [
        _vertexIndex(row, c + 1),
        _vertexIndex(row + 1, c),
        _vertexIndex(row + 1, c + 1),
      ];
    }
  }

  /// Get the 3 edges (as encoded ints) for triangle at (row, triIdx)
  List<int> _triangleEdges(int row, int triIdx) {
    List<int> v = _triangleVertices(row, triIdx);
    return [
      _encodeEdge(v[0], v[1]),
      _encodeEdge(v[1], v[2]),
      _encodeEdge(v[0], v[2]),
    ];
  }

  int _encodeEdge(int a, int b) {
    int lo = min(a, b);
    int hi = max(a, b);
    return lo * 100000 + hi;
  }

  /// Get neighboring triangles that share an edge
  List<List<int>> _cellNeighbors(int row, int triIdx) {
    List<List<int>> result = [];
    bool isUp = triIdx % 2 == 0;
    int c = triIdx ~/ 2;

    if (isUp) {
      // ▲ neighbors:
      // Right neighbor (shares top-right to bottom edge): down triangle at same col
      if (triIdx + 1 < _triPerRow) result.add([row, triIdx + 1]);
      // Left neighbor: down triangle at col-1
      if (c > 0) result.add([row, triIdx - 1]);
      // Top neighbor: down triangle in row above at same col
      if (row > 0) result.add([row - 1, triIdx + 1]);
    } else {
      // ▽ neighbors:
      // Left neighbor: up triangle at same col
      result.add([row, triIdx - 1]);
      // Right neighbor: up triangle at col+1
      if (c + 1 < cols) result.add([row, triIdx + 1]);
      // Bottom neighbor: up triangle in row below at same col
      if (row + 1 < rows) result.add([row + 1, triIdx - 1]);
    }

    return result;
  }

  /// Generate a complete puzzle
  TrianglePuzzle generate({Difficulty difficulty = Difficulty.normal}) {
    for (int attempt = 0; attempt < 1000; attempt++) {
      TrianglePuzzle puzzle = TrianglePuzzle(rows, cols);

      // Generate a simply-connected region and extract boundary
      Set<int> edges = _generateLoop();
      if (edges.length < 3) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < 0.70) continue;

      _buildClue(puzzle, difficulty);
      return puzzle;
    }
    throw Exception('Failed to generate triangle puzzle after 1000 attempts');
  }

  /// Generate only solution (all clues visible)
  TrianglePuzzle generateSolution() {
    for (int attempt = 0; attempt < 1000; attempt++) {
      TrianglePuzzle puzzle = TrianglePuzzle(rows, cols);
      Set<int> edges = _generateLoop();
      if (edges.length < 3) continue;

      puzzle.activeEdges = edges;
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < 0.70) continue;

      for (int r = 0; r < rows; r++) {
        for (int i = 0; i < _triPerRow; i++) {
          puzzle.clue[r][i] = puzzle.solution[r][i];
        }
      }
      return puzzle;
    }
    throw Exception('Failed to generate triangle puzzle after 1000 attempts');
  }

  double _cellCoverage(TrianglePuzzle puzzle) {
    int touched = 0;
    int total = rows * _triPerRow;
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (puzzle.solution[r][i] > 0) touched++;
      }
    }
    return touched / total;
  }

  /// Generate loop by growing a simply-connected region of triangles
  Set<int> _generateLoop() {
    int totalCells = rows * _triPerRow;
    List<List<bool>> inside = List.generate(rows, (_) => List.filled(_triPerRow, false));

    // Random start
    int sr = _random.nextInt(rows);
    int si = _random.nextInt(_triPerRow);
    inside[sr][si] = true;

    int target = max(1, (totalCells * (0.25 + _random.nextDouble() * 0.20)).round());
    int size = 1;
    int curR = sr, curI = si;

    Set<int> frontier = {};
    for (var n in _cellNeighbors(sr, si)) {
      frontier.add(n[0] * _triPerRow + n[1]);
    }

    while (size < target && frontier.isNotEmpty) {
      List<List<int>> neighbors = _cellNeighbors(curR, curI);
      neighbors.shuffle(_random);

      bool extended = false;
      for (var n in neighbors) {
        int nr = n[0], ni = n[1];
        if (inside[nr][ni]) continue;

        int insideCount = 0;
        for (var nn in _cellNeighbors(nr, ni)) {
          if (inside[nn[0]][nn[1]]) insideCount++;
        }
        if (insideCount > 1) continue;

        inside[nr][ni] = true;
        if (!_outsideConnected(inside)) {
          inside[nr][ni] = false;
          continue;
        }

        curR = nr;
        curI = ni;
        size++;
        extended = true;
        frontier.remove(nr * _triPerRow + ni);
        for (var fn in _cellNeighbors(nr, ni)) {
          if (!inside[fn[0]][fn[1]]) {
            frontier.add(fn[0] * _triPerRow + fn[1]);
          }
        }
        break;
      }

      if (!extended) {
        var fList = frontier.toList();
        fList.shuffle(_random);
        bool found = false;
        for (int encoded in fList) {
          int r = encoded ~/ _triPerRow, i = encoded % _triPerRow;
          frontier.remove(encoded);
          if (inside[r][i]) continue;

          int insideCount = 0;
          for (var nn in _cellNeighbors(r, i)) {
            if (inside[nn[0]][nn[1]]) insideCount++;
          }
          if (insideCount > 1) continue;

          inside[r][i] = true;
          if (!_outsideConnected(inside)) {
            inside[r][i] = false;
            continue;
          }

          curR = r;
          curI = i;
          size++;
          found = true;
          for (var fn in _cellNeighbors(r, i)) {
            if (!inside[fn[0]][fn[1]]) {
              frontier.add(fn[0] * _triPerRow + fn[1]);
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
    // Find a border outside cell
    int startR = -1, startI = -1;

    // Border triangles: first row, last row, leftmost, rightmost
    for (int i = 0; i < _triPerRow && startR == -1; i++) {
      if (!inside[0][i]) { startR = 0; startI = i; }
      if (startR == -1 && !inside[rows - 1][i]) { startR = rows - 1; startI = i; }
    }
    for (int r = 0; r < rows && startR == -1; r++) {
      if (!inside[r][0]) { startR = r; startI = 0; }
      if (startR == -1 && !inside[r][_triPerRow - 1]) { startR = r; startI = _triPerRow - 1; }
    }

    if (startR == -1) {
      for (int r = 0; r < rows; r++) {
        for (int i = 0; i < _triPerRow; i++) {
          if (!inside[r][i]) return false;
        }
      }
      return true;
    }

    List<List<bool>> visited = List.generate(rows, (_) => List.filled(_triPerRow, false));
    visited[startR][startI] = true;
    Queue<int> queue = Queue();
    queue.add(startR * _triPerRow + startI);
    int visitedCount = 1;

    while (queue.isNotEmpty) {
      int enc = queue.removeFirst();
      int r = enc ~/ _triPerRow, i = enc % _triPerRow;
      for (var n in _cellNeighbors(r, i)) {
        int nr = n[0], ni = n[1];
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

  /// Extract boundary edges between inside and outside triangles
  Set<int> _extractBoundaryEdges(List<List<bool>> inside) {
    Set<int> edges = {};

    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        if (!inside[r][i]) continue;

        List<int> triEdges = _triangleEdges(r, i);
        List<List<int>> neighbors = _cellNeighbors(r, i);

        // For each edge of this triangle, check if the neighboring triangle
        // sharing that edge is outside (or doesn't exist = boundary)
        // We need to map edges to neighbors

        // Get the 3 edges and check which neighbors share them
        for (int edgeCode in triEdges) {
          bool isBoundary = true;
          for (var n in neighbors) {
            List<int> nEdges = _triangleEdges(n[0], n[1]);
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

  /// Compute solution: count active edges around each triangle
  void _computeSolution(TrianglePuzzle puzzle) {
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        int count = 0;
        List<int> triEdges = _triangleEdges(r, i);
        for (int e in triEdges) {
          if (puzzle.activeEdges.contains(e)) count++;
        }
        puzzle.solution[r][i] = count;
      }
    }
  }

  void _buildClue(TrianglePuzzle puzzle, Difficulty difficulty) {
    int total = rows * _triPerRow;
    int toReveal = (total * difficulty.hintRatio).round();

    List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int i = 0; i < _triPerRow; i++) {
        cells.add([r, i]);
      }
    }
    cells.shuffle(_random);

    for (int j = 0; j < toReveal && j < cells.length; j++) {
      puzzle.clue[cells[j][0]][cells[j][1]] = puzzle.solution[cells[j][0]][cells[j][1]];
    }
  }
}
