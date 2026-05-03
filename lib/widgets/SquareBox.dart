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

  /// Per-direction onTap cycle. Used by the line GestureDetectors and the
  /// transparent box-overlay tap zones (which widen each line's hit area).
  ///   0/-3   → fresh chain colour
  ///   color/-5 → -4 (X)
  ///   -1     → -2 (mark "I disagree with the auto-disable")
  ///   -2     → -1 (revert to auto-disabled)
  ///   -4     → 0
  int _cycleEdgeValue(int v) {
    if (v == 0 || v == -3) return ThemeColor().getNormalRandom();
    if (v >= 1 || v == -5) return -4;
    if (v == -1) return -2;
    if (v == -2) return -1;
    if (v == -4) return 0;
    return v;
  }

  /// Cycle the edge in [dir] and dispatch to the provider. Used by the
  /// transparent box-edge overlays that widen each line's tap range — the
  /// existing line GestureDetectors still handle direct taps on the line.
  Future<void> _tapEdgeFromOverlay(String dir) async {
    setState(() {
      lastClick = dir;
      switch (dir) {
        case "up":
          widget.up = _cycleEdgeValue(widget.up);
          break;
        case "down":
          widget.down = _cycleEdgeValue(widget.down);
          break;
        case "left":
          widget.left = _cycleEdgeValue(widget.left);
          break;
        case "right":
          widget.right = _cycleEdgeValue(widget.right);
          break;
      }
    });
    final provider = Provider.of<SquareProvider>(context, listen: false);
    final cb = widget.isHowToPlay
        ? (int r, int c, String p) async {
            final howToPlayState =
                context.findAncestorStateOfType<HowToPlayState>();
            if (howToPlayState != null) {
              howToPlayState.checkStep(r, c, p);
            }
          }
        : null;
    await provider.updateSquareBox(
      widget.row, widget.column,
      up: dir == "up" ? widget.up : null,
      down: dir == "down" ? widget.down : null,
      left: dir == "left" ? widget.left : null,
      right: dir == "right" ? widget.right : null,
      callback: cb,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirstRow = widget.isFirstRow;
    final bool isFirstColumn = widget.isFirstColumn;

    final int row = widget.row;
    final int column = widget.column;

    // Read all per-edge state via widget.X directly inside the Consumer
    // builder below — provider.notifyListeners triggers Consumer rebuild but
    // does NOT re-run State.build, so any var captured here at State.build
    // time goes stale as soon as another widget mutates puzzle[r][c] (chain
    // merge in updateSquareBox, or auto-disable in the propagators).
    return Consumer<SquareProvider>(
      builder: (context, squareProvider, child) {
        final int boxColor = squareProvider.getBoxColor(row, column);

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
                        widget.up = _cycleEdgeValue(widget.up);
                      });

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, up: widget.up,
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
                        widget.left = _cycleEdgeValue(widget.left);
                      });

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, left: widget.left,
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
                Builder(builder: (_) {
                  final int num = widget.num;
                  // Read edge state via widget.X so re-runs triggered by
                  // provider.notifyListeners (without a State.build) see the
                  // latest values written by chain merge / propagation.
                  final int active =
                      (widget.up    >= 1 ? 1 : 0) +
                      (widget.down  >= 1 ? 1 : 0) +
                      (widget.left  >= 1 ? 1 : 0) +
                      (widget.right >= 1 ? 1 : 0);
                  // Dim only when this cell has a visible clue and exactly
                  // `num` lines are drawn. Hidden clues (num<0) skip dimming
                  // entirely (text isn't rendered for them either).
                  final Color baseNumColor = settingColor["number"] ?? Colors.black;
                  final Color textColor = (num >= 0 && active == num)
                      ? baseNumColor.withOpacity(0.35)
                      : baseNumColor;
                  // 14 px wide transparent strips along each edge widen the
                  // line tap zone into the box face — corners go to up/down
                  // because they're stacked last (top of stack wins hits).
                  return SizedBox(
                    height: 50,
                    width: 50,
                    child: Stack(
                      children: [
                        Container(
                          height: 50,
                          width: 50,
                          color: boxColor == 0 ? settingColor["box"] : settingColor["boxHighLight"],
                          child: num < 0 ? null : Center(
                            child: Text(num.toString(), style: TextStyle(color: textColor)),
                          ),
                        ),
                        Positioned(
                          left: 0, top: 0, bottom: 0, width: 14,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _tapEdgeFromOverlay("left"),
                          ),
                        ),
                        Positioned(
                          right: 0, top: 0, bottom: 0, width: 14,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _tapEdgeFromOverlay("right"),
                          ),
                        ),
                        Positioned(
                          left: 0, right: 0, top: 0, height: 14,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _tapEdgeFromOverlay("up"),
                          ),
                        ),
                        Positioned(
                          left: 0, right: 0, bottom: 0, height: 14,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _tapEdgeFromOverlay("down"),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                SizedBox(
                  height: 50,
                  width: 10,
                  child: GestureDetector(
                    onTap: () async {
                      lastClick = "right";

                      setState(() {
                        widget.right = _cycleEdgeValue(widget.right);
                      });

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, right: widget.right,
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
                        widget.down = _cycleEdgeValue(widget.down);
                      });

                      await Provider.of<SquareProvider>(context, listen: false)
                        .updateSquareBox(row, column, down: widget.down,
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