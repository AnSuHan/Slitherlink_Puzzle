// ignore_for_file: file_names
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

import '../MakePuzzle/SlitherlinkGenerator.dart' show Difficulty;
import '../MakePuzzle/TriangleGenerator.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../provider/TriangleProvider.dart';

class GameSceneTriangle extends StatefulWidget {
  final bool isContinue;
  final String loadKey;

  const GameSceneTriangle({
    Key? key,
    required this.isContinue,
    required this.loadKey,
  }) : super(key: key);

  @override
  GameStateTriangle createState() => GameStateTriangle();
}

class GameStateTriangle extends State<GameSceneTriangle> with WidgetsBindingObserver {
  late TriangleProvider _provider;
  Timer? _shutdownTimer;

  bool isComplete = false;
  bool _isGenerating = false;
  String _generationStatus = '';
  String _debugPuzzleInfo = '';

  late TransformationController _transformationController;
  double _zoomSlider = 1.0;
  bool _suppressZoomSync = false;
  Map<String, Color> settingColor = ThemeColor().getColor();
  bool showAppbar = true;

  @override
  void initState() {
    super.initState();
    _provider = TriangleProvider(
      isContinue: widget.isContinue,
      context: context,
      loadKey: widget.loadKey,
    );
    _loadPuzzle();

    _shutdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_provider.shutdown && mounted && Navigator.canPop(context)) {
        setState(() => Navigator.of(context).pop());
      }
    });

    _transformationController = TransformationController();
    _transformationController.addListener(_syncZoom);
    WidgetsBinding.instance.addObserver(this);
  }

  void _syncZoom() {
    if (_suppressZoomSync) return;
    final s = _transformationController.value.getMaxScaleOnAxis();
    if ((s - _zoomSlider).abs() > 0.001) {
      if (mounted) setState(() => _zoomSlider = s.clamp(0.3, 2.0));
    }
  }

  void _applyZoom(double newScale) {
    newScale = newScale.clamp(0.3, 2.0);
    final old = _transformationController.value.clone();
    final oldScale = old.getMaxScaleOnAxis();
    if (oldScale == 0) return;
    final factor = newScale / oldScale;
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final updated = Matrix4.identity()
      ..translate(cx, cy)
      ..scale(factor)
      ..translate(-cx, -cy)
      ..multiply(old);
    _suppressZoomSync = true;
    _transformationController.value = updated;
    _suppressZoomSync = false;
    setState(() => _zoomSlider = newScale);
  }

  @override
  void dispose() {
    _shutdownTimer?.cancel();
    _transformationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _provider.saveProgress();
    }
  }

  void _loadPuzzle() async {
    List<String> tokens = widget.loadKey.split("_");

    List<List<int>> answer;
    List<List<int>> submit;

    if (widget.isContinue) {
      answer = await _loadSavedPuzzle(widget.loadKey);
      submit = await _loadSavedPuzzle("${widget.loadKey}_continue");
    } else {
      if (mounted) setState(() {
        _isGenerating = true;
        _generationStatus = '20%';
      });

      List<String> sizeParts = tokens[2].split("x");
      int genRows = int.parse(sizeParts[0]);
      int genCols = int.parse(sizeParts[1]);
      String diffStr = tokens.length >= 4 ? tokens[3] : "normal";

      answer = await compute(_generateIsolate, {
        'rows': genRows,
        'cols': genCols,
        'difficulty': diffStr,
      });

      if (mounted) setState(() => _generationStatus = '90%');

      submit = List.generate(answer.length, (r) => List.filled(answer[r].length, 0));

      // Save answer for continue
      final prefs = ExtractData();
      await prefs.saveDataToLocal(widget.loadKey, jsonEncode(answer));
    }

    if (!mounted) return;

    // Debug info
    int puzzleHash = 0;
    for (var row in answer) {
      for (var v in row) {
        puzzleHash = (puzzleHash * 31 + v) & 0x7FFFFFFF;
      }
    }
    int activeEdges = answer.expand((r) => r).where((v) => v == 1).length;
    _debugPuzzleInfo = 'Hash: $puzzleHash | Edges: $activeEdges';

    _provider.setAnswer(answer);
    _provider.setSubmit(submit);
    _provider.init();

    if (mounted) setState(() {
      _generationStatus = '100%';
      _isGenerating = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToScreen());
  }

  Future<List<List<int>>> _loadSavedPuzzle(String key) async {
    final prefs = ExtractData();
    String? data = await prefs.getDataFromLocal(key);
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((row) => (row as List).map((v) => v as int).toList()).toList();
    }
    return [];
  }

  static List<List<int>> _generateIsolate(Map<String, dynamic> params) {
    int rows = params['rows'];
    int cols = params['cols'];
    String diffStr = params['difficulty'];

    Difficulty difficulty;
    switch (diffStr) {
      case "easy": difficulty = Difficulty.easy; break;
      case "hard": difficulty = Difficulty.hard; break;
      default: difficulty = Difficulty.normal;
    }

    final generator = TriangleGenerator(rows, cols);
    final puzzle = generator.generateSolution();
    return puzzle.toEdgeFormat();
  }

  void _fitToScreen() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final cellW = 50.0;
    final cellH = 50.0 * 0.866;

    double puzzleWidth = _provider.triPerRow * cellW / 2 + 40;
    double puzzleHeight = _provider.rows * cellH + 40;

    double availH = size.height - kToolbarHeight - 56;
    double scaleX = size.width / puzzleWidth;
    double scaleY = availH / puzzleHeight;
    double fit = (scaleX < scaleY ? scaleX : scaleY).clamp(0.3, 4.0);

    double dx = (size.width - puzzleWidth * fit) / 2;
    double dy = (availH - puzzleHeight * fit) / 2;
    if (dx < 0) dx = 0;
    if (dy < 0) dy = 0;

    _transformationController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(fit);
  }

  Future<bool> _onWillPop() async {
    if (!_isGenerating) {
      await _provider.saveProgress();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: ChangeNotifierProvider(
        create: (_) => _provider,
        child: Consumer<TriangleProvider>(
          builder: (context, provider, child) {
            return Scaffold(
              appBar: !showAppbar ? null : AppBar(
                backgroundColor: settingColor["appBar"],
                iconTheme: IconThemeData(color: settingColor["appIcon"]),
                title: Text(
                  loc?.translate('game_title') ?? 'Triangle Puzzle',
                  style: TextStyle(color: settingColor["appIcon"]),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.lightbulb_outline, color: settingColor["appIcon"]),
                    onPressed: () => provider.showHint(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: settingColor["appIcon"]),
                    onPressed: () => provider.restart(),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Container(
                    color: settingColor["background"],
                    child: _isGenerating
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 3),
                              const SizedBox(height: 24),
                              Text(_generationStatus,
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                                  color: settingColor["number"] ?? Colors.white)),
                              const SizedBox(height: 8),
                              Text('Generating puzzle...',
                                style: TextStyle(fontSize: 14,
                                  color: (settingColor["number"] ?? Colors.white).withOpacity(0.6))),
                            ],
                          ),
                        )
                      : InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.3,
                          maxScale: 2.0,
                          boundaryMargin: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.5,
                            vertical: screenSize.height * 0.5,
                          ),
                          constrained: false,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: provider.getTriangleField().isNotEmpty
                                ? provider.getTriangleField()
                                : [
                                    SizedBox(
                                      width: screenSize.width,
                                      height: screenSize.height,
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                  ],
                            ),
                          ),
                        ),
                  ),
                  if (_debugPuzzleInfo.isNotEmpty)
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.black54,
                        child: Text(_debugPuzzleInfo,
                          style: const TextStyle(color: Colors.yellow, fontSize: 11)),
                      ),
                    ),
                  // Undo button
                  Positioned(
                    width: 70, height: 70,
                    left: UserInfo.getButtonAlignment() ? 20 : screenSize.width - 90,
                    bottom: 110,
                    child: ElevatedButton(
                      onPressed: () => provider.undo(),
                      child: const Icon(Icons.undo),
                    ),
                  ),
                  // Redo button
                  Positioned(
                    width: 70, height: 70,
                    left: UserInfo.getButtonAlignment() ? 20 : screenSize.width - 90,
                    bottom: 20,
                    child: ElevatedButton(
                      onPressed: () => provider.redo(),
                      child: const Icon(Icons.redo),
                    ),
                  ),
                  // Zoom slider
                  Positioned(
                    width: 40, height: 220,
                    left: UserInfo.getButtonAlignment() ? 20 : screenSize.width - 60,
                    bottom: 290,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        min: 0.3, max: 2.0,
                        value: _zoomSlider.clamp(0.3, 2.0),
                        onChanged: (v) => _applyZoom(v),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
