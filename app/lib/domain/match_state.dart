class MatchStateModel {
  final String matchId, teamAId, teamBId;
  final int court;
  final int currentSet;
  final List<List<int>> setScores; // [[a,b], ...]
  final int scoreA, scoreB;
  MatchStateModel({
    required this.matchId,
    required this.teamAId,
    required this.teamBId,
    required this.court,
    required this.currentSet,
    required this.setScores,
    required this.scoreA,
    required this.scoreB,
  });

  MatchStateModel copyWith({
    int? currentSet, List<List<int>>? setScores, int? scoreA, int? scoreB,
  }) => MatchStateModel(
    matchId: matchId, teamAId: teamAId, teamBId: teamBId, court: court,
    currentSet: currentSet ?? this.currentSet,
    setScores: setScores ?? this.setScores,
    scoreA: scoreA ?? this.scoreA,
    scoreB: scoreB ?? this.scoreB,
  );
}
