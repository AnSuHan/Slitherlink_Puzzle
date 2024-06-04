import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/MainUI.dart';

class EnterSceneState extends State<EnterScene> {
  late Size screenSize;
  MainUI ui = MainUI();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(  // Replace YourWidget with your actual widget
        home: Builder(
        builder: (context) {
          screenSize = MediaQuery.of(context).size;
          ui.setScreenSize(screenSize);

          return Scaffold(
            backgroundColor: Colors.blueGrey,
            body: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ui.getMainMenu(context)
                  ],
                ),
                SizedBox(
                  height: ui.getTopMargin(),
                ),
                Flexible(
                  child: Center(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.005)),
                          child: const Text("Slitherlink",
                            style: TextStyle(
                              fontSize: 45, fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.1)),
                          child: ui.getStartButton(context),
                        ),
                        ui.getPuzzleType(context),
                      ],
                    ),
                  ),
                ),
              ],
            )
          );
        }
      )
    );
  }
}

class EnterScene extends StatefulWidget {
  const EnterScene({Key? key}) : super(key: key);

  @override
  EnterSceneState createState() => EnterSceneState();
}