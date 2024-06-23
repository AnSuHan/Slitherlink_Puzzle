import 'package:flutter/material.dart';

import '../ThemeColor.dart';

// ignore: must_be_immutable
class SquareBoxProvider extends StatefulWidget {
  final bool isFirstRow;
  final bool isFirstColumn;
  //SquareBox's position in `puzzle`
  final int row;
  final int column;

  //각 숫자는 색에 대한 의미를 같이 가짐
  //0 : 기본, 1~ : 유저가 선택, -3 : 힌트
  //-1 : 비활성(미선택), -2 : 비활성(선택)
  var up = 0, down = 0, left = 0, right = 0;
  var num = 0;

  SquareBoxProvider({
    Key? key,
    this.isFirstRow = false,
    this.isFirstColumn = false,
    required this.row,
    required this.column,
  }) : super(key: key);

  @override
  SquareBoxStateProvider createState() => SquareBoxStateProvider();
}

class SquareBoxStateProvider extends State<SquareBoxProvider> {
  //setting color
  Map<String, Color> settingColor = ThemeColor().getColor();
  ThemeColor themeColor = ThemeColor();

  String lastClick = "";

  @override
  void didUpdateWidget(covariant SquareBoxProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.up != oldWidget.up ||
        widget.down != oldWidget.down ||
        widget.left != oldWidget.left ||
        widget.right != oldWidget.right ||
        widget.row != oldWidget.row ||
        widget.column != oldWidget.column) {
    }
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
              color: setupColor(widget.up),
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
              color: setupColor(widget.left),
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
              color: setupColor(widget.right),
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
              color: setupColor(widget.down),
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

  Color getLineColor(BuildContext context, int type, {int? row, int? column, String? dir}) {
    Color? color = Colors.black;
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
            //두 개의 색이 만난 경우 변경해야 하는 라인의 목록
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
    if(value <= 0) {
      switch(value) {
        case 0:
          key += "normal";
          break;
        case -1:
          key += "disable";
          break;
        case -2:
          key += "wrong";
          break;
        case -3:
          key += "hint";
          break;
      }
    }
    else if(value < 10) {
      key += "0$value";
    }
    else {
      key += value.toString();
    }
    return ThemeColor().lineColor[key]!;
  }
}