import 'package:flutter/material.dart';

class SquareBox extends StatefulWidget {
  final bool isFirstRow;
  final bool isFirstColumn;

  //0 : 기본, 1 : 유저가 선택, 2 : 힌트
  //-1 : 비활성(미선택), -2 : 비활성(선택)
  var up = 0, down = 0, left = 0, right = 0;

  SquareBox({
    Key? key,
    this.isFirstRow = false,
    this.isFirstColumn = false
  }) : super(key: key);

  @override
  SquareBoxState createState() => SquareBoxState();
}

class SquareBoxState extends State<SquareBox> {
  @override
  Widget build(BuildContext context) {
    final bool isFirstRow = widget.isFirstRow;
    final bool isFirstColumn = widget.isFirstColumn;

    var up = widget.up;
    var down = widget.down;
    var left = widget.left;
    var right = widget.right;

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
                color: getLineColor(up),
                child: GestureDetector(
                  onTap: () {
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
                    });
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
              color: getLineColor(left),
              child: GestureDetector(
                onTap: () {
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
                  });
                },
              ),
            ),
            Container(
              height: 50,
              width: 50,
              child: Center(
                child: Text("1"),
              ),
            ),
            Container(
              height: 50,
              width: 10,
              color: getLineColor(right),
              child: GestureDetector(
                onTap: () {
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
                  });
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
              color: getLineColor(down),
              child: GestureDetector(
                onTap: () {
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
                  });
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

  Color getLineColor(int type) {
    Color color;

    switch(type) {
      case 0:
        color = Colors.grey;
        break;
      case 1:
        color = Colors.black;
        break;
      case 2:
        color = Colors.yellowAccent;
        break;
      case -1:
        color = Colors.grey.withOpacity(0.8);
        break;
      case -2:
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return color;
  }
}