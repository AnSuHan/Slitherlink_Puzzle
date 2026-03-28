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

  static const String _storagePrefix = 'puzzle_cache_';

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
    final sizeKey = '${rows}x$cols';

    if (_cache.containsKey(sizeKey) && _cache[sizeKey]!.isNotEmpty) {
      // Take one puzzle from cache
      final puzzle = _cache[sizeKey]!.removeAt(0);
      // Save updated cache
      await _saveLocalCache(sizeKey);
      // Generate replacement in background
      _generateReplacement(rows, cols);
      return puzzle;
    }

    return null; // No cached puzzle available
  }

  /// Generate a replacement puzzle in the background and add to cache
  void _generateReplacement(int rows, int cols) {
    compute(_generateInIsolate, {'rows': rows, 'cols': cols}).then((result) {
      final sizeKey = '${rows}x$cols';
      _cache.putIfAbsent(sizeKey, () => []);
      _cache[sizeKey]!.add(result);
      _saveLocalCache(sizeKey);
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
