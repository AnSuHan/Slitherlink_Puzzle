import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slitherlink_project/widgets/TriangleBox.dart';

/// Hit-testing geometry for the triangle cell. Verifies:
///   • pickClosestEdge returns the right edge index for taps near each side
///   • pointInTriangle drops taps that fall in the bounding-box corners
///     (the property that makes deferToChild work for overlapping cells)
void main() {
  const double w = 50.0;
  const double h = 50.0 * 0.866;

  group('TriangleBoxState.pickClosestEdge — Up', () {
    test('tap on base midpoint → e0', () {
      // Up: base goes p1(0,h)-p2(w,h); midpoint is (w/2, h).
      expect(TriangleBoxState.pickClosestEdge(true, Offset(w / 2, h), w, h), 0);
    });

    test('tap on left-diagonal midpoint → e1', () {
      // Up: left diag goes apex(w/2, 0) → p1(0, h); midpoint (w/4, h/2).
      expect(
          TriangleBoxState.pickClosestEdge(true, Offset(w / 4, h / 2), w, h), 1);
    });

    test('tap on right-diagonal midpoint → e2', () {
      // Up: right diag goes apex(w/2, 0) → p2(w, h); midpoint (3w/4, h/2).
      expect(
          TriangleBoxState.pickClosestEdge(true, Offset(3 * w / 4, h / 2), w, h),
          2);
    });
  });

  group('TriangleBoxState.pickClosestEdge — Down', () {
    test('tap on top midpoint → e0', () {
      // Down: top goes p0(0, 0) - p1(w, 0); midpoint (w/2, 0).
      expect(TriangleBoxState.pickClosestEdge(false, Offset(w / 2, 0), w, h), 0);
    });

    test('tap on left-diagonal midpoint → e1', () {
      // Down: left diag goes p0(0, 0) → apex(w/2, h); midpoint (w/4, h/2).
      expect(
          TriangleBoxState.pickClosestEdge(false, Offset(w / 4, h / 2), w, h),
          1);
    });

    test('tap on right-diagonal midpoint → e2', () {
      // Down: right diag goes p1(w, 0) → apex(w/2, h); midpoint (3w/4, h/2).
      expect(
          TriangleBoxState.pickClosestEdge(false, Offset(3 * w / 4, h / 2), w, h),
          2);
    });
  });

  group('TriangleBoxState.pointInTriangle — overlap pass-through', () {
    test('Up: center is inside', () {
      // Centroid of Up triangle is at (w/2, 2h/3).
      expect(TriangleBoxState.pointInTriangle(true, Offset(w / 2, 2 * h / 3), w, h),
          isTrue);
    });

    test('Up: top-left corner of bounding box is outside', () {
      // (0, 0) is the apex of Down's left side, not inside an Up.
      expect(TriangleBoxState.pointInTriangle(true, const Offset(1, 1), w, h),
          isFalse);
    });

    test('Up: top-right corner of bounding box is outside', () {
      expect(TriangleBoxState.pointInTriangle(true, Offset(w - 1, 1), w, h),
          isFalse);
    });

    test('Down: center is inside', () {
      expect(TriangleBoxState.pointInTriangle(false, Offset(w / 2, h / 3), w, h),
          isTrue);
    });

    test('Down: bottom-left corner of bounding box is outside', () {
      expect(TriangleBoxState.pointInTriangle(false, Offset(1, h - 1), w, h),
          isFalse);
    });

    test('Down: bottom-right corner of bounding box is outside', () {
      expect(TriangleBoxState.pointInTriangle(false, Offset(w - 1, h - 1), w, h),
          isFalse);
    });
  });
}
