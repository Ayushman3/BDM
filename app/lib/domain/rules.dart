class Rules {
  final int bestOf, pointsToWin, winBy, capAt;
  final bool rallyScoring;
  final String discipline; // 'doubles'|'singles'
  const Rules({
    this.bestOf = 3,
    this.pointsToWin = 21,
    this.winBy = 2,
    this.capAt = 30,
    this.rallyScoring = true,
    this.discipline = 'doubles',
  });
}
