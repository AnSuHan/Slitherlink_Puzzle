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

/// Generates Slitherlink puzzles using Wilson's Loop-Erased Random Walk
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
    SlitherlinkPuzzle puzzle = SlitherlinkPuzzle(rows, cols);

    // Try up to 100 times to generate a valid loop
    for (int attempt = 0; attempt < 100; attempt++) {
      Set<int> edges = _generateLoop();
      if (edges.isEmpty) continue;

      _decodeEdges(puzzle, edges);

      if (_isValidLoop(puzzle)) {
        _computeSolution(puzzle);
        _buildClue(puzzle, difficulty);
        return puzzle;
      }

      // Reset for retry
      puzzle = SlitherlinkPuzzle(rows, cols);
    }

    throw Exception('Failed to generate a valid puzzle after 100 attempts');
  }

  /// Generate only the loop (solution edges) without clue masking
  SlitherlinkPuzzle generateSolution() {
    SlitherlinkPuzzle puzzle = SlitherlinkPuzzle(rows, cols);

    for (int attempt = 0; attempt < 100; attempt++) {
      Set<int> edges = _generateLoop();
      if (edges.isEmpty) continue;

      _decodeEdges(puzzle, edges);

      if (_isValidLoop(puzzle)) {
        _computeSolution(puzzle);
        // Set all clues visible (same as solution)
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            puzzle.clue[r][c] = puzzle.solution[r][c];
          }
        }
        return puzzle;
      }

      puzzle = SlitherlinkPuzzle(rows, cols);
    }

    throw Exception('Failed to generate a valid puzzle after 100 attempts');
  }

  /// Encode an edge between two node indices as a single int
  /// Uses node index a * 10000 + b (where a < b)
  int _encodeEdge(int a, int b) {
    int lo = min(a, b);
    int hi = max(a, b);
    return lo * 10000 + hi;
  }

  /// Get node index from (row, col) in the node grid
  int _nodeIndex(int r, int c) => r * _nodeCols + c;

  /// Get adjacent node indices for a given node
  List<int> _getNeighbors(int nodeIndex) {
    int r = nodeIndex ~/ _nodeCols;
    int c = nodeIndex % _nodeCols;
    List<int> neighbors = [];

    if (r > 0) neighbors.add(_nodeIndex(r - 1, c)); // up
    if (r < _nodeRows - 1) neighbors.add(_nodeIndex(r + 1, c)); // down
    if (c > 0) neighbors.add(_nodeIndex(r, c - 1)); // left
    if (c < _nodeCols - 1) neighbors.add(_nodeIndex(r, c + 1)); // right

    return neighbors;
  }

  /// Wilson's Loop-Erased Random Walk
  /// Returns a set of encoded edges forming a valid loop
  Set<int> _generateLoop() {
    int maxSteps = _totalNodes * 10;
    int startNode = _random.nextInt(_totalNodes);

    List<int> path = [startNode];
    Set<int> pathSet = {startNode};

    for (int step = 0; step < maxSteps; step++) {
      int current = path.last;
      List<int> neighbors = _getNeighbors(current);
      int next = neighbors[_random.nextInt(neighbors.length)];

      // If we return to start and path is long enough, we have a loop
      if (next == startNode && path.length >= 4) {
        path.add(next);
        // Convert path to edge set
        Set<int> edges = {};
        for (int i = 0; i < path.length - 1; i++) {
          edges.add(_encodeEdge(path[i], path[i + 1]));
        }
        return edges;
      }

      // Loop erasure: if we revisit a node in the path, erase the loop
      if (pathSet.contains(next) && next != startNode) {
        int idx = path.indexOf(next);
        // Remove everything after the first occurrence
        while (path.length > idx + 1) {
          pathSet.remove(path.removeLast());
        }
      } else {
        path.add(next);
        pathSet.add(next);
      }
    }

    return {}; // Failed to generate
  }

  /// Decode edge set into hEdge/vEdge arrays
  void _decodeEdges(SlitherlinkPuzzle puzzle, Set<int> edges) {
    for (int code in edges) {
      int a = code ~/ 10000;
      int b = code % 10000;
      int ra = a ~/ _nodeCols, ca = a % _nodeCols;
      int rb = b ~/ _nodeCols, cb = b % _nodeCols;

      if (ra == rb) {
        // Horizontal edge
        puzzle.hEdge[ra][min(ca, cb)] = true;
      } else {
        // Vertical edge
        puzzle.vEdge[min(ra, rb)][ca] = true;
      }
    }
  }

  /// Validate that edges form a single closed loop
  bool _isValidLoop(SlitherlinkPuzzle puzzle) {
    List<int> degree = List.filled(_totalNodes, 0);
    int edgeCount = 0;

    // Count degrees from horizontal edges
    for (int r = 0; r < _nodeRows; r++) {
      for (int c = 0; c < cols; c++) {
        if (puzzle.hEdge[r][c]) {
          degree[_nodeIndex(r, c)]++;
          degree[_nodeIndex(r, c + 1)]++;
          edgeCount++;
        }
      }
    }

    // Count degrees from vertical edges
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < _nodeCols; c++) {
        if (puzzle.vEdge[r][c]) {
          degree[_nodeIndex(r, c)]++;
          degree[_nodeIndex(r + 1, c)]++;
          edgeCount++;
        }
      }
    }

    // Condition 1: all active nodes must have degree 2
    for (int d in degree) {
      if (d != 0 && d != 2) return false;
    }

    // Condition 2: at least 4 edges
    if (edgeCount < 4) return false;

    // Condition 3: BFS - all degree-2 nodes must be in one connected component
    int startNode = -1;
    for (int i = 0; i < _totalNodes; i++) {
      if (degree[i] == 2) {
        startNode = i;
        break;
      }
    }
    if (startNode == -1) return false;

    Set<int> visited = {};
    Queue<int> queue = Queue();
    queue.add(startNode);
    visited.add(startNode);

    while (queue.isNotEmpty) {
      int node = queue.removeFirst();
      int r = node ~/ _nodeCols;
      int c = node % _nodeCols;

      // Check all 4 possible edges from this node
      // Up
      if (r > 0 && puzzle.vEdge[r - 1][c] && !visited.contains(_nodeIndex(r - 1, c))) {
        visited.add(_nodeIndex(r - 1, c));
        queue.add(_nodeIndex(r - 1, c));
      }
      // Down
      if (r < rows && puzzle.vEdge[r][c] && !visited.contains(_nodeIndex(r + 1, c))) {
        visited.add(_nodeIndex(r + 1, c));
        queue.add(_nodeIndex(r + 1, c));
      }
      // Left
      if (c > 0 && puzzle.hEdge[r][c - 1] && !visited.contains(_nodeIndex(r, c - 1))) {
        visited.add(_nodeIndex(r, c - 1));
        queue.add(_nodeIndex(r, c - 1));
      }
      // Right
      if (c < cols && puzzle.hEdge[r][c] && !visited.contains(_nodeIndex(r, c + 1))) {
        visited.add(_nodeIndex(r, c + 1));
        queue.add(_nodeIndex(r, c + 1));
      }
    }

    // All degree-2 nodes must be visited
    for (int i = 0; i < _totalNodes; i++) {
      if (degree[i] == 2 && !visited.contains(i)) return false;
    }

    return true;
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

    // Create shuffled cell list
    List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([r, c]);
      }
    }
    cells.shuffle(_random);

    // Reveal first `toReveal` cells
    for (int i = 0; i < toReveal && i < cells.length; i++) {
      puzzle.clue[cells[i][0]][cells[i][1]] = puzzle.solution[cells[i][0]][cells[i][1]];
    }
  }
}
