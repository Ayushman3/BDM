import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/match_state.dart';
import '../domain/rules.dart';

class MatchesRepo {
  final FirebaseFirestore _fs;
  final String functionsBase; // e.g. https://asia-south1-<proj>.cloudfunctions.net/api
  MatchesRepo(this._fs, this.functionsBase);

  Stream<MatchStateModel> watchMatch(String tid, String mid) {
    final doc = _fs.doc('tournaments/$tid/matches/$mid');
    return doc.snapshots().map((s) {
      final d = s.data()!;
      return MatchStateModel(
        matchId: s.id,
        teamAId: d['teamAId'],
        teamBId: d['teamBId'],
        court: d['court'],
        currentSet: d['state']['currentSet'],
        setScores: (d['state']['setScores'] as List).map<List<int>>((e) => [e[0], e[1]]).toList(),
        scoreA: d['state']['scoreA'],
        scoreB: d['state']['scoreB'],
      );
    });
  }

  Future<void> addPoint({required String tid, required String mid, required String team, required Rules rules, String? byPid}) async {
    final opId = DateTime.now().microsecondsSinceEpoch.toString();
    final url = Uri.parse('$functionsBase/api/matches/$mid/point');
    await http.post(url, headers: {'Content-Type':'application/json'}, body: jsonEncode({
      'tid': tid, 'team': team, 'opId': opId, 'byPid': byPid,
      'rules': {
        'bestOf': rules.bestOf, 'pointsToWin': rules.pointsToWin,
        'winBy': rules.winBy, 'capAt': rules.capAt,
        'rallyScoring': rules.rallyScoring, 'discipline': rules.discipline,
      }
    }));
  }

  Future<void> undo({required String tid, required String mid, required Rules rules}) async {
    final url = Uri.parse('$functionsBase/api/matches/$mid/undo');
    await http.post(url, headers: {'Content-Type':'application/json'}, body: jsonEncode({
      'tid': tid,
      'rules': {
        'bestOf': rules.bestOf, 'pointsToWin': rules.pointsToWin,
        'winBy': rules.winBy, 'capAt': rules.capAt,
        'rallyScoring': rules.rallyScoring, 'discipline': rules.discipline,
      }
    }));
  }

  Future<void> endMatch({required String tid, required String mid, required String fixtureId}) async {
    final url = Uri.parse('$functionsBase/api/matches/$mid/end');
    await http.post(url, headers: {'Content-Type':'application/json'}, body: jsonEncode({
      'tid': tid, 'fixtureId': fixtureId
    }));
  }
}
