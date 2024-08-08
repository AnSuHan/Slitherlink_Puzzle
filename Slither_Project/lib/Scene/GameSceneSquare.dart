// ignore_for_file: file_names
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../provider/SquareProvider.dart';
import '../widgets/GameUI.dart';

class GameSceneSquare extends StatefulWidget {
  //to access to parameter with Navigator push, variable should be final
  final bool isContinue;
  final String loadKey;

  const GameSceneSquare({
    Key? key, required this.isContinue, required this.loadKey
  }) : super(key: key);

  @override
  GameStateSquare createState() => GameStateSquare();
}

class GameStateSquare extends State<GameSceneSquare> {
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

  //for moving interactive Viewer
  late TransformationController _transformationController;

  void debugSetting() {
    if(UserInfo.isDebug) {
      extractData = true;
      useKeyInput = true;
    }
    else {
      extractData = false;
      useKeyInput = false;
    }
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
  }

  @override
  void dispose() {
    // 타이머 취소
    _shutdownTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  void loadPuzzle() async {
    //print("loadKey : ${widget.loadKey}");
    isComplete = false;

    if(widget.isContinue) {
      answer = await readSquare.loadPuzzle(widget.loadKey);

      submit = await readSquare.loadPuzzle("${widget.loadKey}_continue");
    }
    else {
      answer = await readSquare.loadPuzzle(widget.loadKey);

      submit = List.generate(answer.length, (row) =>
          List.filled(answer[row].length, 0),
      );
    }

    _provider.setAnswer(answer);
    _provider.setSubmit(submit);
    _provider.init();
    _provider.setGameField(this); //start 할 때, 바로 field가 보이도록 하기 위해 사용
  }

  @override
  Widget build(BuildContext context) {
    if(uiNullable == null) {
      uiNullable = GameUI(squareProvider: _provider, context: context, appLocalizations: AppLocalizations.of(context)!);
      ui = uiNullable!;
    }

    return ChangeNotifierProvider( // ChangeNotifierProvider 사용
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
                  } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
                    setState(() {
                      _provider.showComplete(context);
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
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          boundaryMargin: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.4,
                            vertical: screenSize.height * 0.4,
                          ),
                          constrained: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 20),
                            child: Column(
                              //provider와 ChangeNotifier를 통해 접근
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
    );
  }

  String getPuzzleKey() {
    return widget.loadKey;
  }

  List<double> getHintPos(List<dynamic> item) {
    List<int> area = _provider.getResolutionCount();  //count of field
    List<double> max = [
      -screenSize.width,
      -screenSize.height
    ];
    List<double> ratio = [item[1] * max[0] / area[0], item[0] * max[1] / area[1]];
    //bias
    if(item[1] < area[0] * 0.25) {
      ratio[0] -= max[0] * 0.1;
    }
    else if(item[1] > area[0] * 0.75) {
      ratio[0] -= max[0] * 0.3;
    }
    if(item[0] < area[1] * 0.25 || item[0] > area[1] * 0.75) {
      ratio[1] -= max[1] * 0.1;
    }

    //double maxX = -screenSize.width * 0.8;  // ~ screenSize.width * 0.4
    //double maxY = -screenSize.height * 0.2; // -screenSize.height * 0.2 ~ screenSize.height * 0.2
    //print("maxX : ${max[0]}, maxY : ${max[1]}");
    // print("area : ${area[0]}, ${area[1]}");
    print("item : ${item[0]}, ${item[1]}");
    print("ratio : ${ratio[0]} ${ratio[1]}");

    return [ratio[0], ratio[1]];
  }

  ///move to position in "InteractiveViewer"
  Future<void> moveTo(List<double> pos, double scale) async {
    final matrix4 = Matrix4.identity()
      ..translate(pos[0], pos[1])
      ..scale(scale);
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