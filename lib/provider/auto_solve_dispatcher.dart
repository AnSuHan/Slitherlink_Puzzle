// ignore_for_file: file_names
import 'SquareProvider.dart';
import 'TriangleProvider.dart';

/// 사각형 / 삼각형 솔버를 감싸는 박싱(boxing) 디스패처. 각 도형의
/// `solveHumanLike()` 본체는 자기 Provider 안에 그대로 두고, AppBar
/// 자동 풀이 버튼은 항상 이 함수만 호출한다. Scene 은 자기 Provider 를
/// 그대로 넘기면 되고, 어느 메소드를 부를지 신경 쓰지 않는다.
Future<void> runAutoSolve(Object provider) async {
  if (provider is SquareProvider) {
    await provider.solveHumanLike();
  } else if (provider is TriangleProvider) {
    await provider.solveHumanLike();
  }
}
