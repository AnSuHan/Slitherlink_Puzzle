// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../ThemeColor.dart';
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
  //GameSceneStateSquareProvider({this.isContinue = false, this.loadKey = ""});
  //provider for using setState in other class
  late SquareProvider _provider;
  late ReadSquare readSquare;

  GameStateSquare({this.isContinue = false, this.loadKey = ""}) {
    // SquareProviderProvider 객체 초기화
    _provider = SquareProvider(isContinue: isContinue);
    // ReadSquare 객체 초기화
    readSquare = ReadSquare(squareProvider: _provider);
  }

  //check complete puzzle;
  bool isComplete = false;
  bool isContinue = false;
  String loadKey = "";
  late List<List<int>> answer;
  late List<List<int>> submit;

  //UI
  late Size screenSize;
  bool showAppbar = false;
  late GameUI ui;
  Map<String, Color> settingColor = ThemeColor().getColor();


  @override
  void initState() {
    isContinue = widget.isContinue;

    //print("GameSceneStateSquareProvider is start, isContinue : ${widget.isContinue}");
    super.initState();
    _provider = SquareProvider(isContinue: isContinue);
    ui = GameUI(_provider);
    loadPuzzle();
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
    return ChangeNotifierProvider( // ChangeNotifierProvider 사용
      create: (context) => _provider, //ChangeNotifier class
      child: Consumer<SquareProvider>(
        builder: (context, provider, child) {
          screenSize = MediaQuery.of(context).size;
          ui.setScreenSize(screenSize);
          _provider = provider;

          return Scaffold(
            appBar: !showAppbar ? null : ui.getGameAppBar(context, settingColor["appBar"]!, settingColor["appIcon"]!),
            body: GestureDetector(
              onTap: () {
                setState(() {
                  showAppbar = !showAppbar;
                });
              },
              child: AbsorbPointer(
                absorbing: isComplete,
                child: Stack(
                  children: [
                    Container(
                      color: settingColor["background"],
                      child: InteractiveViewer(
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
                            children: _provider.getSquareField(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      width: 70,
                      height: 70,
                      left: 20, //margin
                      bottom: 110,
                      child: ElevatedButton(
                        onPressed: () {
                          // 버튼이 눌렸을 때 실행할 동작
                        },
                        child: const Icon(Icons.undo),
                      ),
                    ),
                    Positioned(
                      width: 70,
                      height: 70,
                      left: 20, //margin
                      bottom: 20,
                      child: ElevatedButton(
                        onPressed: () {
                          // 버튼이 눌렸을 때 실행할 동작
                        },
                        child: const Icon(Icons.redo),
                      ),
                    ),
                  ],
                )
              ),
            ),
          );
        },
      ),
    );
  }
}