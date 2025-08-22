import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/rules.dart';
import '../../data/matches_repo.dart';
import 'live_controller.dart';

class LiveScreen extends ConsumerWidget {
  final String tid, mid;
  final Rules rules;
  final MatchesRepo repo;
  const LiveScreen({super.key, required this.tid, required this.mid, required this.rules, required this.repo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveControllerProvider((repo: repo, tid: tid, mid: mid, rules: rules)));
    final ctrl = ref.read(liveControllerProvider((repo: repo, tid: tid, mid: mid, rules: rules)).notifier);

    final m = state.match;
    if (m == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Court ${m.court} – ${m.matchId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Set ${m.currentSet}/${rules.bestOf}', style: const TextStyle(fontSize: 16)),
                        if (state.syncing) const Icon(Icons.cloud_upload),
                      ],
                    ),
                  ),
                  // Court canvas placeholder (replace with CustomPaint + AnimatedPositioned)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(width: 2),
                      ),
                      child: Stack(
                        children: const [
                          // TODO: draw court lines, 4 player dots, animated serve dot
                          // Use AnimatedPositioned / TweenAnimationBuilder for swaps
                        ],
                      ),
                    ),
                  ),
                  // Scores + Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _teamPanel(context, "Team A", m.scoreA, m.setScores, rules.bestOf),
                        Row(
                          children: [
                            ElevatedButton(onPressed: () => ctrl.pointA(), child: const Text('+1 Team A')),
                            const SizedBox(width: 12),
                            ElevatedButton(onPressed: () => ctrl.undo(), child: const Text('Undo')),
                            const SizedBox(width: 12),
                            ElevatedButton(onPressed: () => ctrl.pointB(), child: const Text('+1 Team B')),
                          ],
                        ),
                        _teamPanel(context, "Team B", m.scoreB, m.setScores, rules.bestOf),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPanel(BuildContext ctx, String name, int score, List<List<int>> setScores, int bestOf) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text('$score', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
        Row(
          children: List.generate(bestOf, (i) {
            final s = setScores[i];
            final won = s[0] != 0 || s[1] != 0 ? (s[0] > s[1]) : false;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(won ? Icons.circle : Icons.circle_outlined, size: 12),
            );
          }),
        ),
      ],
    );
  }
}
