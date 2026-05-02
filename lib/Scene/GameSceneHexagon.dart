// ignore_for_file: file_names
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

import '../MakePuzzle/HexagonGenerator.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../provider/HexagonProvider.dart';
import '../widgets/PuzzleAppBar.dart';

class GameSceneHexagon extends StatefulWidget {
  final bool isContinue;
  final String loadKey;

  const GameSceneHexagon({
    Key? key,
    required this.isContinue,
    required this.loadKey,
  }) : super(key: key);

  @override
  GameStateHexagon createState() => GameStateHexagon();
}

class GameStateHexagon extends State<GameSceneHexagon> with WidgetsBindingObserver {
  late HexagonProvider _provider;
  Timer? _shutdownTimer;

  bool _isGenerating = false;
  String _generationStatus = '';
  String _debugPuzzleInfo = '';

  late TransformationController _transformationController;
  double _zoomSlider = 1.0;
  bool _suppressZoomSync = false;
  Map<String, Color> settingColor = ThemeColor().getColor();
  bool showAppbar = true;

  // Bookmark state: R, G, B — "save" means empty slot, "load" means occupied.
  final List<String> _labelState = ["save", "save", "save"];

  @override
  void initState() {
    super.initState();
    _provider = HexagonProvider(
      isContinue: widget.isContinue,
      context: context,
      loadKey: widget.loadKey,
    );
    _initLabelState();
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

  /// Pan (without zoom) so that [p] — given in InteractiveViewer-child
  /// coordinates — sits at the centre of the available body area.
  void _panToCanvasPoint(Offset p) {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final ah = size.height - kToolbarHeight - 56;
    final old = _transformationController.value.clone();
    final s = old.getMaxScaleOnAxis();
    if (s == 0) return;
    final tx = size.width / 2 - s * p.dx;
    final ty = ah / 2 - s * p.dy;
    final m = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(s);
    _suppressZoomSync = true;
    _transformationController.value = m;
    _suppressZoomSync = false;
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
      // Stale Continue entry: the answer key was wiped (e.g. by a previous
      // build whose Splash.clearKeys allowlist didn't preserve this puzzle
      // type). Drop the entry and pop so the user isn't stuck on a blank screen.
      if (answer.isEmpty) {
        UserInfo.clearPuzzle(widget.loadKey);
        if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
        return;
      }
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

      final prefs = ExtractData();
      await prefs.saveDataToLocal(widget.loadKey, jsonEncode(answer));
    }

    if (!mounted) return;

    int puzzleHash = 0;
    for (var row in answer) {
      for (var v in row) {
        puzzleHash = (puzzleHash * 31 + v) & 0x7FFFFFFF;
      }
    }
    int activeEdges = answer.expand((r) => r).where((v) => v == 1).length;
    _debugPuzzleInfo = 'Hash: $puzzleHash | Edges: $activeEdges';

    final List<String> diffTokens = widget.loadKey.split("_");
    _provider.setAnswer(answer);
    _provider.setSubmit(submit);
    _provider.setDifficulty(diffTokens.length >= 4 ? diffTokens[3] : "normal");
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

  /// Difficulty isn't needed here — generator returns full edge data and
  /// HexagonProvider does the difficulty-based clue masking on the same answer.
  static List<List<int>> _generateIsolate(Map<String, dynamic> params) {
    int rows = params['rows'];
    int cols = params['cols'];
    final generator = HexagonGenerator(rows, cols);
    final puzzle = generator.generateSolution();
    return puzzle.toEdgeFormat();
  }

  void _fitToScreen() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final hexR = 40.0;
    final hexW = hexR * 2;
    final hexH = hexR * 1.732;

    double puzzleWidth = _provider.cols * (hexW + 2) + hexR + 40;
    double puzzleHeight = _provider.rows * hexH * 0.75 + hexH * 0.25 + 40;

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

  Future<void> _initLabelState() async {
    final prefs = ExtractData();
    for (int i = 0; i < PuzzleAppBar.colorNames.length; i++) {
      final key = "${widget.loadKey}_${PuzzleAppBar.colorNames[i]}";
      if (await prefs.containsKey(key)) {
        _labelState[i] = "load";
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveBookmark(int idx) async {
    final color = PuzzleAppBar.colorNames[idx];
    final key = "${widget.loadKey}_$color";
    final prefs = ExtractData();
    final snapshot = _provider.snapshotSubmit();
    await prefs.saveDataToLocal(key, jsonEncode(snapshot));
    setState(() => _labelState[idx] = "load");
  }

  Future<void> _loadBookmark(int idx) async {
    final color = PuzzleAppBar.colorNames[idx];
    final key = "${widget.loadKey}_$color";
    final prefs = ExtractData();
    final raw = await prefs.getDataFromLocal(key);
    if (raw == null) return;
    final List<dynamic> decoded = jsonDecode(raw.toString());
    final List<List<int>> saved = decoded
        .map<List<int>>((row) => (row as List).map<int>((v) => v as int).toList())
        .toList();
    await _provider.applyBookmarkSubmit(saved);
  }

  Future<void> _clearBookmark(int idx) async {
    final color = PuzzleAppBar.colorNames[idx];
    final key = "${widget.loadKey}_$color";
    final prefs = ExtractData();
    if (await prefs.containsKey(key)) {
      await prefs.removeKey(key);
    }
    setState(() => _labelState[idx] = "save");
  }

  Future<void> _onExit() async {
    if (!_isGenerating) {
      await _provider.saveProgress();
    }
    if (mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onNewGame() async {
    await _provider.removeHintLine();
    final prefs = ExtractData();
    for (final suffix in ["", "_continue"]) {
      final k = "${widget.loadKey}$suffix";
      if (await prefs.containsKey(k)) {
        await prefs.removeKey(k);
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameSceneHexagon(
          isContinue: false,
          loadKey: widget.loadKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: ChangeNotifierProvider(
        create: (_) => _provider,
        child: Consumer<HexagonProvider>(
          builder: (context, provider, child) {
            return Scaffold(
              appBar: !showAppbar || loc == null ? null : PuzzleAppBar.build(
                context: context,
                appbarColor: settingColor["appBar"]!,
                iconColor: settingColor["appIcon"]!,
                appLocalizations: loc,
                labelState: _labelState,
                onExit: () async {
                  await _onExit();
                },
                onRestart: () => provider.restart(),
                onNewGame: () async {
                  await _onNewGame();
                },
                onHint: () async {
                  await provider.showHint(context);
                  final p = provider.getHintCanvasPos();
                  if (p != null) _panToCanvasPoint(p);
                },
                onSaveBookmark: _saveBookmark,
                onLoadBookmark: _loadBookmark,
                onClearBookmark: _clearBookmark,
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
                              children: provider.getHexagonField().isNotEmpty
                                ? provider.getHexagonField()
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
                  if (kDebugMode && _debugPuzzleInfo.isNotEmpty)
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.black54,
                        child: Text(_debugPuzzleInfo,
                          style: const TextStyle(color: Colors.yellow, fontSize: 11)),
                      ),
                    ),
                  Positioned(
                    width: 70, height: 70,
                    left: UserInfo.getButtonAlignment() ? 20 : screenSize.width - 90,
                    bottom: 110,
                    child: ElevatedButton(
                      onPressed: () => provider.undo(),
                      child: const Icon(Icons.undo),
                    ),
                  ),
                  Positioned(
                    width: 70, height: 70,
                    left: UserInfo.getButtonAlignment() ? 20 : screenSize.width - 90,
                    bottom: 20,
                    child: ElevatedButton(
                      onPressed: () => provider.redo(),
                      child: const Icon(Icons.redo),
                    ),
                  ),
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
