// ignore_for_file: file_names
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shared header AppBar used by Square, Triangle, and Hexagon game scenes.
///
/// Exposes two popup menus:
///   • Bookmark (Red/Green/Blue × save/load/clear)
///   • Menu (restart / new_game / hint)
///
/// State is held externally — pass in the current `labelState` list
/// (length 3, each element `"save"` or `"load"`) and the scene is expected to
/// update it and call `setState` inside the save/load/clear callbacks so the
/// popup text and enabled flags refresh on the next rebuild.
class PuzzleAppBar {
  static const List<String> colorNames = ["Red", "Green", "Blue"];

  static int _colorIdx(String color) {
    switch (color) {
      case "Red": return 0;
      case "Green": return 1;
      case "Blue": return 2;
    }
    return -1;
  }

  static AppBar build({
    required BuildContext context,
    required Color appbarColor,
    required Color iconColor,
    required AppLocalizations appLocalizations,
    required List<String> labelState,
    required VoidCallback onExit,
    required VoidCallback onRestart,
    required VoidCallback onNewGame,
    required VoidCallback onHint,
    required Future<void> Function(int colorIdx) onSaveBookmark,
    required Future<void> Function(int colorIdx) onLoadBookmark,
    required Future<void> Function(int colorIdx) onClearBookmark,
    VoidCallback? onAutoSolve,
  }) {
    return AppBar(
      backgroundColor: appbarColor,
      foregroundColor: iconColor,
      leading: InkWell(
        onTap: onExit,
        child: Icon(Icons.keyboard_backspace, color: iconColor),
      ),
      actions: <Widget>[
        SizedBox(
          width: 50,
          height: 50,
          child: PopupMenuButton<String>(
            onSelected: (String result) async {
              final tokens = result.split(" ");
              final color = tokens[2];
              final idx = _colorIdx(color);
              if (idx < 0) return;

              Text snack = const Text("");
              switch (tokens[0]) {
                case "click":
                  snack = Text('${labelState[idx]} data with $color');
                  break;
                case "clear":
                  snack = Text('clear $color data');
                  break;
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: snack,
                duration: const Duration(milliseconds: 500),
              ));

              if (tokens[0] == "click") {
                if (labelState[idx] == "save") {
                  await onSaveBookmark(idx);
                } else {
                  await onLoadBookmark(idx);
                }
              } else if (tokens[0] == "clear") {
                await onClearBookmark(idx);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              _buildBookmarkItem(appLocalizations, labelState[0], "Red", "red", Colors.red),
              _buildBookmarkItem(appLocalizations, labelState[1], "Green", "green", Colors.green),
              _buildBookmarkItem(appLocalizations, labelState[2], "Blue", "blue", Colors.blue),
              _buildClearItem(appLocalizations, labelState[0], "Red", "red", Colors.red),
              _buildClearItem(appLocalizations, labelState[1], "Green", "green", Colors.green),
              _buildClearItem(appLocalizations, labelState[2], "Blue", "blue", Colors.blue),
            ],
            icon: const Icon(Icons.bookmarks),
          ),
        ),
        SizedBox(
          width: 50,
          height: 50,
          child: PopupMenuButton<String>(
            onSelected: (String result) {
              final tokens = result.split(" ");
              if (tokens.length < 2) return;
              switch (tokens[1]) {
                case "restart":
                  onRestart();
                  break;
                case "new_game":
                  onNewGame();
                  break;
                case "hint":
                  onHint();
                  break;
                case "auto_solve":
                  onAutoSolve?.call();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'menu restart',
                child: Text(appLocalizations.translate('restart')),
              ),
              PopupMenuItem<String>(
                value: 'menu new_game',
                child: Text(appLocalizations.translate('new_game')),
              ),
              PopupMenuItem<String>(
                value: 'menu hint',
                child: Text(appLocalizations.translate('hint')),
              ),
              if (onAutoSolve != null)
                PopupMenuItem<String>(
                  value: 'menu auto_solve',
                  child: Row(
                    children: [
                      const Icon(Icons.auto_fix_high, size: 18),
                      const SizedBox(width: 8),
                      Text(appLocalizations.translate('auto_solve')),
                    ],
                  ),
                ),
            ],
            icon: const Icon(Icons.menu),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  static PopupMenuItem<String> _buildBookmarkItem(
      AppLocalizations appLocalizations,
      String state,
      String colorValue,
      String localizationKey,
      Color color) {
    return PopupMenuItem<String>(
      value: 'click Label $colorValue',
      child: Row(
        children: [
          Icon(Icons.bookmark_sharp, color: color),
          Text(
            state == "save"
                ? appLocalizations.translateComplex("save", localizationKey)
                : appLocalizations.translateComplex("load", localizationKey),
          ),
        ],
      ),
    );
  }

  static PopupMenuItem<String> _buildClearItem(
      AppLocalizations appLocalizations,
      String state,
      String colorValue,
      String localizationKey,
      Color color) {
    return PopupMenuItem<String>(
      value: 'clear Label $colorValue',
      enabled: state == "load",
      child: Row(
        children: [
          Icon(Icons.bookmark_remove, color: color),
          Text(appLocalizations.translateComplex("clear", localizationKey)),
        ],
      ),
    );
  }
}
