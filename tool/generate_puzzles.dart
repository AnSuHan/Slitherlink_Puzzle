/// Pre-generates Slitherlink puzzles and saves them as JSON asset files.
/// Run: dart run tool/generate_puzzles.dart
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class SlitherlinkPuzzle {
  final int rows, cols;
  late List<List<bool>> hEdge;
  late List<List<bool>> vEdge;

  SlitherlinkPuzzle(this.rows, this.cols) {
    hEdge = List.generate(rows + 1, (_) => List.filled(cols, false));
    vEdge = List.generate(rows, (_) => List.filled(cols + 1, false));
  }

  List<List<int>> toEdgeFormat() {
    List<List<int>> result = [];
    for (int i = 0; i <= 2 * rows; i++) {
      if (i % 2 == 0) {
        int hr = i ~/ 2;
        result.add(hEdge[hr].map((b) => b ? 1 : 0).toList());
      } else {
        int vr = i ~/ 2;
        result.add(vEdge[vr].map((b) => b ? 1 : 0).toList());
      }
    }
    return result;
  }
}

class SlitherlinkGenerator {
  final int rows, cols;
  final Random _random;
  int get _nodeCols => cols + 1;

  SlitherlinkGenerator(this.rows, this.cols, {int? seed})
      : _random = seed != null ? Random(seed) : Random();

  int _encodeEdge(int a, int b) => min(a, b) * 10000 + max(a, b);
  int _nodeIndex(int r, int c) => r * _nodeCols + c;

  List<List<int>> _cellNeighbors(int r, int c) {
    List<List<int>> result = [];
    if (r > 0) result.add([r - 1, c]);
    if (r < rows - 1) result.add([r + 1, c]);
    if (c > 0) result.add([r, c - 1]);
    if (c < cols - 1) result.add([r, c + 1]);
    return result;
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
    for (int r = 0; r <= rows; r++) {
      for (int c = 0; c < cols; c++) {
        bool above = (r > 0) ? inside[r - 1][c] : false;
        bool below = (r < rows) ? inside[r][c] : false;
        if (above != below) {
          edges.add(_encodeEdge(_nodeIndex(r, c), _nodeIndex(r, c + 1)));
        }
      }
    }
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

  Set<int> _generateLoop() {
    List<List<bool>> inside = List.generate(rows, (_) => List.filled(cols, false));
    int sr = _random.nextInt(rows);
    int sc = _random.nextInt(cols);
    inside[sr][sc] = true;

    int total = rows * cols;
    int target = max(1, (total * (0.35 + _random.nextDouble() * 0.30)).round());

    List<int> stack = [];
    for (var n in _cellNeighbors(sr, sc)) {
      stack.add(n[0] * cols + n[1]);
    }
    stack.shuffle(_random);

    int size = 1;
    int stepsSinceShuffle = 0;
    while (size < target && stack.isNotEmpty) {
      stepsSinceShuffle++;
      if (stepsSinceShuffle > 3 + _random.nextInt(5)) {
        stack.shuffle(_random);
        stepsSinceShuffle = 0;
      }

      int encoded = stack.removeLast();
      int r = encoded ~/ cols, c = encoded % cols;
      if (inside[r][c]) continue;

      inside[r][c] = true;
      if (!_outsideConnected(inside)) {
        inside[r][c] = false;
        continue;
      }

      size++;
      List<int> neighbors = [];
      for (var n in _cellNeighbors(r, c)) {
        if (!inside[n[0]][n[1]]) {
          neighbors.add(n[0] * cols + n[1]);
        }
      }
      neighbors.shuffle(_random);
      stack.addAll(neighbors);
    }

    return _extractBoundaryEdges(inside);
  }

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

  SlitherlinkPuzzle generate() {
    for (int attempt = 0; attempt < 300; attempt++) {
      SlitherlinkPuzzle puzzle = SlitherlinkPuzzle(rows, cols);
      Set<int> edges = _generateLoop();
      if (edges.length < 4) continue;
      _decodeEdges(puzzle, edges);
      return puzzle;
    }
    throw Exception('Failed to generate a valid puzzle after 300 attempts');
  }
}

void main() {
  final Map<String, int> sizesAndCounts = {
    '5x5': 3,
    '7x7': 3,
    '10x10': 3,
    '15x15': 2,
    '20x20': 2,
  };

  Map<String, dynamic> allPuzzles = {};

  for (final entry in sizesAndCounts.entries) {
    final parts = entry.key.split('x');
    final rows = int.parse(parts[0]);
    final cols = int.parse(parts[1]);
    final count = entry.value;

    print('Generating $count puzzles for ${rows}x$cols...');

    for (int i = 0; i < count; i++) {
      final generator = SlitherlinkGenerator(rows, cols);
      try {
        final puzzle = generator.generate();
        final key = 'generate_${rows}x${cols}_$i';
        allPuzzles[key] = puzzle.toEdgeFormat();
        print('  [$key] done');
      } catch (e) {
        print('  Failed to generate ${rows}x$cols #$i: $e');
      }
    }
  }

  final outPath = 'lib/Answer/Square_generate.json';
  final jsonStr = const JsonEncoder.withIndent('  ').convert(allPuzzles);
  File(outPath).writeAsStringSync(jsonStr);
  print('\nWrote ${allPuzzles.length} puzzles to $outPath');
}
