// ignore_for_file: file_names
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

import '../MakePuzzle/ReadSquare.dart';
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
  String loadKey = "square_small_0_test";
  late List<List<int>> answer;
  late List<List<int>> submit;

  late Size screenSize;

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
                              ..._provider.getSquareField(),
                              Text(""),
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
}

/*

 */

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