// ignore_for_file: file_names
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../Platform/ExtractData.dart'
if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import 'SlitherlinkGenerator.dart';

/// Manages pre-generated puzzle cache for instant loading.
/// - Loads bundled puzzles from assets on first use
/// - After consuming a puzzle, generates a replacement in the background
/// - Stores cached puzzles in local storage
class PuzzleCache {
  static PuzzleCache? _instance;
  static PuzzleCache get instance => _instance ??= PuzzleCache._();

  PuzzleCache._();

  // In-memory cache: "5x5" -> [puzzle1, puzzle2, ...]
  final Map<String, List<List<List<int>>>> _cache = {};
  bool _assetLoaded = false;

  // Seen puzzle hashes to prevent serving duplicates across sessions
  final Set<int> _seenHashes = <int>{};
  bool _seenLoaded = false;

  static const String _storagePrefix = 'puzzle_cache_';
  static const String _seenKey = 'puzzle_seen_hashes';

  int _hashPuzzle(List<List<int>> puzzle) {
    int h = 0;
    for (final row in puzzle) {
      for (final v in row) {
        h = (h * 31 + v) & 0x7FFFFFFF;
      }
    }
    return h;
  }

  Future<void> _loadSeen() async {
    if (_seenLoaded) return;
    _seenLoaded = true;
    final prefs = ExtractData();
    final stored = await prefs.getDataFromLocal(_seenKey);
    if (stored != null) {
      try {
        final List<dynamic> list = jsonDecode(stored.toString());
        _seenHashes.addAll(list.map((e) => (e as num).toInt()));
      } catch (_) {}
    }
  }

  Future<void> _saveSeen() async {
    final prefs = ExtractData();
    await prefs.saveDataToLocal(_seenKey, jsonEncode(_seenHashes.toList()));
  }

  /// Load bundled puzzles from assets (called once)
  Future<void> _loadAssets() async {
    if (_assetLoaded) return;
    _assetLoaded = true;

    try {
      final jsonStr = await rootBundle.loadString('lib/Answer/Square_generate.json');
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      for (final entry in data.entries) {
        // key format: "generate_{rows}x{cols}_{index}"
        final parts = entry.key.split('_');
        if (parts.length >= 2) {
          final sizeKey = parts[1]; // "5x5", "10x10", etc.
          final edgeData = (entry.value as List)
              .map((row) => (row as List).map((v) => v as int).toList())
              .toList();

          _cache.putIfAbsent(sizeKey, () => []);
          _cache[sizeKey]!.add(edgeData);
        }
      }
    } catch (e) {
      // Asset not found or parse error - will fall back to runtime generation
    }

    // Also load any locally cached puzzles
    await _loadLocalCache();
  }

  /// Load puzzles from local storage
  Future<void> _loadLocalCache() async {
    final prefs = ExtractData();
    // Check for each known size
    for (final sizeKey in ['5x5', '7x7', '10x10', '15x15', '20x20']) {
      final stored = await prefs.getDataFromLocal('$_storagePrefix$sizeKey');
      if (stored != null) {
        try {
          final List<dynamic> puzzles = jsonDecode(stored.toString());
          _cache.putIfAbsent(sizeKey, () => []);
          for (final puzzle in puzzles) {
            final edgeData = (puzzle as List)
                .map((row) => (row as List<dynamic>).map((v) => v as int).toList())
                .toList();
            _cache[sizeKey]!.add(edgeData);
          }
        } catch (_) {}
      }
    }
  }

  /// Save remaining cache for a size to local storage
  Future<void> _saveLocalCache(String sizeKey) async {
    final prefs = ExtractData();
    final puzzles = _cache[sizeKey];
    if (puzzles != null && puzzles.isNotEmpty) {
      await prefs.saveDataToLocal('$_storagePrefix$sizeKey', jsonEncode(puzzles));
    } else {
      await prefs.saveDataToLocal('$_storagePrefix$sizeKey', '[]');
    }
  }

  /// Get a puzzle for the given size. Returns instantly if cached.
  /// Returns null if no cached puzzle available (caller should generate).
  Future<List<List<int>>?> getPuzzle(int rows, int cols) async {
    await _loadAssets();
    await _loadSeen();
    final sizeKey = '${rows}x$cols';

    if (_cache.containsKey(sizeKey)) {
      // 캐시 앞에서부터 꺼내며, 이미 본 해시는 건너뛴다.
      while (_cache[sizeKey]!.isNotEmpty) {
        final puzzle = _cache[sizeKey]!.removeAt(0);
        final h = _hashPuzzle(puzzle);
        if (_seenHashes.contains(h)) {
          // 중복 — 폐기하고 다음 후보 검사
          continue;
        }
        _seenHashes.add(h);
        await _saveSeen();
        await _saveLocalCache(sizeKey);
        // 백그라운드 보충
        _generateReplacement(rows, cols);
        return puzzle;
      }
      await _saveLocalCache(sizeKey);
    }

    return null; // 사용 가능한 캐시 없음 → 호출자가 직접 생성
  }

  /// 외부에서 직접 생성한 퍼즐도 seen 처리해 캐시 중복 방지에 반영.
  Future<void> markPuzzleSeen(List<List<int>> puzzle) async {
    await _loadSeen();
    final h = _hashPuzzle(puzzle);
    if (_seenHashes.add(h)) {
      await _saveSeen();
    }
  }

  /// Generate a replacement puzzle in the background and add to cache
  void _generateReplacement(int rows, int cols) {
    compute(_generateInIsolate, {'rows': rows, 'cols': cols}).then((result) async {
      await _loadSeen();
      final h = _hashPuzzle(result);
      if (_seenHashes.contains(h)) {
        // 이미 본 해시면 캐시에 추가하지 않고 다시 생성 시도
        _generateReplacement(rows, cols);
        return;
      }
      final sizeKey = '${rows}x$cols';
      _cache.putIfAbsent(sizeKey, () => []);
      _cache[sizeKey]!.add(result);
      await _saveLocalCache(sizeKey);
    }).catchError((_) {
      // Generation failed - will try again next time
    });
  }

  /// Top-level function for isolate generation
  static List<List<int>> _generateInIsolate(Map<String, int> params) {
    final rows = params['rows']!;
    final cols = params['cols']!;
    final generator = SlitherlinkGenerator(rows, cols);
    final puzzle = generator.generateSolution();
    return puzzle.toEdgeFormat();
  }
}
