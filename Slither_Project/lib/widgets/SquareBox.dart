import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ThemeColor.dart';
import '../provider/SquareProvider.dart';

// ignore: must_be_immutable
class SquareBox extends StatefulWidget {
  final bool isFirstRow;
  final bool isFirstColumn;
  //SquareBox's position in `puzzle`
  final int row;
  final int column;

  //각 숫자는 색에 대한 의미를 같이 가짐
  //0 : 기본, 1~ : 유저가 선택, -4 : 유저가 x로 표기
  //-1 : 비활성(미선택), -2 : 비활성(선택), -3 : 힌트
  var up = 0, down = 0, left = 0, right = 0;
  var num = 0;

  SquareBox({
    Key? key,
    this.isFirstRow = false,
    this.isFirstColumn = false,
    required this.row,
    required this.column,
  }) : super(key: key);

  @override
  SquareBoxStateProvider createState() => SquareBoxStateProvider();
}

class SquareBoxStateProvider extends State<SquareBox> {
  //setting color
  Map<String, Color> settingColor = ThemeColor().getColor();
  ThemeColor themeColor = ThemeColor();

  String lastClick = "";

  @override
  void didUpdateWidget(covariant SquareBox oldWidget) {
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

    return Consumer<SquareProvider>(
      builder: (context, squareProvider, child) {
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
                          up = -4;
                        } else if(up == -1) {
                          up = -2;
                        } else if(up == -2) {
                          up = -1;
                        } else if(up == -4) {
                          up = 0;
                        }
                        widget.up = up;
                      });

                      Provider.of<SquareProvider>(context, listen: false)
                          .updateSquareBox(row, column, up: up);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 10,
                          width: 50,
                          color: setupColor(widget.up),
                        ),
                        if (widget.up == -4)
                          const Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 10,
                          ),
                      ],
                    ),
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
                          left = -4;
                        } else if(left == -1) {
                          left = -2;
                        } else if(left == -2) {
                          left = -1;
                        } else if(left == -4) {
                          left = 0;
                        }
                        widget.left = left;
                      });

                      Provider.of<SquareProvider>(context, listen: false)
                          .updateSquareBox(row, column, left: left);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 10,
                          width: 50,
                          color: setupColor(widget.left),
                        ),
                        if (widget.left == -4)
                          const Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 10,
                          ),
                      ],
                    ),
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
                          right = -4;
                        } else if(right == -1) {
                          right = -2;
                        } else if(right == -2) {
                          right = -1;
                        } else if(right == -4) {
                          right = 0;
                        }
                        widget.right = right;
                      });

                      Provider.of<SquareProvider>(context, listen: false)
                          .updateSquareBox(row, column, right: right);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 10,
                          width: 50,
                          color: setupColor(widget.right),
                        ),
                        if (widget.right == -4)
                          const Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 10,
                          ),
                      ],
                    ),
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
                          down = -4;
                        } else if(down == -1) {
                          down = -2;
                        } else if(down == -2) {
                          down = -1;
                        } else if(down == -4) {
                          down = 0;
                        }
                        widget.down = down;
                      });

                      Provider.of<SquareProvider>(context, listen: false)
                          .updateSquareBox(row, column, down: down);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 10,
                          width: 50,
                          color: setupColor(widget.down),
                        ),
                        if (widget.down == -4)
                          const Icon(
                            Icons.close,
                            color: Colors.black,
                            size: 10,
                          ),
                      ],
                    ),
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
    );
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
        case -4:
          key += "x";
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