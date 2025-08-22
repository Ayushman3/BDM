import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/matches_repo.dart';
import '../../domain/match_state.dart';
import '../../domain/rules.dart';

class LiveState {
  final MatchStateModel? match;
  final bool syncing;
  LiveState({this.match, this.syncing=false});
  LiveState copyWith({MatchStateModel? match, bool? syncing}) =>
      LiveState(match: match ?? this.match, syncing: syncing ?? this.syncing);
}

class LiveController extends StateNotifier<LiveState> {
  final MatchesRepo repo;
  final String tid, mid;
  final Rules rules;
  LiveController({required this.repo, required this.tid, required this.mid, required this.rules})
      : super(LiveState()) {
    repo.watchMatch(tid, mid).listen((m) => state = state.copyWith(match: m, syncing: false));
  }

  Future<void> pointA() async { state = state.copyWith(syncing: true); await repo.addPoint(tid: tid, mid: mid, team: 'A', rules: rules); }
  Future<void> pointB() async { state = state.copyWith(syncing: true); await repo.addPoint(tid: tid, mid: mid, team: 'B', rules: rules); }
  Future<void> undo()   async { state = state.copyWith(syncing: true); await repo.undo(tid: tid, mid: mid, rules: rules); }
}

final liveControllerProvider = StateNotifierProvider.family<LiveController, LiveState, ({MatchesRepo repo, String tid, String mid, Rules rules})>((ref, args) {
  return LiveController(repo: args.repo, tid: args.tid, mid: args.mid, rules: args.rules);
});
