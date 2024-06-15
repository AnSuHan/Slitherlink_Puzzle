import 'package:flutter/material.dart';

import '../Scene/GameSceneStateSquare.dart';
import '../ThemeColor.dart';

// ignore: must_be_immutable
class SquareBox extends StatefulWidget {
  final bool isFirstRow;
  final bool isFirstColumn;
  //SquareBox's position in `puzzle`
  final int row;
  final int column;

  //0 : 기본, 1 : 유저가 선택, 2 : 힌트
  //-1 : 비활성(미선택), -2 : 비활성(선택)
  var up = 0, down = 0, left = 0, right = 0;
  var num = 0;

  Color colorUp = const Color(0xFF000000), colorDown = const Color(0xFF000000),
    colorLeft = const Color(0xFF000000), colorRight = const Color(0xFF000000);

  SquareBox({
    Key? key,
    this.isFirstRow = false,
    this.isFirstColumn = false,
    required this.row,
    required this.column,
  }) : super(key: key);

  @override
  SquareBoxState createState() => SquareBoxState();
}

class SquareBoxState extends State<SquareBox> {
  //setting color
  Map<String, Color> settingColor = ThemeColor().getColor();
  ThemeColor themeColor = ThemeColor();

  late Color colorUp;
  late Color colorDown;
  late Color colorLeft;
  late Color colorRight;

  String lastClick = "";

  @override
  void initState() {
    super.initState();
    _computeColors();
  }

  @override
  void didUpdateWidget(covariant SquareBox oldWidget) {
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
    colorUp = getLineColor(widget.up, thisColor: widget.colorUp, row: widget.row, column: widget.column);
    colorDown = getLineColor(widget.down, thisColor: widget.colorDown, row: widget.row, column: widget.column);
    colorLeft = getLineColor(widget.left, thisColor: widget.colorLeft, row: widget.row, column: widget.column);
    colorRight = getLineColor(widget.right, thisColor: widget.colorRight, row: widget.row, column: widget.column);
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
                color: colorUp,
                child: GestureDetector(
                  onTap: () {
                    lastClick = "up";
                    setState(() {
                      if(up == 0 || up == 2) {
                        up = 1;
                      } else if(up == 1) {
                        up = 0;
                      } else if(up == -1) {
                        up = -2;
                      } else if(up == -2) {
                        up = -1;
                      }
                      widget.up = up;
                      colorUp = getLineColor(up, thisColor: colorUp, row: row, column: column);
                      widget.colorUp = colorUp;
                    });
                    GameSceneStateSquare.checkCompletePuzzle(context);
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
              color: colorLeft,
              child: GestureDetector(
                onTap: () {
                  lastClick = "left";
                  setState(() {
                    if(left == 0 || left == 2) {
                      left = 1;
                    } else if(left == 1) {
                      left = 0;
                    } else if(left == -1) {
                      left = -2;
                    } else if(left == -2) {
                      left = -1;
                    }
                    widget.left = left;
                    colorLeft = getLineColor(left, thisColor: colorLeft, row: row, column: column);
                    widget.colorLeft = colorLeft;
                  });
                  GameSceneStateSquare.checkCompletePuzzle(context);
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
              color: colorRight,
              child: GestureDetector(
                onTap: () {
                  lastClick = "right";
                  setState(() {
                    if(right == 0 || right == 2) {
                      right = 1;
                    } else if(right == 1) {
                      right = 0;
                    } else if(right == -1) {
                      right = -2;
                    } else if(right == -2) {
                      right = -1;
                    }
                    widget.right = right;
                    colorRight = getLineColor(right, thisColor: colorRight, row: row, column: column);
                    widget.colorRight = colorRight;
                  });
                  GameSceneStateSquare.checkCompletePuzzle(context);
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
              color: colorDown,
              child: GestureDetector(
                onTap: () {
                  lastClick = "down";
                  setState(() {
                    if(down == 0 || down == 2) {
                      down = 1;
                    } else if(down == 1) {
                      down = 0;
                    } else if(down == -1) {
                      down = -2;
                    } else if(down == -2) {
                      down = -1;
                    }
                    widget.down = down;
                    colorDown = getLineColor(down, thisColor: colorDown, row: row, column: column);
                    widget.colorDown = colorDown;
                  });
                  GameSceneStateSquare.checkCompletePuzzle(context);
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

  Color getLineColor(int type, {Color? thisColor, int? row, int? column}) {
    Color? color = thisColor;
    //0 : 기본, 1 : 유저가 선택, 2 : 힌트
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
            color = colors.first;
          }
          //change all near colors
          else {
            ///TODO : 두 개 이상의 색이 있는 경우 모두 colors.first로 변경 필요
            color = colors.first;
          }
        }
        break;
      case 2:
        color = themeColor.getLineColor(type: 2);
        break;
      case -1:
        color = themeColor.getLineColor(type: -1);
        break;
      case -2:
        color = themeColor.getLineColor(type: -2);
        break;
      default:
        color = Colors.grey;
    }

    return color;
  }

  Set<Color> isExistNearColor() {
    List<Color> noUse = [themeColor.getLineColor(type: 0), themeColor.getLineColor(type: 2), themeColor.getLineColor(type: -1), themeColor.getLineColor(type: -2)];

    Set<Color> colors = GameSceneStateSquare.getNearColor(widget.row, widget.column, lastClick);
    for(int i = 0 ; i < noUse.length ; i++) {
      colors.remove(noUse[i]);
    }

    return colors;
  }
}