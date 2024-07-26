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

loading puzzle key (init and restart) : shape_size_progress (ex. square_small_0)
loading submit key (continue) : shape_size_progress_continue (ex. square_small_0_continue)

game label key (save and load) : shape_size_progress_color (ex. square_small_0_Red, square_small_0_Green, square_small_0_Blue)

setting key (for app setting) : setting

SquareProvider 클래스 extractData() 내부는 웹과 비웹 플랫폼에 따라 필수로 주석 처리가 필요하다
    ㆍ web인 경우   - else 내부 주석 처리
    ㆍ 비 web인 경우 - if(kIsWeb) 내부 주석 처리 + import '../Platform/ExtractDataWeb.dart'; 부분 주석 처리 