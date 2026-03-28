import 'dart:convert';
import 'dart:io';

void main() {
  final data = jsonDecode(File('lib/Answer/Square_generate.json').readAsStringSync()) as Map<String, dynamic>;
  for (final entry in data.entries) {
    final edges = entry.value as List;
    int activeEdges = 0;
    for (final row in edges) {
      for (final v in row as List) {
        if (v == 1) activeEdges++;
      }
    }
    final parts = entry.key.split('_');
    final sizeParts = parts[1].split('x');
    int rows = int.parse(sizeParts[0]);
    int cols = int.parse(sizeParts[1]);
    int totalCells = rows * cols;

    int touchedCells = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int count = 0;
        if ((edges[2*r] as List)[c] == 1) count++;
        if ((edges[2*(r+1)] as List)[c] == 1) count++;
        if ((edges[2*r+1] as List)[c] == 1) count++;
        if ((edges[2*r+1] as List)[c+1] == 1) count++;
        if (count > 0) touchedCells++;
      }
    }
    print('${entry.key}: $activeEdges edges, $touchedCells/$totalCells cells touched (${(touchedCells*100/totalCells).round()}%)');
  }
}
