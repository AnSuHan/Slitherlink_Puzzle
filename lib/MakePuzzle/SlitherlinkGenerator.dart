// ignore_for_file: file_names
import 'dart:math';
import 'dart:collection';

/// Difficulty levels for puzzle generation
enum Difficulty {
  easy(0.80),
  normal(0.55),
  hard(0.35);

  final double hintRatio;
  const Difficulty(this.hintRatio);
}

/// Slitherlink puzzle data holding edges, solution, and clues
class SlitherlinkPuzzle {
  final int rows;
  final int cols;

  /// hEdge[r][c]: horizontal edge between node(r,c) and node(r,c+1)
  /// Size: (rows+1) x cols
  late List<List<bool>> hEdge;

  /// vEdge[r][c]: vertical edge between node(r,c) and node(r+1,c)
  /// Size: rows x (cols+1)
  late List<List<bool>> vEdge;

  /// solution[r][c]: number of active edges around cell (r,c), range 0~4
  late List<List<int>> solution;

  /// clue[r][c]: displayed hint (-1 = hidden, 0~4 = revealed)
  late List<List<int>> clue;

  SlitherlinkPuzzle(this.rows, this.cols) {
    hEdge = List.generate(rows + 1, (_) => List.filled(cols, false));
    vEdge = List.generate(rows, (_) => List.filled(cols + 1, false));
    solution = List.generate(rows, (_) => List.filled(cols, 0));
    clue = List.generate(rows, (_) => List.filled(cols, -1));
  }

  /// Convert to the app's edge format: List<List<int>>
  /// Even rows (0,2,...,2*rows): horizontal edges, length = cols
  /// Odd rows (1,3,...,2*rows-1): vertical edges, length = cols+1
  List<List<int>> toEdgeFormat() {
    List<List<int>> result = [];
    for (int i = 0; i <= 2 * rows; i++) {
      if (i % 2 == 0) {
        // horizontal edge row
        int hr = i ~/ 2;
        result.add(hEdge[hr].map((b) => b ? 1 : 0).toList());
      } else {
        // vertical edge row
        int vr = i ~/ 2;
        result.add(vEdge[vr].map((b) => b ? 1 : 0).toList());
      }
    }
    return result;
  }
}

/// Generates Slitherlink puzzles by growing a random simply-connected region
/// and using its boundary as the loop.
class SlitherlinkGenerator {
  final int rows;
  final int cols;
  final Random _random;

  int get _nodeRows => rows + 1;
  int get _nodeCols => cols + 1;
  int get _totalNodes => _nodeRows * _nodeCols;

  SlitherlinkGenerator(this.rows, this.cols, {int? seed})
      : _random = seed != null ? Random(seed) : Random();

  /// Generate a complete puzzle with the given difficulty
  SlitherlinkPuzzle generate({Difficulty difficulty = Difficulty.normal}) {
    for (int attempt = 0; attempt < 1000; attempt++) {
      SlitherlinkPuzzle puzzle = SlitherlinkPuzzle(rows, cols);
      Set<int> edges = _generateLoop();
      if (edges.length < 4) continue;

      _decodeEdges(puzzle, edges);
      _computeSolution(puzzle);

      // Require at least 70% cell coverage (cells touched by the loop)
      if (_cellCoverage(puzzle) < 0.90) continue;

      _buildClue(puzzle, difficulty);
      return puzzle;
    }
    throw Exception('Failed to generate a valid puzzle after 300 attempts');
  }

  /// Generate only the loop (solution edges) without clue masking
  SlitherlinkPuzzle generateSolution() {
    for (int attempt = 0; attempt < 1000; attempt++) {
      SlitherlinkPuzzle puzzle = SlitherlinkPuzzle(rows, cols);
      Set<int> edges = _generateLoop();
      if (edges.length < 4) continue;

      _decodeEdges(puzzle, edges);
      _computeSolution(puzzle);

      if (_cellCoverage(puzzle) < 0.90) continue;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          puzzle.clue[r][c] = puzzle.solution[r][c];
        }
      }
      return puzzle;
    }
    throw Exception('Failed to generate a valid puzzle after 300 attempts');
  }

  /// Calculate fraction of cells touched by at least one edge
  double _cellCoverage(SlitherlinkPuzzle puzzle) {
    int touched = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (puzzle.solution[r][c] > 0) touched++;
      }
    }
    return touched / (rows * cols);
  }

  int _encodeEdge(int a, int b) {
    int lo = min(a, b);
    int hi = max(a, b);
    return lo * 10000 + hi;
  }

  int _nodeIndex(int r, int c) => r * _nodeCols + c;

  /// Generate a random single closed loop by growing a simply-connected region.
  /// Uses a random walk that prefers thin, winding growth for high cell coverage.
  Set<int> _generateLoop() {
    List<List<bool>> inside = List.generate(rows, (_) => List.filled(cols, false));

    // Random starting cell
    int sr = _random.nextInt(rows);
    int sc = _random.nextInt(cols);
    inside[sr][sc] = true;

    // Target: 30-50% of cells inside as a thin snake path
    int total = rows * cols;
    int target = max(1, (total * (0.30 + _random.nextDouble() * 0.20)).round());

    // Snake-like random walk: only extend to cells with at most 1 inside
    // neighbor, creating a 1-cell-wide winding path for maximum coverage.
    int curR = sr, curC = sc;
    int size = 1;

    Set<int> frontier = {};
    for (var n in _cellNeighbors(sr, sc)) {
      frontier.add(n[0] * cols + n[1]);
    }

    while (size < target && frontier.isNotEmpty) {
      // Try to extend from current position
      List<List<int>> neighbors = _cellNeighbors(curR, curC);
      neighbors.shuffle(_random);

      bool extended = false;
      for (var n in neighbors) {
        int nr = n[0], nc = n[1];
        if (inside[nr][nc]) continue;

        // Only extend to cells with at most 1 inside neighbor (thin path)
        int insideNeighborCount = 0;
        for (var nn in _cellNeighbors(nr, nc)) {
          if (inside[nn[0]][nn[1]]) insideNeighborCount++;
        }
        if (insideNeighborCount > 1) continue;

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
        // Stuck - pick a random thin frontier cell
        var fList = frontier.toList();
        fList.shuffle(_random);

        bool found = false;
        for (int encoded in fList) {
          int r = encoded ~/ cols, c = encoded % cols;
          frontier.remove(encoded);
          if (inside[r][c]) continue;

          int insideNeighborCount = 0;
          for (var nn in _cellNeighbors(r, c)) {
            if (inside[nn[0]][nn[1]]) insideNeighborCount++;
          }
          if (insideNeighborCount > 1) continue;

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

  /// Get neighboring cell coordinates
  List<List<int>> _cellNeighbors(int r, int c) {
    List<List<int>> result = [];
    if (r > 0) result.add([r - 1, c]);
    if (r < rows - 1) result.add([r + 1, c]);
    if (c > 0) result.add([r, c - 1]);
    if (c < cols - 1) result.add([r, c + 1]);
    return result;
  }

  /// Check that all outside cells can reach the grid border.
  /// If an outside cell is surrounded by inside cells, we have a hole.
  bool _outsideConnected(List<List<bool>> inside) {
    // Find any outside cell on the border to start BFS
    int startR = -1, startC = -1;

    // Check border rows/cols for an outside cell
    for (int c = 0; c < cols && startR == -1; c++) {
      if (!inside[0][c]) { startR = 0; startC = c; }
      if (startR == -1 && !inside[rows - 1][c]) { startR = rows - 1; startC = c; }
    }
    for (int r = 0; r < rows && startR == -1; r++) {
      if (!inside[r][0]) { startR = r; startC = 0; }
      if (startR == -1 && !inside[r][cols - 1]) { startR = r; startC = cols - 1; }
    }

    if (startR == -1) {
      // All border cells are inside. Check if any outside cells exist at all.
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (!inside[r][c]) return false; // Unreachable outside cell = hole
        }
      }
      return true; // All cells inside, no holes
    }

    // BFS from the border outside cell
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

    // Count total outside cells
    int outsideCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!inside[r][c]) outsideCount++;
      }
    }

    return visitedCount == outsideCount;
  }

  /// Extract boundary edges: edges between inside and outside cells.
  /// These form a single closed loop when the inside region is simply connected.
  Set<int> _extractBoundaryEdges(List<List<bool>> inside) {
    Set<int> edges = {};

    // Horizontal edges: between cell rows r-1 and r
    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c < cols; c++) {
        bool above = (r > 0) ? inside[r - 1][c] : false;
        bool below = (r < rows) ? inside[r][c] : false;
        if (above != below) {
          edges.add(_encodeEdge(_nodeIndex(r, c), _nodeIndex(r, c + 1)));
        }
      }
    }

    // Vertical edges: between cell cols c-1 and c
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c <= cols; c++) {
        bool left = (c > 0) ? inside[r][c - 1] : false;
        bool right = (c < cols) ? inside[r][c] : false;
        if (left != right) {
          edges.add(_encodeEdge(_nodeIndex(r, c), _nodeIndex(r + 1, c)));
        }
      }
    }

    return edges;
  }

  /// Decode edge set into hEdge/vEdge arrays
  void _decodeEdges(SlitherlinkPuzzle puzzle, Set<int> edges) {
    for (int code in edges) {
      int a = code ~/ 10000;
      int b = code % 10000;
      int ra = a ~/ _nodeCols, ca = a % _nodeCols;
      int rb = b ~/ _nodeCols, cb = b % _nodeCols;

      if (ra == rb) {
        puzzle.hEdge[ra][min(ca, cb)] = true;
      } else {
        puzzle.vEdge[min(ra, rb)][ca] = true;
      }
    }
  }

  /// Compute solution: count active edges around each cell
  void _computeSolution(SlitherlinkPuzzle puzzle) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int count = 0;
        if (puzzle.hEdge[r][c]) count++;     // top
        if (puzzle.hEdge[r + 1][c]) count++; // bottom
        if (puzzle.vEdge[r][c]) count++;     // left
        if (puzzle.vEdge[r][c + 1]) count++; // right
        puzzle.solution[r][c] = count;
      }
    }
  }

  /// Build clues by revealing a fraction of cells based on difficulty
  void _buildClue(SlitherlinkPuzzle puzzle, Difficulty difficulty) {
    int total = rows * cols;
    int toReveal = (total * difficulty.hintRatio).round();

    List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([r, c]);
      }
    }
    cells.shuffle(_random);

    for (int i = 0; i < toReveal && i < cells.length; i++) {
      puzzle.clue[cells[i][0]][cells[i][1]] = puzzle.solution[cells[i][0]][cells[i][1]];
    }
  }
}
