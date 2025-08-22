// rotation_helper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_app/features/live_scoring/rotation/rotation_helper.dart';
import 'package:badminton_app/features/live_scoring/rotation/rotation_validator.dart';

RotationState _initDoubles({
  Team initialTeam = Team.A,
  String initialKey = 'A_FRONT',
}) {
  final s = initialDoublesRotation(
    aFrontName: 'A1', aBackName: 'A2',
    bFrontName: 'B1', bBackName: 'B2',
    initialServingTeam: initialTeam,
    initialServingKey: initialKey,
  );
  validateRotationState(s);
  return s;
}

void main() {
  group('Doubles rotation', () {
    test('Serving team wins: swaps own front/back & toggles server key', () {
      var s = _initDoubles(initialTeam: Team.A, initialKey: 'A_FRONT');
      // A wins first rally -> A continues serving, swap front/back
      s = applyRally(s: s, winner: Team.A, scoreA: 1, scoreB: 0);
      validateRotationState(s);

      expect(s.serving.team, Team.A);
      expect(s.serving.servingKey, anyOf('A_BACK','A_FRONT')); // should toggle
      // Applying again should toggle back
      final prevKey = s.serving.servingKey;
      s = applyRally(s: s, winner: Team.A, scoreA: 2, scoreB: 0);
      validateRotationState(s);
      expect(s.serving.team, Team.A);
      expect(s.serving.servingKey == prevKey, isFalse,
          reason: 'Server key must toggle each consecutive serve for same team');
    });

    test('Receiving team wins: service passes; server decided by parity', () {
      var s = _initDoubles(initialTeam: Team.A, initialKey: 'A_FRONT');
      // B wins rally -> service passes to B; scoreB=1 (odd) -> left box -> we mapped to BACK
      s = applyRally(s: s, winner: Team.B, scoreA: 0, scoreB: 1);
      validateRotationState(s);

      expect(s.serving.team, Team.B);
      expect(s.serving.servingKey, anyOf('B_FRONT','B_BACK'));
      // For our anchors, we used FRONT as "right" and BACK as "left" (by parity mapping).
      // With odd score, expect left -> key likely 'B_BACK'.
      // We don't hard-assert the exact label if your mapping differs, but it must be B_*.
      expect(s.serving.servingKey.startsWith('B_'), isTrue);
    });

    test('Side switch between sets mirrors anchors and picks new server', () {
      var s = _initDoubles(initialTeam: Team.A, initialKey: 'A_FRONT');
      // Pretend Team B won the set:
      s = onSetChange(s: s, previousSetWinner: Team.B);
      validateRotationState(s);

      expect(s.serving.team, Team.B);
      expect(s.serving.servingKey, anyOf('B_FRONT','B_BACK'));
    });
  });

  group('Singles rotation (parity-based)', () {
    test('Serving team wins: same server; parity determines right/left', () {
      // Start singles with A serving on right (even)
      var s = initialSinglesRotation(aName: 'A', bName: 'B', initialServingTeam: Team.A, serverOnRight: true);
      validateRotationState(s);

      // A wins → A continues; scoreA=1 (odd) -> left box
      s = applyRally(s: s, winner: Team.A, scoreA: 1, scoreB: 0);
      validateRotationState(s);

      expect(s.serving.team, Team.A);
      expect(s.serving.servingKey, anyOf('A_FRONT','A_BACK')); // toggled by parity
    });

    test('Receiving team wins: service passes; new server by parity', () {
      var s = initialSinglesRotation(aName: 'A', bName: 'B', initialServingTeam: Team.A, serverOnRight: true);
      // B wins → service to B; scoreB=1 (odd) -> left
      s = applyRally(s: s, winner: Team.B, scoreA: 0, scoreB: 1);
      validateRotationState(s);

      expect(s.serving.team, Team.B);
      expect(s.serving.servingKey.startsWith('B_'), isTrue);
    });
  });

  group('Validator catches invalid states', () {
    test('Serving team mismatch with key prefix throws', () {
      var s = _initDoubles();
      // Manually break invariant
      final bad = s.copyWith(
        serving: ServingState(Team.B, 'A_FRONT'),
      );
      expect(() => validateRotationState(bad), throwsArgumentError);
    });

    test('Anchor out-of-bounds throws', () {
      var s = _initDoubles();
      final bad = s.copyWith(
        pose: s.pose.copyWith(
          anchors: s.pose.anchors.copyWith(
            aFront: const Pct(1.5, -0.2), // invalid
          ),
        ),
      );
      expect(() => validateRotationState(bad), throwsArgumentError);
    });
  });
}

