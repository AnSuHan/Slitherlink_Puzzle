// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Front/HowToPlay.dart';
import '../ThemeColor.dart';
import '../provider/SquareProvider.dart';

// ignore: must_be_immutable
class SquareBox extends StatefulWidget {
  final bool isFirstRow;
  final bool isFirstColumn;
  //SquareBox's position in `puzzle`
  final int row;
  final int column;
  final bool isHowToPlay;

  //각 숫자는 색에 대한 의미를 같이 가짐
  //0 : 기본, 1~ : 유저가 선택, -4 : 유저가 x로 표기
  //-1 : 비활성(미선택), -2 : 비활성(선택), -3 : 정답을 나타내는 힌트, -5 : 오답을 나타내는 힌트 
  var up = 0, down = 0, left = 0, right = 0;
  var num = 0;
  var boxColor = 0; //0 : 일반, 1 : 강조(howToPlay에서만 사용)
  HowToPlayState howToPlay = HowToPlayState();

  SquareBox({
    Key? key,
    this.isFirstRow = false,
    this.isFirstColumn = false,
    required this.row,
    required this.column,
    this.isHowToPlay = false,
  }) : super(key: key);

  @override
  SquareBoxStateProvider createState() => SquareBoxStateProvider();

  void setColor(int color, String dir) {
    switch(dir) {
      case "down":
        down = color;
        break;
      case "right":
        right = color;
        break;
      case "up":
        up = color;
        break;
      case "left":
        left = color;
        break;
    }
  }

  void setBoxColor(int color) {
    boxColor = color;
  }
}

class SquareBoxStateProvider extends State<SquareBox> with SingleTickerProviderStateMixin {
  //setting color
  Map<String, Color> settingColor = ThemeColor().getColor();

  String lastClick = "";

  //for hint's animation
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late Animation<Color?> _wrongColorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.yellow,
    ).animate(_controller);

    _wrongColorAnimation = ColorTween(
      begin: Colors.black,
      end: Colors.red,
    ).animate(_controller);
  }

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
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    var boxColor = widget.boxColor;

    int row = widget.row;
    int column = widget.column;

    return Consumer<SquareProvider>(
      builder: (context, squareProvider, child) {
        boxColor = squareProvider.getBoxColor(row, column);

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
                SizedBox(
                  height: 10,
                  width: 50,
                  child: GestureDetector(
                    onTap: () async {
                      lastClick = "up";

                      setState(() {
                        if(up == 0 || up == -3) {
                          up = 1;
                        } else if(up >= 1 || up == -5) {
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

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, up: up,
                        callback: widget.isHowToPlay ? (int row, int col, String pos) async {
                          final howToPlayState = context.findAncestorStateOfType<HowToPlayState>();
                          if (howToPlayState != null) {
                            howToPlayState.checkStep(row, col, pos);
                          }
                        } : null
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _colorAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 10,
                          width: 50,
                          color: widget.up == -3 ? _colorAnimation.value ?? Colors.transparent
                              : widget.up == -5 ? _wrongColorAnimation.value ?? Colors.transparent : setupColor(widget.up),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.up == -4)
                                const Icon(
                                  Icons.close,
                                  color: Colors.black,
                                  size: 10,
                                ),
                            ],
                          ),
                        );
                      },
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
                !isFirstColumn ? Container() : SizedBox(
                  height: 50,
                  width: 10,
                  child: GestureDetector(
                    onTap: () async {
                      lastClick = "left";

                      setState(() {
                        if(left == 0 || left == -3) {
                          left = 1;
                        } else if(left >= 1 || left == -5) {
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

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, left: left,
                        callback: widget.isHowToPlay ? (int row, int col, String pos) async {
                          final howToPlayState = context.findAncestorStateOfType<HowToPlayState>();
                          if (howToPlayState != null) {
                            howToPlayState.checkStep(row, col, pos);
                          }
                        } : null
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _colorAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 50,
                          width: 10,
                          color: widget.left == -3 ? _colorAnimation.value ?? Colors.transparent
                              : widget.left == -5 ? _wrongColorAnimation.value ?? Colors.transparent : setupColor(widget.left),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.left == -4)
                                const Icon(
                                  Icons.close,
                                  color: Colors.black,
                                  size: 10,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  height: 50,
                  width: 50,
                  color: boxColor == 0 ? settingColor["box"] : settingColor["boxHighLight"],
                  child: Center(
                    child: Text(num.toString(), style: TextStyle(color: settingColor["number"])),
                  ),
                ),
                SizedBox(
                  height: 50,
                  width: 10,
                  child: GestureDetector(
                    onTap: () async {
                      lastClick = "right";

                      setState(() {
                        if(right == 0 || right == -3) {
                          right = 1;
                        } else if(right >= 1 || right == -5) {
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

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, right: right,
                        callback: widget.isHowToPlay ? (int row, int col, String pos) async {
                          final howToPlayState = context.findAncestorStateOfType<HowToPlayState>();
                          if (howToPlayState != null) {
                            howToPlayState.checkStep(row, col, pos);
                          }
                        } : null
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _colorAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 50,
                          width: 10,
                          color: widget.right == -3 ? _colorAnimation.value ?? Colors.transparent
                              : widget.right == -5 ? _wrongColorAnimation.value ?? Colors.transparent : setupColor(widget.right),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.right == -4)
                                const Icon(
                                  Icons.close,
                                  color: Colors.black,
                                  size: 10,
                                ),
                            ],
                          ),
                        );
                      },
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
                SizedBox(
                  height: 10,
                  width: 50,
                  child: GestureDetector(
                    onTap: () async {
                      lastClick = "down";

                      setState(() {
                        if(down == 0 || down == -3) {
                          down = 1;
                        } else if(down >= 1 || down == -5) {
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

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, down: down,
                        callback: widget.isHowToPlay ? (int row, int col, String pos) async {
                          final howToPlayState = context.findAncestorStateOfType<HowToPlayState>();
                          if (howToPlayState != null) {
                            howToPlayState.checkStep(row, col, pos);
                          }
                        } : null
                      );
                    },
                    child: AnimatedBuilder(
                      animation: _colorAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 10,
                          width: 50,
                          color: widget.down == -3 ? _colorAnimation.value ?? Colors.transparent
                              : widget.down == -5 ? _wrongColorAnimation.value ?? Colors.transparent : setupColor(widget.down),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (widget.down == -4)
                                const Icon(
                                  Icons.close,
                                  color: Colors.black,
                                  size: 10,
                                ),
                            ],
                          ),
                        );
                      },
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