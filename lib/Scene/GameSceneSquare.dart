// ignore_for_file: file_names
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

import '../MakePuzzle/PuzzleCache.dart';
import '../MakePuzzle/ReadSquare.dart';
import '../MakePuzzle/SlitherlinkGenerator.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../provider/SquareProvider.dart';
import '../widgets/GameUI.dart';

class GameSceneSquare extends StatefulWidget {
  //to access to parameter with Navigator push, variable should be final
  final bool isContinue;
  final String loadKey;
  final bool testMode;
  final bool forceNewPuzzle;

  const GameSceneSquare({
    Key? key, required this.isContinue, required this.loadKey, this.testMode = false, this.forceNewPuzzle = false,
  }) : super(key: key);

  @override
  GameStateSquare createState() => GameStateSquare();
}

enum DisplayType {
  smallLand,
  smallPortrait,
  bigLand,
  bigPortrait,
}

class GameStateSquare extends State<GameSceneSquare> with WidgetsBindingObserver {
  ///ONLY-DEBUG variables
  bool extractData = false;
  final FocusNode _focusNode = FocusNode();
  bool useKeyInput = false;
  ///ONLY-DEBUG variables

  //provider for using setState in other class
  late SquareProvider _provider;
  late ReadSquare readSquare;
  Timer? _shutdownTimer;

  GameStateSquare({this.isContinue = false, this.loadKey = ""});

  //check complete puzzle;
  bool isComplete = false;
  bool isContinue = false;
  String loadKey = "";
  late List<List<int>> answer;
  late List<List<int>> submit;

  //UI
  late Size screenSize;
  late String appbarMode;
  bool showAppbar = true;
  GameUI? uiNullable;
  late GameUI ui;
  Map<String, Color> settingColor = ThemeColor().getColor();
  late DisplayType displayType;

  //puzzle generation state
  bool _isGenerating = false;
  String _generationStatus = '';
  String _debugPuzzleInfo = '';

  //for moving interactive Viewer
  late TransformationController _transformationController;

  void debugSetting() {
    extractData = UserInfo.debugMode["enable_extract"]!;
    useKeyInput = UserInfo.debugMode["use_KeyInput"]!;
  }

  @override
  void initState() {
    debugSetting();

    isContinue = widget.isContinue;
    appbarMode = UserInfo.getAppbarMode();
    _focusNode.requestFocus();

    //print("GameSceneStateSquareProvider is start, isContinue : ${widget.isContinue}");
    super.initState();
    _provider = SquareProvider(isContinue: isContinue, context: context, gameStateSquare: this, loadKey: widget.loadKey);
    readSquare = ReadSquare(squareProvider: _provider, context: context);
    loadPuzzle();

    _shutdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      //print("_provider.shutdown : ${_provider.shutdown}, mounted : $mounted, canPop : ${Navigator.canPop(context)}");
      if (_provider.shutdown && mounted && Navigator.canPop(context)) {
        setState(() {
          Navigator.of(context).pop();
        });
      }
    });

    _transformationController = TransformationController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // 타이머 취소
    _shutdownTimer?.cancel();
    _transformationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void loadPuzzle() async {
    isComplete = false;
    List<String> tokens = widget.loadKey.split("_");
    bool isGenerate = tokens.length >= 3 && tokens[1] == "generate";

    //load test answer
    if(widget.testMode && tokens.length > 3 && tokens[3].compareTo("test") == 0) {
      answer = await readSquare.loadPuzzle(widget.loadKey);
      submit = List.generate(answer.length, (row) =>
          List.filled(answer[row].length, 0),
      );
    }
    else if(widget.isContinue) {
      answer = await readSquare.loadPuzzle(widget.loadKey);
      submit = await readSquare.loadPuzzle("${widget.loadKey}_continue");
    }
    else if (isGenerate) {
      List<String> sizeParts = tokens[2].split("x");
      int genRows = int.parse(sizeParts[0]);
      int genCols = int.parse(sizeParts[1]);

      // Try cache first for instant loading (skip cache if forceNewPuzzle)
      List<List<int>>? cached;
      if (!widget.forceNewPuzzle) {
        cached = await PuzzleCache.instance.getPuzzle(genRows, genCols);
      }

      if (cached != null) {
        answer = cached;
      } else {
        // No cache or forced new - generate with progress UI
        if (mounted) setState(() {
          _isGenerating = true;
          _generationStatus = '0%';
        });

        if (mounted) setState(() => _generationStatus = '20%');

        // Run heavy generation in a separate isolate
        answer = await compute(_generatePuzzleIsolate, {
          'rows': genRows,
          'cols': genCols,
          'difficulty': tokens.length >= 4 ? tokens[3] : "normal",
        });

        if (mounted) setState(() => _generationStatus = '90%');
      }

      submit = List.generate(answer.length, (row) =>
          List.filled(answer[row].length, 0),
      );

      // 생성된 퍼즐 정답을 저장 (이어하기 시 복원용)
      await readSquare.saveAnswer(widget.loadKey, answer);
    }
    else {
      answer = await readSquare.loadPuzzle(widget.loadKey);
      submit = List.generate(answer.length, (row) =>
          List.filled(answer[row].length, 0),
      );
    }

    if (!mounted) return;

    // Debug: compute puzzle hash to verify uniqueness
    int puzzleHash = 0;
    for (int i = 0; i < answer.length; i++) {
      for (int j = 0; j < answer[i].length; j++) {
        puzzleHash = (puzzleHash * 31 + answer[i][j]) & 0x7FFFFFFF;
      }
    }
    int activeEdges = 0;
    for (var row in answer) {
      for (var v in row) {
        if (v == 1) activeEdges++;
      }
    }
    _debugPuzzleInfo = 'Hash: $puzzleHash | Edges: $activeEdges | Force: ${widget.forceNewPuzzle}';
    // ignore: avoid_print
    print('PUZZLE DEBUG: $_debugPuzzleInfo | Key: ${widget.loadKey}');

    _provider.setAnswer(answer);
    _provider.setSubmit(submit);
    _provider.init();
    _provider.setGameField(this);

    if (_isGenerating && mounted) {
      setState(() {
        _generationStatus = '100%';
        _isGenerating = false;
      });
    }

    // Auto-fit puzzle to screen after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitPuzzleToScreen();
    });
  }

  /// Top-level function for compute() isolate
  static List<List<int>> _generatePuzzleIsolate(Map<String, dynamic> params) {
    int rows = params['rows'];
    int cols = params['cols'];
    String diffStr = params['difficulty'];

    Difficulty difficulty;
    switch (diffStr) {
      case "easy":
        difficulty = Difficulty.easy;
        break;
      case "hard":
        difficulty = Difficulty.hard;
        break;
      default:
        difficulty = Difficulty.normal;
    }

    final generator = SlitherlinkGenerator(rows, cols);
    final puzzle = generator.generateSolution();
    return puzzle.toEdgeFormat();
  }

  void _fitPuzzleToScreen() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;

    // SquareBox dimensions:
    // Each cell: box(50) + rightLine(10) + gap(2.5) + dot(5) = 67.5px wide
    // First column adds: leftLine(10) extra
    // Each cell: box(50) + bottomLine(10) + dot(5) = 65px tall
    // First row adds: topLine(10) + dot(5) + gap(2.5) = 17.5px extra
    const double cellWidth = 67.5;
    const double cellHeight = 65.0;
    const double firstColExtra = 10.0;
    const double firstRowExtra = 17.5;
    const double viewPadding = 40.0;

    int cols = answer.isNotEmpty ? answer[0].length : 1;
    int rows = answer.isNotEmpty ? answer.length ~/ 2 : 1;

    double puzzleWidth = cols * cellWidth + firstColExtra + viewPadding;
    double puzzleHeight = rows * cellHeight + firstRowExtra + viewPadding;

    double availableWidth = size.width;
    double availableHeight = size.height - kToolbarHeight - 56; // appbar + status bar

    double scaleX = availableWidth / puzzleWidth;
    double scaleY = availableHeight / puzzleHeight;
    double fitScale = scaleX < scaleY ? scaleX : scaleY;

    // Clamp to reasonable range
    if (fitScale < 0.3) fitScale = 0.3;
    if (fitScale > 4.0) fitScale = 4.0;

    // Center the puzzle
    double scaledWidth = puzzleWidth * fitScale;
    double scaledHeight = puzzleHeight * fitScale;
    double dx = (size.width - scaledWidth) / 2;
    double dy = (availableHeight - scaledHeight) / 2;
    if (dx < 0) dx = 0;
    if (dy < 0) dy = 0;

    final matrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(fitScale);
    _transformationController.value = matrix;
  }

  Future<bool> _onWillPop() async {
    if (_isGenerating) {
      // During generation, just go back without saving
      return true;
    }
    if(uiNullable != null) {
      await ui.exitGame();
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // 앱이 백그라운드로 전환될 때 실행할 메소드 호출
      ui.pauseGame();
      //print("앱이 백그라운드로 이동했습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if(uiNullable == null) {
      uiNullable = GameUI(squareProvider: _provider, context: context, appLocalizations: AppLocalizations.of(context)!);
      ui = uiNullable!;
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: ChangeNotifierProvider( // ChangeNotifierProvider 사용
        create: (context) => _provider, //ChangeNotifier class
        child: Consumer<SquareProvider>(
          builder: (context, provider, child) {
            screenSize = MediaQuery.of(context).size;
            ui.setScreenSize(screenSize);
            _provider = provider;

            return Scaffold(
              appBar: !showAppbar ? null : ui.getGameAppBar(context, settingColor["appBar"]!, settingColor["appIcon"]!),
              body: RawKeyboardListener(
                focusNode: _focusNode,
                onKey: (RawKeyEvent event) {
                  if(!useKeyInput) {
                    return;
                  }
                  if (event is RawKeyDownEvent) {
                    //apply answer to field
                    if (event.logicalKey == LogicalKeyboardKey.keyA) {
                      setState(() {
                        _provider.loadLabel(answer);
                      });
                    }
                    //clear puzzle
                    else if (event.logicalKey == LogicalKeyboardKey.keyF) {
                      setState(() {
                        _provider.showComplete(context);
                      });
                    }
                    //print submit
                    else if (event.logicalKey == LogicalKeyboardKey.keyP) {
                      setState(() {
                        _provider.readSubmit();
                      });
                    }
                  }
                },
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if(appbarMode.compareTo("fixed") != 0) {
                        showAppbar = !showAppbar;
                      }
                    });
                  },
                  child: AbsorbPointer(
                    absorbing: isComplete,
                    child: Stack(
                      children: [
                        Container(
                          color: settingColor["background"],
                          child: _isGenerating
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      _generationStatus,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: settingColor["number"] ?? Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Generating puzzle...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: (settingColor["number"] ?? Colors.white).withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : InteractiveViewer(
                            transformationController: _transformationController,
                            minScale: 0.3,
                            maxScale: 5.0,
                            boundaryMargin: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.5,
                              vertical: screenSize.height * 0.5,
                            ),
                            constrained: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 20),
                              child: Column(
                                children: _provider.getSquareField().isNotEmpty
                                    ? _provider.getSquareField()
                                    : [
                                      SizedBox(
                                        width: screenSize.width,
                                        height: screenSize.height,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: const [CircularProgressIndicator()],
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Debug: puzzle hash overlay
                        if (_debugPuzzleInfo.isNotEmpty)
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              color: Colors.black54,
                              child: Text(
                                _debugPuzzleInfo,
                                style: const TextStyle(color: Colors.yellow, fontSize: 11),
                              ),
                            ),
                          ),
                        Positioned(
                          width: 70,
                          height: 70,
                          left: UserInfo.getButtonAlignment() ? 20
                              : ui.getScreenSize().width - 90, //margin
                          bottom: 110,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _provider.undo();
                            },
                            child: const Icon(Icons.undo),
                          ),
                        ),
                        Positioned(
                          width: 70,
                          height: 70,
                          left: UserInfo.getButtonAlignment() ? 20
                              : ui.getScreenSize().width - 90, //margin
                          bottom: 20,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _provider.redo();
                            },
                            child: const Icon(Icons.redo),
                          ),
                        ),
                        if(extractData)
                          Positioned(
                            width: 70,
                            height: 70,
                            left: UserInfo.getButtonAlignment() ? 20
                                : ui.getScreenSize().width - 90, //margin
                            bottom: 200,
                            child: ElevatedButton(
                              onPressed: () async {
                                await _provider.extractData();
                              },
                              child: const Icon(Icons.upload_rounded),
                            ),
                          ),
                      ],
                    )
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double boxSize = 50;
  double scale = 1.6;

  ///item => [row, col, dir, `isWrongSubmit : bool`]
  ///
  ///item => [vertical, horizontal]
  List<double> getHintPos(List<dynamic> item) {
    return [0.0, 0.0];

    /*
    //[vertical, horizontal]
    List<int> hintCount = _provider.getResolutionCount();

    //한 화면에 보이는 아이템의 최대 개수
    //[vertical, horizontal]
    List<int> inScreen = [
      screenSize.height ~/ (boxSize * scale),
      screenSize.width ~/ (boxSize * scale)
    ];

    //landscape small
    if(screenSize.width > screenSize.height && screenSize.height <= 600) {
      inScreen = [inScreen[0] - 2, inScreen[1] - 2];
      displayType = DisplayType.smallLand;
    }
    //portrait small
    else if(screenSize.width < screenSize.height && screenSize.width <= 400) {
      inScreen = [inScreen[0] - 2, inScreen[1] - 2];
      displayType = DisplayType.smallPortrait;
    }
    //landscape big ok
    else if(screenSize.width > screenSize.height && screenSize.height > 600) {
      inScreen = [inScreen[0] - 2, inScreen[1] - 2];
      displayType = DisplayType.bigLand;
    }
    //portrait big (default)
    else if((screenSize.width < screenSize.height && screenSize.width > 400) || true) {
      inScreen = [inScreen[1] - 3, inScreen[0] - 5];
      displayType = DisplayType.bigPortrait;
    }
    print("inScreen : $inScreen, $displayType");

    int row = int.parse(item[0].toString());
    int col = int.parse(item[1].toString());

    double xPos = 0, yPos = 0;

    //find xPos
    if(col < inScreen[1] / 2) {
      xPos = 0;
    }
    else if(col > hintCount[0] - inScreen[0] / 2) {
      xPos = -(hintCount[1] - inScreen[1]) * boxSize;
      print("in xPos");
    }
    else {
      xPos = -col * boxSize;
    }

    //find yPos
    if(row < inScreen[0] / 2) {
      yPos = 0;
    }
    else if(row > hintCount[1] - inScreen[1] / 2) {
      yPos = -(hintCount[0] - inScreen[0]) * boxSize;
    }
    else {
      yPos = -row * boxSize;
    }

    return [xPos, yPos];
     */
  }

  ///move to position in "InteractiveViewer"
  Future<void> moveTo(List<double> pos, double scale) async {
    final matrix4 = Matrix4.identity()
      //..translate(-screenSize.width / 2, -screenSize.height / 2)
      ..scale(1);
    _transformationController.value = matrix4;
  }
}

/*
* [0,0] 좌상, [-screenSize.width * 1.2, 0] 우상, [0, -screenSize.height * 0.4] 좌하
(1280, 752) => (-770, -440) 태블릿 가로
(800, 1232) => (-1250, 0) 태블릿 세로

(726, 360) => (-1350, -770) 스마트폰 가로
(360, 752) => (-1700, -400) 스마트폰 세로

(960, 961) => (-1150, -200) 웹 화면 절반
screenSize => translate()
* */