import 'package:flutter/material.dart';

import '../Scene/GameSceneSquareProvider.dart';
import '../ThemeColor.dart';
import '../provider/SquareProviderProvider.dart';

// ignore: must_be_immutable
class SquareBoxProvider extends StatefulWidget {
  final bool isFirstRow;
  final bool isFirstColumn;
  //SquareBox's position in `puzzle`
  final int row;
  final int column;

  //0 : 기본, 1~ : 유저가 선택, -3 : 힌트
  //-1 : 비활성(미선택), -2 : 비활성(선택)
  var up = 0, down = 0, left = 0, right = 0;
  var num = 0;

  Color colorUp, colorDown, colorLeft, colorRight;

  SquareBoxProvider({
    Key? key,
    this.isFirstRow = false,
    this.isFirstColumn = false,
    required this.row,
    required this.column,
  }) :
        colorUp = const Color(0xFFC0C0C0),
        colorDown = const Color(0xFFC0C0C0),
        colorLeft = const Color(0xFFC0C0C0),
        colorRight = const Color(0xFFC0C0C0),
        super(key: key);

  @override
  SquareBoxStateProvider createState() => SquareBoxStateProvider();
}

class SquareBoxStateProvider extends State<SquareBoxProvider> {
  //setting color
  Map<String, Color> settingColor = ThemeColor().getColor();
  ThemeColor themeColor = ThemeColor();

  late Color colorUp;
  late Color colorDown;
  late Color colorLeft;
  late Color colorRight;

  String lastClick = "";
  //late GameSceneStateSquareProvider gameField;

  @override
  void initState() {
    super.initState();
    _computeColors();
  }

  @override
  void didUpdateWidget(covariant SquareBoxProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.up != oldWidget.up ||
        widget.down != oldWidget.down ||
        widget.left != oldWidget.left ||
        widget.right != oldWidget.right ||
        widget.row != oldWidget.row ||
        widget.column != oldWidget.column ||
        widget.colorUp != oldWidget.colorUp ||
        widget.colorDown != oldWidget.colorDown ||
        widget.colorLeft != oldWidget.colorLeft ||
        widget.colorRight != oldWidget.colorRight) {
      _computeColors();
    }
  }

  void _computeColors() {
    colorUp = getLineColor(context, widget.up, thisColor: widget.colorUp, row: widget.row, column: widget.column);
    colorDown = getLineColor(context, widget.down, thisColor: widget.colorDown, row: widget.row, column: widget.column);
    colorLeft = getLineColor(context, widget.left, thisColor: widget.colorLeft, row: widget.row, column: widget.column);
    colorRight = getLineColor(context, widget.right, thisColor: widget.colorRight, row: widget.row, column: widget.column);
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirstRow = widget.isFirstRow;
    final bool isFirstColumn = widget.isFirstColumn;

    var up = widget.up;
    var down = widget.down;
    var left = widget.left;
    var right = widget.right;
    var num = widget.num;

    int row = widget.row;
    int column = widget.column;

    return Column(
      children: [
        !isFirstRow ? Container() : Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isFirstColumn ? Row(
              children: [
                Container(
                  height: 5,
                  width: 5,
                  color: Colors.grey,
                ),
                const SizedBox(
                  width: 2.5,
                ),
              ],
            ) : Container(),
            Container(
              height: 10,
              width: 50,
              color: getLineColor(context, up, thisColor: colorUp, row: row, column: column, dir: "up"),
              child: GestureDetector(
                onTap: () {
                  lastClick = "up";

                  setState(() {
                    if(up == 0 || up == -3) {
                      up = 1;
                    } else if(up >= 1) {
                      up = 0;
                    } else if(up == -1) {
                      up = -2;
                    } else if(up == -2) {
                      up = -1;
                    }
                    widget.up = up;
                    colorUp = getLineColor(context, up, thisColor: colorUp, row: row, column: column, dir: "up");
                    widget.colorUp = colorUp;
                    if(up >= 1) {
                      up = setupData(colorUp);
                      colorUp = setupColor(up);
                    }
                  });

                  //gameField.checkCompletePuzzle(context);
                  //gameField.updatePuzzle();
                },
              ),
            ),
            const SizedBox(
              width: 2.5,
            ),
            Container(
              height: 5,
              width: 5,
              color: Colors.grey,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            !isFirstColumn ? Container() : Container(
              height: 50,
              width: 10,
              color: getLineColor(context, left, thisColor: colorLeft, row: row, column: column, dir: "left"),
              child: GestureDetector(
                onTap: () {
                  lastClick = "left";

                  setState(() {
                    if(left == 0 || left == -3) {
                      left = 1;
                    } else if(left >= 1) {
                      left = 0;
                    } else if(left == -1) {
                      left = -2;
                    } else if(left == -2) {
                      left = -1;
                    }
                    widget.left = left;
                    colorLeft = getLineColor(context, left, thisColor: colorLeft, row: row, column: column, dir: "left");
                    widget.colorLeft = colorLeft;
                    if(left >= 1) {
                      left = setupData(colorLeft);
                      colorLeft = setupColor(left);
                    }
                  });

                  //gameField.checkCompletePuzzle(context);
                  //gameField.updatePuzzle();
                },
              ),
            ),
            Container(
              height: 50,
              width: 50,
              color: settingColor["box"],
              child: Center(
                child: Text(num.toString(), style: TextStyle(color: settingColor["number"])),
              ),
            ),
            Container(
              height: 50,
              width: 10,
              color: getLineColor(context, right, thisColor: colorRight, row: row, column: column, dir: "right"),
              child: GestureDetector(
                onTap: () {
                  lastClick = "right";

                  setState(() {
                    if(right == 0 || right == -3) {
                      right = 1;
                    } else if(right >= 1) {
                      right = 0;
                    } else if(right == -1) {
                      right = -2;
                    } else if(right == -2) {
                      right = -1;
                    }
                    widget.right = right;
                    colorRight = getLineColor(context, right, thisColor: colorRight, row: row, column: column, dir: "right");
                    widget.colorRight = colorRight;
                    if(right >= 1) {
                      right = setupData(colorRight);
                      colorRight = setupColor(right);
                    }
                  });

                  //gameField.checkCompletePuzzle(context);
                  //gameField.updatePuzzle();
                },
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isFirstColumn ? Row(
              children: [
                Container(
                  height: 5,
                  width: 5,
                  color: Colors.grey,
                ),
                const SizedBox(
                  width: 2.5,
                ),
              ],
            ) : Container(),
            Container(
              height: 10,
              width: 50,
              color: getLineColor(context, down, thisColor: colorDown, row: row, column: column, dir: "down"),
              child: GestureDetector(
                onTap: () {
                  lastClick = "down";

                  setState(() {
                    if(down == 0 || down == -3) {
                      down = 1;
                    } else if(down >= 1) {
                      down = 0;
                    } else if(down == -1) {
                      down = -2;
                    } else if(down == -2) {
                      down = -1;
                    }
                    widget.down = down;
                    colorDown = getLineColor(context, down, thisColor: colorDown, row: row, column: column, dir: "down");
                    widget.colorDown = colorDown;
                    if(down >= 1) {
                      down = setupData(colorDown);
                      colorDown = setupColor(down);
                    }
                  });

                  //gameField.checkCompletePuzzle(context);
                  //gameField.updatePuzzle();
                },
              ),
            ),
            const SizedBox(
              width: 2.5,
            ),
            Container(
              height: 5,
              width: 5,
              color: Colors.grey,
            ),
          ],
        ),
      ],
    );
  }

  Color getLineColor(BuildContext context, int type, {Color? thisColor, int? row, int? column, String? dir}) {
    Color? color = thisColor;
    //0 : 기본, 1 : 유저가 선택, -3 : 힌트
    //-1 : 비활성(미선택), -2 : 비활성(선택)
    //print("type : $type, thisColor : $thisColor");
    switch(type) {
      case 0:
        color = themeColor.getLineColor(type: 0);
        break;
      case 1:
        Set<Color> colors = isExistNearColor();

        //use new color
        ///TODO : 현재 색을 변경해야 하는 라인 1개는 찾을 수 있지만, 색을 변경해도 UI에 반영이 되지 않음
        ///TODO : 따라서 Triangle의 작성을 시작하고 해당 클래스는 instance로만 작성
        if(colors.isEmpty) {
          color = themeColor.getLineColor();
        }
        else {
          //set only this color
          if(colors.length == 1) {
            print("colors : $colors");
            color = colors.first;
          }
          //change all near colors
          else if(colors.length == 2){
            color = colors.first;
            //두 개의 색이 만난 경우 변경해야 하는 라인들의 목록
            /*
            List<dynamic> changes = gameField.getOldColorList(row!, column!, dir!, color);
            print("_____ getOldColorList _____");
            for(int i = 0 ; i < changes.length ; i++) {
              print("changes : ${changes[i]}");
              //gameField.changeColor(context, changes[i][0], changes[i][1], changes[i][2], color);
            }
             */
          }
          else {
            throw Exception("UnExpected Exception occurred");
          }
        }
        break;
      case -1:
        color = themeColor.getLineColor(type: -1);
        break;
      case -2:
        color = themeColor.getLineColor(type: -2);
        break;
      case -3:
        color = themeColor.getLineColor(type: -3);
        break;
      default:
        color = Colors.grey;
    }

    thisColor = color;
    return color;
  }

  Set<Color> isExistNearColor() {
    List<Color> noUse = [
      themeColor.getLineColor(type: 0),   //normal
      themeColor.getLineColor(type: -1),  //disable
      themeColor.getLineColor(type: -2),  //disable select
      themeColor.getLineColor(type: -3)   //hint
    ];

    /*
    Set<Color> colors = gameField.getNearColor(widget.row, widget.column, lastClick);
    for(int i = 0 ; i < noUse.length ; i++) {
      colors.remove(noUse[i]);
    }
     */

    return {};
  }

  //return over 1
  int setupData(Color color) {
    Map<Color, String> items = {};

    ThemeColor().lineColor.forEach((key, value) {
      items[value] = key;
    });
    String value = items[color]!.split("_")[1];
    int intValue = int.parse(value);

    print("setUpData $intValue");
    return intValue;
  }

  Color setupColor(int value) {
    String key = "line_";
    if(value < 10) {
      key += "0$value";
    }
    else {
      key += value.toString();
    }
    return ThemeColor().lineColor[key]!;
  }
}