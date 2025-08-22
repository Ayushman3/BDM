import 'dart:ui';

/// Percent-based anchors for player positions on the court.
class CourtPositions {
  final Offset aFront;
  final Offset aBack;
  final Offset bFront;
  final Offset bBack;

  const CourtPositions({
    required this.aFront,
    required this.aBack,
    required this.bFront,
    required this.bBack,
  });

  CourtPositions copyWith({
    Offset? aFront,
    Offset? aBack,
    Offset? bFront,
    Offset? bBack,
  }) => CourtPositions(
        aFront: aFront ?? this.aFront,
        aBack: aBack ?? this.aBack,
        bFront: bFront ?? this.bFront,
        bBack: bBack ?? this.bBack,
      );

  /// Starting anchors for doubles with Team A on the left and Team B on the right.
  static CourtPositions initialDoubles() => const CourtPositions(
        aFront: Offset(0.25, 0.3),
        aBack: Offset(0.25, 0.7),
        bFront: Offset(0.75, 0.3),
        bBack: Offset(0.75, 0.7),
      );

  /// Swap front/back players for Team A.
  CourtPositions swapTeamAFrontBack() => copyWith(aFront: aBack, aBack: aFront);

  /// Swap front/back players for Team B.
  CourtPositions swapTeamBFrontBack() => copyWith(bFront: bBack, bBack: bFront);

  /// Position Team A according to score parity (even => server on right).
  CourtPositions setTeamAParity({required bool even}) => even
      ? copyWith(aFront: const Offset(0.25, 0.3), aBack: const Offset(0.25, 0.7))
      : copyWith(aFront: const Offset(0.25, 0.7), aBack: const Offset(0.25, 0.3));

  /// Position Team B according to score parity (even => server on right).
  CourtPositions setTeamBParity({required bool even}) => even
      ? copyWith(bFront: const Offset(0.75, 0.3), bBack: const Offset(0.75, 0.7))
      : copyWith(bFront: const Offset(0.75, 0.7), bBack: const Offset(0.75, 0.3));

  /// Swap sides of the court between teams.
  CourtPositions swappedSides() => CourtPositions(
        aFront: bFront,
        aBack: bBack,
        bFront: aFront,
        bBack: aBack,
      );
}

