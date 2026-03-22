// ignore_for_file: file_names
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../provider/SquareProvider.dart';

class HowToPlay extends StatefulWidget {
  const HowToPlay({
    Key? key
  }) : super(key: key);

  @override
  HowToPlayState createState() => HowToPlayState();
}

class HowToPlayState extends State<HowToPlay> {
  late PageController controller;
  final FocusNode _focusNode = FocusNode();

  //provider for using setState in other class
  late SquareProvider _provider;
  late ReadSquare readSquare;
  final String loadKey = "square_small_0_test";
  late List<List<int>> answer;
  late List<List<int>> submit;

  late Size screenSize;

  Timer? _timer;
  int progressStep = 0;
  String stepText = "";
  int lineColor = 0;

  List<List<dynamic>> step = [
    //step0
    [[0, 1, "down"], [1, 1, "right"], [1, 1, "down"]],
    //step1
    [[0, 0, "right"], [0, 1, "up"], [2, 0, "right"], [2, 1, "down"]],
    [[0, 2, "up"]],
    [[0, 3, "up"], [0, 3, "right"], [2, 2, "down"], [2, 2, "right"]],
    [[1, 3, "down"], [1, 3, "right"]],
    []
  ];

  @override
  void initState() {
    super.initState();
    controller = PageController(
      initialPage: 0,
      viewportFraction: 0.8,
    );

    _provider = SquareProvider(context: context, loadKey: loadKey);
    readSquare = ReadSquare(squareProvider: _provider, context: context);
    loadPuzzle();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      showStep();
    });
    _focusNode.requestFocus();
  }

  void loadPuzzle() async {
    //load test answer
    answer = await readSquare.loadPuzzle(loadKey);  //test 데이터 정상적으로 가져옴

    submit = List.generate(answer.length, (row) =>
        List.filled(answer[row].length, 0),
    );

    _provider.setAnswer(answer);
    _provider.setSubmit(submit);
    await _provider.init();

    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (event) {
        if(event is RawKeyDownEvent) {
          if(UserInfo.debugMode["use_KeyInput"]!) {
            if(event.logicalKey == LogicalKeyboardKey.keyW) {
              _provider.printSubmit();
            }
          }
        }
      },
      child: ChangeNotifierProvider(
        create: (context) => _provider,
        child : Consumer<SquareProvider>(
            builder: (context, provider, child) {
              _provider = provider;
              screenSize = MediaQuery.of(context).size;

              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.keyboard_backspace),
                  ),
                  title: Text(AppLocalizations.of(context)!.translate("MainUI_menuHowToPlay")),
                  centerTitle: true,
                ),
                body: Column(
                    children: UserInfo.debugMode["howToPlay_followSteps"]!
                    //show interactive howToPlay
                        ? _provider.getSquareField().isNotEmpty
                        ? [
                      Column(
                        children: [
                          SizedBox(
                            height: screenSize.height * 0.05,
                          ),
                          ..._provider.getSquareField().map((widget) => Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.05,
                              ),
                              child: Container(
                                color: ThemeColor().getColor()["background"],
                                child: widget,
                              )),
                          ),
                          SizedBox(
                            height: screenSize.height * 0.1,
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenSize.width * 0.05,
                            ),
                            child: Text(
                              stepText,
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.start,
                              softWrap: true,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          SizedBox(
                            height: screenSize.height * 0.2,
                          ),
                        ],
                      )
                    ]
                    //loading
                        : [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [CircularProgressIndicator()],
                        ),
                      ),
                    ]
                        : [
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: AllowAllInputScrollBehavior(),
                          child: PageView(
                            scrollDirection: Axis.horizontal,
                            controller: controller,
                            physics: const AlwaysScrollableScrollPhysics(),
                            dragStartBehavior: DragStartBehavior.start,

                            children: [
                              Container(
                                margin: const EdgeInsets.all(20),
                                color: Colors.red,
                              ),
                              Container(
                                margin: const EdgeInsets.all(20),
                                color: Colors.green,
                              ),
                              Container(
                                margin: const EdgeInsets.all(20),
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),]
                ),
              );
            }
        ),
      ),
    );
  }

  bool isOn = true;

  void showStep() {
    switch(progressStep) {
      case 0:
        stepText = "0";
        if(_provider.getLineColorBox(1, 1, "right") > 0 && _provider.getLineColorBox(1, 1, "down") > 0 && _provider.getLineColorBox(0, 1, "down") > 0) {
          progressStep++;
        }
        showStep0();
        break;
      case 1:
        stepText = "1";
        if(_provider.getLineColorBox(0, 0, "right") > 0 && _provider.getLineColorBox(0, 1, "up") > 0 && _provider.getLineColorBox(2, 0, "right") > 0 && _provider.getLineColorBox(2, 1, "down") > 0) {
          progressStep++;
        }
        showStep1();
        break;
      case 2:
        stepText = "2";
        if(_provider.getLineColorBox(0, 2, "up") > 0) {
          progressStep++;
        }
        showStep2();
        break;
      case 3:
        stepText = "3";
        if(_provider.getLineColorBox(0, 3, "up") > 0 && _provider.getLineColorBox(0, 3, "right") > 0 && _provider.getLineColorBox(2, 2, "down") > 0 && _provider.getLineColorBox(2, 2, "right") > 0) {
          progressStep++;
        }
        showStep3();
        break;
      case 4:
        stepText = "4";
        if(_provider.getLineColorBox(1, 3, "down") > 0 && _provider.getLineColorBox(1, 3, "right") > 0) {
          progressStep++;
        }
        showStep4();
        break;
      //condition of end
      case 5:
        stepText = "5";
        showStepEnd();
        _timer?.cancel();
        break;
    }

    isOn = !isOn;
    stepText = AppLocalizations.of(context)!.translate("howToPlay_Step$progressStep");
    setState(() {});
  }

  Future<void> checkStep(int row, int col, String pos) async {
    bool right = step[progressStep].any(
            (element) => element[0] == row && element[1] == col && element[2] == pos
    );

    if(!right) {
      //0이 아닌 다른 색으로 rollback
      bool found = false;
      for(int i = 0; i < progressStep && !found; i++) {
        found = step[i].any(
                (element) => element[0] == row && element[1] == col && element[2] == pos
        );
      }

      await rollback(row, col, pos, found ? lineColor : 0);
    }
    else {
      if(lineColor == 0) {
        lineColor = _provider.getLineColorBox(row, col, pos);
      }
      _provider.findBlockEnableDisable(row, col, pos, enable: true, isMax: true);
    }
  }

  ///updateSquareBox()에서 콜백으로 등록하여 잘못된 라인 클릭 시 롤백
  Future<void> rollback(int row, int col, String pos, int color) async {
    _provider.setLineColorBox(row, col, pos, color);
    _provider.findBlockEnableDisable(row, col, pos, enable: true, isMax: true);
  }

  void showStep0() {
    _provider.setBoxColor(1, 1, 1);

    switch(_provider.getLineColorBox(1, 1, "right")) {
      case 0:
      case -3:
        _provider.setLineColorBox(1, 1, "right", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(1, 1, "down")) {
      case 0:
      case -3:
        _provider.setLineColorBox(1, 1, "down", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(0, 1, "down")) {
      case 0:
      case -3:
        _provider.setLineColorBox(0, 1, "down", isOn ? -3 : 0);
        break;
    }
  }
  void showStep1() {
    _provider.setBoxColor(1, 1, 0);
    _provider.setBoxColor(0, 1, 1);
    _provider.setBoxColor(2, 1, 1);

    switch(_provider.getLineColorBox(0, 0, "right")) {
      case 0:
      case -3:
        _provider.setLineColorBox(0, 0, "right", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(0, 1, "up")) {
      case 0:
      case -3:
        _provider.setLineColorBox(0, 1, "up", isOn ? -3 : 0);
        break;
    }

    switch(_provider.getLineColorBox(2, 0, "right")) {
      case 0:
      case -3:
        _provider.setLineColorBox(2, 0, "right", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(2, 1, "down")) {
      case 0:
      case -3:
        _provider.setLineColorBox(2, 1, "down", isOn ? -3 : 0);
        break;
    }
  }
  void showStep2() {
    _provider.setBoxColor(0, 1, 0);
    _provider.setBoxColor(2, 1, 0);
    _provider.setBoxColor(0, 2, 1);

    switch(_provider.getLineColorBox(0, 2, "up")) {
      case 0:
      case -3:
        _provider.setLineColorBox(0, 2, "up", isOn ? -3 : 0);
        break;
    }
  }
  void showStep3() {
    _provider.setBoxColor(0, 2, 0);
    _provider.setBoxColor(0, 3, 1);
    _provider.setBoxColor(2, 2, 1);

    switch(_provider.getLineColorBox(0, 3, "up")) {
      case 0:
      case -3:
        _provider.setLineColorBox(0, 3, "up", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(0, 3, "right")) {
      case 0:
      case -3:
        _provider.setLineColorBox(0, 3, "right", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(2, 2, "down")) {
      case 0:
      case -3:
        _provider.setLineColorBox(2, 2, "down", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(2, 2, "right")) {
      case 0:
      case -3:
        _provider.setLineColorBox(2, 2, "right", isOn ? -3 : 0);
        break;
    }
  }
  void showStep4() {
    _provider.setBoxColor(0, 3, 0);
    _provider.setBoxColor(2, 2, 0);
    _provider.setBoxColor(1, 3, 1);
    _provider.setBoxColor(2, 3, 1);

    switch(_provider.getLineColorBox(1, 3, "down")) {
      case 0:
      case -3:
        _provider.setLineColorBox(1, 3, "down", isOn ? -3 : 0);
        break;
    }
    switch(_provider.getLineColorBox(1, 3, "right")) {
      case 0:
      case -3:
        _provider.setLineColorBox(1, 3, "right", isOn ? -3 : 0);
        break;
    }
  }
  void showStepEnd() {
    _provider.setBoxColor(1, 3, 0);
    _provider.setBoxColor(2, 3, 0);
  }
}

class AllowAllInputScrollBehavior extends MaterialScrollBehavior {
  // 모든 입력 장치에서 스크롤 가능하도록 오버라이드
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}