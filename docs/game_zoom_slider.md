# 게임 화면 줌 슬라이더

`lib/Scene/GameSceneSquare.dart` — 한 손 조작용 수직 슬라이더로 InteractiveViewer 의 스케일을 조절.

## 상태
- `double _zoomSlider = 1.0;`
- `bool _suppressZoomSync = false;` — 슬라이더 → 컨트롤러 적용 중 리스너 재호출 방지.

## 메서드
- `_syncZoomFromController()` — `TransformationController` 가 변할 때 슬라이더 값을 추종.
- `_applyZoom(double newScale)` — 슬라이더 변경 시 컨트롤러의 변환 행렬을 새 스케일로 갱신.

## 범위
- min `0.3`, max `2.0` (InteractiveViewer 의 maxScale 도 동일).
- 초기값 `1.0`.

## UI
- `Positioned` + `RotatedBox(quarterTurns: 3)` 로 화면 우측에 세로 슬라이더 배치.

## 리스너 등록
`initState` 에서 `_transformationController.addListener(_syncZoomFromController);`
`dispose` 에서 해제.
