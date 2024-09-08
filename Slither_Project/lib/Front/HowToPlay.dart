// ignore_for_file: file_names
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

class HowToPlay extends StatefulWidget {
  const HowToPlay({
    Key? key
  }) : super(key: key);

  @override
  HowToPlayState createState() => HowToPlayState();
}

class HowToPlayState extends State<HowToPlay> {
  late PageController controller;

  @override
  void initState() {
    super.initState();
    controller = PageController(
      initialPage: 0,
      viewportFraction: 0.8,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: ScrollConfiguration(
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
    );
  }
}

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