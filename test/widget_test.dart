// 기본 스모크 테스트.
//
// 원래 Flutter 템플릿의 "Counter increments" 테스트는 이 앱(카운터 아님, 슬리더링크)과
// 맞지 않아 항상 실패했다. 앱 고유의 순수 데이터(ThemeColor)를 검증하는 테스트로 대체한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:slitherlink_project/ThemeColor.dart';

void main() {
  test('ThemeColor 는 15개 선 색상과 특수 선 상태 색을 제공한다', () {
    final theme = ThemeColor();

    // 사용자 선 색상 line_01 ~ line_15
    for (var i = 1; i <= 15; i++) {
      final key = 'line_${i.toString().padLeft(2, '0')}';
      expect(theme.lineColor.containsKey(key), isTrue, reason: '$key 누락');
    }

    // 특수 선 상태 색
    for (final key in ['line_wrong', 'line_hint', 'line_disable', 'line_normal', 'line_x']) {
      expect(theme.lineColor.containsKey(key), isTrue, reason: '$key 누락');
    }
  });
}
