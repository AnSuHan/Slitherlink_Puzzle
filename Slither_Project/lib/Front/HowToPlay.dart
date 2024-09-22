// ignore_for_file: file_names
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  List<List<dynamic>> step = [
    [
      [0, 1, "down"], [1, 1, "right"], [1, 1, "down"],    //step0
      //step1
    ]
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
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
                                height: screenSize.height * 0.2,
                              ),
                              ..._provider.getSquareField().map((widget) => Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenSize.width * 0.2,
                                ),
                                child: Container(
                                  color: ThemeColor().getColor()["background"],
                                  child: widget,
                                )),
                              ),
                              SizedBox(
                                height: screenSize.height * 0.2,
                              ),
                              Text(stepText),
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
                                  margin: EdgeInsets.all(20),
                                  color: Colors.red,
                                ),
                                Container(
                                  margin: EdgeInsets.all(20),
                                  color: Colors.green,
                                ),
                                Container(
                                  margin: EdgeInsets.all(20),
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
        //showStep1();
        break;
      case 2:
        stepText = "2";
        break;
      case 3:
        stepText = "3";
        break;
    }

    isOn = !isOn;
  }

  Future<void> checkStep(int row, int col, String pos) async {
    bool right = step[progressStep].any(
            (element) => element[0] == row && element[1] == col && element[2] == pos
    );

    if(!right) {
      await rollback(row, col, pos);
    }
  }

  ///updateSquareBox()에서 콜백으로 등록하여 잘못된 라인 클릭 시 롤백
  Future<void> rollback(int row, int col, String pos) async {
    _provider.setLineColorBox(row, col, pos, 0);
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