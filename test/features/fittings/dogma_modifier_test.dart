import 'package:flutter_test/flutter_test.dart';
import 'package:neocompanion/features/fittings/domain/dogma_modifier.dart';

void main() {
  group('resolveAttribute', () {
    test('returns base when no modifiers', () {
      expect(resolveAttribute(100, const []), 100);
    });

    test('postPercent stackable bonuses multiply directly', () {
      final v = resolveAttribute(100, const [
        Modifier(
          op: ModifierOp.postPercent,
          value: 5,
          source: 'cpu_management',
          stackable: true,
        ),
        Modifier(
          op: ModifierOp.postPercent,
          value: 5,
          source: 'cpu_implant',
          stackable: true,
        ),
      ]);
      // (1 + 0.05) * (1 + 0.05) = 1.1025
      expect(v, closeTo(110.25, 1e-9));
    });

    test('two non-stackable +25% are penalised on the second', () {
      final v = resolveAttribute(100, const [
        Modifier(
          op: ModifierOp.postPercent,
          value: 25,
          source: 'eanm-1',
        ),
        Modifier(
          op: ModifierOp.postPercent,
          value: 25,
          source: 'eanm-2',
        ),
      ]);
      // First module at full strength (×1.25), second at exp(-(1/2.67)^2)
      // ≈ 0.8691 → effective +21.73% → ×1.2173
      // 100 * 1.25 * (1 + 0.25 * 0.8691) ≈ 100 * 1.25 * 1.21727
      expect(v, closeTo(152.16, 0.5));
    });

    test('preAssignment overrides base', () {
      final v = resolveAttribute(100, const [
        Modifier(
          op: ModifierOp.preAssignment,
          value: 42,
          source: 'override',
        ),
        Modifier(
          op: ModifierOp.modAdd,
          value: 10,
          source: 'plus10',
        ),
      ]);
      expect(v, 52);
    });

    test('modAdd is applied after pre-mul', () {
      final v = resolveAttribute(10, const [
        Modifier(
          op: ModifierOp.preMul,
          value: 2,
          source: 'double',
          stackable: true,
        ),
        Modifier(
          op: ModifierOp.modAdd,
          value: 5,
          source: 'plus5',
        ),
      ]);
      expect(v, 25);
    });

    test('non-stackable modifiers are sorted by magnitude before penalty',
        () {
      final small = const Modifier(
        op: ModifierOp.postPercent,
        value: 5,
        source: 'small',
      );
      final big = const Modifier(
        op: ModifierOp.postPercent,
        value: 25,
        source: 'big',
      );
      final asc = resolveAttribute(100, [small, big]);
      final desc = resolveAttribute(100, [big, small]);
      // Order in the list shouldn't change the result — penalty is
      // applied to the *smaller* effect either way.
      expect(asc, closeTo(desc, 1e-9));
    });
  });
}
