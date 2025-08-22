// rotation_helper.dart
import 'package:badminton_app/court/court_geometry.dart';

/// Teams in code: 'A' and 'B'
enum Team { A, B }
extension TeamX on Team {
  String get key => this == Team.A ? 'A' : 'B';
  Team get other => this == Team.A ? Team.B : Team.A;
}

/// Discipline
enum Discipline { singles, doubles }

/// Minimal rules needed for rotation (expand if you add variants)
class RotationRules {
  final Discipline discipline;
  const RotationRules({this.discipline = Discipline.doubles});
}

/// Who is serving (team + which player key on court)
/// servingKey must be one of: 'A_FRONT' | 'A_BACK' | 'B_FRONT' | 'B_BACK'
class ServingState {
  final Team team;
  final String servingKey;
  const ServingState(this.team, this.servingKey);

  ServingState copyWith({Team? team, String? servingKey}) =>
      ServingState(team ?? this.team, servingKey ?? this.servingKey);
}

/// Four player IDs (or labels) mapped to the four anchor roles
/// Keep these in sync with your UI labels
class PlayersOnCourt {
  final String aFront, aBack, bFront, bBack;
  const PlayersOnCourt({
    required this.aFront,
    required this.aBack,
    required this.bFront,
    required this.bBack,
  });

  PlayersOnCourt swapTeamAFrontBack() =>
      PlayersOnCourt(aFront: aBack, aBack: aFront, bFront: bFront, bBack: bBack);

  PlayersOnCourt swapTeamBFrontBack() =>
      PlayersOnCourt(aFront: aFront, aBack: aBack, bFront: bBack, bBack: bFront);

  PlayersOnCourt swappedSides() => PlayersOnCourt(
        aFront: bFront,
        aBack: bBack,
        bFront: aFront,
        bBack: aBack,
      );
}

/// UI positions (percent anchors) for the four player dots.
/// You already have this type from court_geometry.dart, reusing here.
class CourtPose {
  final CourtPositions anchors; // where each role sits on the court
  final String servingKey;       // 'A_FRONT' | 'A_BACK' | 'B_FRONT' | 'B_BACK'
  const CourtPose({required this.anchors, required this.servingKey});

  CourtPose copyWith({CourtPositions? anchors, String? servingKey}) =>
      CourtPose(anchors: anchors ?? this.anchors, servingKey: servingKey ?? this.servingKey);
}

/// Full rotation state passed around your live-scoring store.
class RotationState {
  final RotationRules rules;
  final ServingState serving;
  final PlayersOnCourt players;  // mapping of names/ids to roles
  final CourtPose pose;          // where dots are drawn

  const RotationState({
    required this.rules,
    required this.serving,
    required this.players,
    required this.pose,
  });

  RotationState copyWith({
    RotationRules? rules,
    ServingState? serving,
    PlayersOnCourt? players,
    CourtPose? pose,
  }) =>
      RotationState(
        rules: rules ?? this.rules,
        serving: serving ?? this.serving,
        players: players ?? this.players,
        pose: pose ?? this.pose,
      );
}

/// Helpers to build initial state (right service court by default = even parity)
RotationState initialDoublesRotation({
  required String aFrontName,
  required String aBackName,
  required String bFrontName,
  required String bBackName,
  Team initialServingTeam = Team.A,
  String initialServingKey = 'A_FRONT', // choose which of your pair serves first
}) {
  final anchors = CourtPositions.initialDoubles();
  return RotationState(
    rules: const RotationRules(discipline: Discipline.doubles),
    serving: ServingState(initialServingTeam, initialServingKey),
    players: PlayersOnCourt(
      aFront: aFrontName,
      aBack: aBackName,
      bFront: bFrontName,
      bBack: bBackName,
    ),
    pose: CourtPose(anchors: anchors, servingKey: initialServingKey),
  );
}

RotationState initialSinglesRotation({
  required String aName,
  required String bName,
  Team initialServingTeam = Team.A,
  bool serverOnRight = true, // even parity starts right
}) {
  // In singles we still reuse the same anchors:
  var anchors = CourtPositions.initialDoubles();
  // Place A according to parity
  anchors = serverOnRight ? anchors.setTeamAParity(even: true)
                          : anchors.setTeamAParity(even: false);
  // B mirrors accordingly; actual side chosen by who serves first
  return RotationState(
    rules: const RotationRules(discipline: Discipline.singles),
    serving: ServingState(
      initialServingTeam,
      initialServingTeam == Team.A ? (serverOnRight ? 'A_FRONT' : 'A_BACK')
                                   : (serverOnRight ? 'B_FRONT' : 'B_BACK'),
    ),
    players: PlayersOnCourt(
      aFront: aName, aBack: aName, // same label on both anchors in singles
      bFront: bName, bBack: bName,
    ),
    pose: CourtPose(anchors: anchors,
        servingKey: initialServingTeam == Team.A
            ? (serverOnRight ? 'A_FRONT' : 'A_BACK')
            : (serverOnRight ? 'B_FRONT' : 'B_BACK')),
  );
}

/// Apply rotation after a rally ends.
/// Inputs:
/// - winner: Team.A or Team.B
/// - scoreA / scoreB: *new* current rally score AFTER increment (used for parity)
/// Returns updated RotationState with:
/// - serving team/key adjusted
/// - anchors adjusted for parity or swaps (UI will animate)
RotationState applyRally({
  required RotationState s,
  required Team winner,
  required int scoreA,
  required int scoreB,
}) {
  if (s.rules.discipline == Discipline.singles) {
    return _applySinglesRally(s: s, winner: winner, scoreA: scoreA, scoreB: scoreB);
  } else {
    return _applyDoublesRally(s: s, winner: winner, scoreA: scoreA, scoreB: scoreB);
  }
}

RotationState _applySinglesRally({
  required RotationState s,
  required Team winner,
  required int scoreA,
  required int scoreB,
}) {
  var pose = s.pose;
  var serving = s.serving;

  final servingTeamWon = serving.team == winner;
  if (servingTeamWon) {
    // Same server continues; parity changes with server's team score
    final even = (winner == Team.A ? scoreA : scoreB) % 2 == 0;
    if (winner == Team.A) {
      pose = pose.copyWith(anchors: pose.anchors.setTeamAParity(even: even));
      serving = serving.copyWith(servingKey: even ? 'A_FRONT' : 'A_BACK');
    } else {
      pose = pose.copyWith(anchors: pose.anchors.setTeamBParity(even: even));
      serving = serving.copyWith(servingKey: even ? 'B_FRONT' : 'B_BACK');
    }
  } else {
    // Service changes to winner; server stands on right when own score even
    final even = (winner == Team.A ? scoreA : scoreB) % 2 == 0;
    if (winner == Team.A) {
      pose = pose.copyWith(anchors: pose.anchors.setTeamAParity(even: even));
      serving = ServingState(Team.A, even ? 'A_FRONT' : 'A_BACK');
    } else {
      pose = pose.copyWith(anchors: pose.anchors.setTeamBParity(even: even));
      serving = ServingState(Team.B, even ? 'B_FRONT' : 'B_BACK');
    }
  }

  return s.copyWith(pose: pose, serving: serving);
}

RotationState _applyDoublesRally({
  required RotationState s,
  required Team winner,
  required int scoreA,
  required int scoreB,
}) {
  var pose = s.pose;
  var serving = s.serving;

  final servingTeamWon = serving.team == winner;

  if (servingTeamWon) {
    // Same team serves again; server alternates right/left => swap that team's front/back
    if (winner == Team.A) {
      pose = pose.copyWith(
        anchors: pose.anchors.swapTeamAFrontBack(),
      );
      serving = serving.copyWith(
        servingKey: serving.servingKey == 'A_FRONT' ? 'A_BACK' : 'A_FRONT',
      );
    } else {
      pose = pose.copyWith(
        anchors: pose.anchors.swapTeamBFrontBack(),
      );
      serving = serving.copyWith(
        servingKey: serving.servingKey == 'B_FRONT' ? 'B_BACK' : 'B_FRONT',
      );
    }
  } else {
    // Service passes to receiving team; choose server by parity of the new winner's score
    final even = (winner == Team.A ? scoreA : scoreB) % 2 == 0;
    if (winner == Team.A) {
      pose = pose.copyWith(anchors: pose.anchors.setTeamAParity(even: even));
      serving = ServingState(Team.A, even ? 'A_FRONT' : 'A_BACK');
    } else {
      pose = pose.copyWith(anchors: pose.anchors.setTeamBParity(even: even));
      serving = ServingState(Team.B, even ? 'B_FRONT' : 'B_BACK');
    }
  }

  return s.copyWith(pose: pose, serving: serving);
}

/// Call when a set ends to cross the court (side switch) and pick first server of next set.
/// Common rule: previous set winner serves first (adjust if your event uses a different rule).
RotationState onSetChange({
  required RotationState s,
  required Team previousSetWinner,
}) {
  var pose = s.pose.copyWith(anchors: s.pose.anchors.swappedSides());
  // Initial parity for next set: start on "right" (even) by default
  if (previousSetWinner == Team.A) {
    pose = pose.copyWith(anchors: pose.anchors.setTeamAParity(even: true));
    return s.copyWith(
      pose: pose,
      serving: ServingState(Team.A, 'A_FRONT'),
    );
  } else {
    pose = pose.copyWith(anchors: pose.anchors.setTeamBParity(even: true));
    return s.copyWith(
      pose: pose,
      serving: ServingState(Team.B, 'B_FRONT'),
    );
  }
}

