// ignore_for_file: file_names
import 'HexagonProvider.dart';
import 'SquareProvider.dart';
import 'TriangleProvider.dart';
import 'TrihexProvider.dart';

/// 4 가지 도형 (Square / Triangle / Hexagon / Trihex) 의 solveHumanLike 를
/// 감싸는 박싱(boxing) 디스패처. 각 도형의 본체는 자기 Provider 안에 그대로
/// 두고, AppBar 자동 풀이 버튼은 항상 이 함수만 호출한다. Scene 은 자기
/// Provider 를 그대로 넘기면 되고, 어느 메소드를 부를지 신경 쓰지 않는다.
///
/// [stepDelay] 한 수와 다음 수 사이의 대기. 기본 0 (지연 없음). 사람이
/// 따라 볼 수 있게 늦추고 싶다면 호출 측에서 Duration 을 넘긴다.
Future<void> runAutoSolve(Object provider,
    {Duration stepDelay = Duration.zero}) async {
  if (provider is SquareProvider) {
    await provider.solveHumanLike(stepDelay: stepDelay);
  } else if (provider is TriangleProvider) {
    await provider.solveHumanLike(stepDelay: stepDelay);
  } else if (provider is HexagonProvider) {
    await provider.solveHumanLike(stepDelay: stepDelay);
  } else if (provider is TrihexProvider) {
    await provider.solveHumanLike(stepDelay: stepDelay);
  }
}
