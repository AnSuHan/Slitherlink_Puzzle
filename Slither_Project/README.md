# slitherlink_project

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## SharedPreference Key Handling

### loading puzzle key (init and restart) : shape_size_progress (ex. square_small_0)
- generated when click start button in **MainUI().getStartButton()**
- deleted puzzle key(including continue) when complete puzzle in **SquareProvider().showComplete()**
~~loading submit key (continue) : shape_size_progress_continue (ex. square_small_0_continue)
- generated when click back button in **GameUI().getGameAppBar()**
- deleted when clear puzzle with passing **MainUI().getProgressPuzzle()'s key**~~

### game label key (save and load) : shape_size_progress_color (ex. square_small_0_Red, square_small_0_Green, square_small_0_Blue)
- generated when click label in **GameUI().saveData()**
- deleted when clear label & clear puzzle in **GameUI().clearLabel() / SquareProvider().showComplete()**

### game label key (for controlling do) : shape_size_progress_color_`do` (ex. square_small_0_Red_do, square_small_0_Green_do, square_small_0_Blue_do)
- generated when click label in **SquareProvider().controlDo()**
- deleted when clear label & clear puzzle in **GameUI().clearLabel() / SquareProvider().showComplete()**

### do-value keys (controlling progress) : shape_size_progress_color_`doValue` (ex. square_small_0_Red_doValue, square_small_0__doValue {`this means now state when back without clear`})
- generated when click label and quit puzzle in **/ SquareProvider().quitDoValue()**
- deleted when clear puzzle in **SquareProvider().showComplete()**

    doSubmit list (for do-value) : shape_size_progress_color_`doSubmit` (ex. square_small_0_Red_doSubmit, square_small_0__doValue {`this means now state when back without clear`})
    - generated when click label and quit puzzle(for supporting undo/redo in continue) in **a**
    - deleted when clear puzzle in **SquareProvider().showComplete()**

### setting key (for app setting) : `setting`
- generated in **UserInfo.setSettingAll()** in mobile
- not deleted

## File Handling

Square_small.json : item's length should be 1410 (like test form) 