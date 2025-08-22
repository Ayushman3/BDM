import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import express from "express";
import cors from "cors";

admin.initializeApp();
const db = admin.firestore();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

/** ---------- Helpers (simplified) ---------- */
type Team = "A" | "B";
interface Rules {
  bestOf: number; pointsToWin: number; winBy: number; capAt: number;
  rallyScoring: boolean; discipline: "singles" | "doubles";
}

function setIsWon(a: number, b: number, r: Rules): boolean {
  if (a >= r.pointsToWin || b >= r.pointsToWin) {
    if (Math.abs(a - b) >= r.winBy) return true;
    if (a === r.capAt || b === r.capAt) return true;
  }
  return false;
}

function setWinner(a: number, b: number, r: Rules): Team | null {
  return setIsWon(a,b,r) ? (a > b ? "A" : "B") : null;
}

/** Compute next state from events (idempotent, deterministic). */
async function recomputeMatchFromEvents(mid: string, rules: Rules) {
  const mref = db.doc(`tournaments/${(await db.collectionGroup("matches").doc(mid).get()).ref.parent!.parent!.id}/matches/${mid}`);
  const snap = await mref.get();
  if (!snap.exists) return;
  const m = snap.data() as any;
  let scoreA = 0, scoreB = 0, currentSet = m.state?.currentSet ?? 1;
  const setScores: [number, number][] = Array.from({length: rules.bestOf}, () => [0,0]);

  for (const ev of (m.events || [])) {
    if (ev.type === "point") {
      if (ev.team === "A") scoreA++; else scoreB++;
      const w = setWinner(scoreA, scoreB, rules);
      if (w) {
        const idx = currentSet - 1;
        setScores[idx] = [scoreA, scoreB];
        scoreA = 0; scoreB = 0; currentSet += 1;
      }
    } else if (ev.type === "undo") {
      // No-op here; 'events' should already have last point removed before recompute
    }
  }

  await mref.update({
    "state.currentSet": currentSet,
    "state.scoreA": scoreA,
    "state.scoreB": scoreB,
    "state.setScores": setScores,
  });
}

/** Mirror minimal state for public viewers */
async function mirrorPublicLive(tid: string, court: number, payload: any) {
  await db.doc(`public/${tid}/live/${court}`).set(payload, { merge: true });
}

/** ---------- Endpoints ---------- */

// Generate fixtures (round-robin or knockout)
app.post("/api/tournaments/:tid/fixtures/generate", async (req, res) => {
  const { tid } = req.params;
  const { format = "round_robin" } = req.body || {};
  const tRef = db.doc(`tournaments/${tid}`);
  const t = (await tRef.get()).data();
  if (!t) return res.status(404).send("Tournament not found");

  const teamsSnap = await tRef.collection("teams").orderBy("seed", "asc").get();
  const teams = teamsSnap.docs.map(d => ({ id: d.id, ...d.data() }));

  if (teams.length < 2) return res.status(400).send("Need at least 2 teams");

  // Round-robin (circle) schedule
  const ids = teams.map(t => t.id);
  const isOdd = ids.length % 2 === 1;
  const list = [...ids, ...(isOdd ? ["BYE"] : [])];

  const rounds: [string, string][][] = [];
  for (let r = 0; r < list.length - 1; r++) {
    const matches: [string, string][] = [];
    for (let i = 0; i < list.length / 2; i++) {
      const a = list[i], b = list[list.length - 1 - i];
      if (a !== "BYE" && b !== "BYE") matches.push([a, b]);
    }
    rounds.push(matches);
    const fixed = list[0];
    const rest = list.slice(1);
    rest.unshift(rest.pop()!);
    list.splice(0, list.length, fixed, ...rest);
  }

  const batch = db.bulkWriter();
  let orderPerCourt: Record<number, number> = {};
  for (let c = 1; c <= t.courtsCount; c++) orderPerCourt[c] = 0;

  let court = 1;
  for (const round of rounds) {
    for (const [teamAId, teamBId] of round) {
      const fid = tRef.collection("fixtures").doc().id;
      orderPerCourt[court] += 1;
      batch.set(tRef.collection("fixtures").doc(fid), {
        court, teamAId, teamBId,
        status: "scheduled",
        orderOnCourt: orderPerCourt[court],
        slotTime: null,
        matchId: null,
      });
      court = court % t.courtsCount + 1;
    }
  }
  await batch.close();
  return res.json({ ok: true, rounds: rounds.length });
});

// Start match
app.post("/api/matches/:mid/start", async (req, res) => {
  const { mid } = req.params;
  const { tid, fixtureId, court, teamAId, teamBId, rules } = req.body;
  const mref = db.doc(`tournaments/${tid}/matches/${mid}`);
  await mref.set({
    fixtureId, court, teamAId, teamBId,
    status: "live",
    startedAt: Date.now(),
    state: {
      currentSet: 1,
      setScores: Array.from({length: rules.bestOf}, () => [0,0]),
      scoreA: 0, scoreB: 0,
      serving: null,
      positions: null,
    },
    events: [],
    winnerTeamId: null,
  }, { merge: true });

  await db.doc(`tournaments/${tid}/fixtures/${fixtureId}`).update({
    status: "live", matchId: mid
  });

  await mirrorPublicLive(tid, court, {
    matchId: mid, court, teamAId, teamBId,
    setScores: Array.from({length: rules.bestOf}, () => [0,0]),
    current: { scoreA: 0, scoreB: 0, set: 1 }
  });

  return res.json({ ok: true });
});

// Add point (idempotent via opId)
app.post("/api/matches/:mid/point", async (req, res) => {
  const { mid } = req.params;
  const { tid, team, opId, byPid, rules } = req.body as { tid: string, team: Team, opId: string, byPid?: string, rules: Rules };

  const mref = db.doc(`tournaments/${tid}/matches/${mid}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(mref);
    if (!snap.exists) throw new Error("Match not found");
    const m = snap.data() as any;
    if (m.events?.some((e: any) => e.opId === opId)) return; // idempotent

    const events = [...(m.events || []), { opId, ts: Date.now(), type: "point", team, byPid }];
    tx.update(mref, { events });

    // (lightweight state update; full recompute below)
    const scoreA = (m.state?.scoreA ?? 0) + (team === "A" ? 1 : 0);
    const scoreB = (m.state?.scoreB ?? 0) + (team === "B" ? 1 : 0);
    tx.update(mref, { "state.scoreA": scoreA, "state.scoreB": scoreB });
  });

  await recomputeMatchFromEvents(mid, rules);
  const msnap = await mref.get();
  const m = msnap.data() as any;
  await mirrorPublicLive(tid, m.court, {
    matchId: mid, court: m.court,
    teamAId: m.teamAId, teamBId: m.teamBId,
    setScores: m.state.setScores,
    current: { scoreA: m.state.scoreA, scoreB: m.state.scoreB, set: m.state.currentSet }
  });

  return res.json({ ok: true });
});

// Undo last point
app.post("/api/matches/:mid/undo", async (req, res) => {
  const { mid } = req.params;
  const { tid, rules } = req.body as { tid: string, rules: Rules };

  const mref = db.doc(`tournaments/${tid}/matches/${mid}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(mref);
    if (!snap.exists) throw new Error("Match not found");
    const m = snap.data() as any;
    const events = [...(m.events || [])];
    for (let i = events.length - 1; i >= 0; i--) {
      if (events[i].type === "point") { events.splice(i, 1); break; }
    }
    tx.update(mref, { events });
  });

  await recomputeMatchFromEvents(mid, rules);
  const msnap = await mref.get();
  const m = msnap.data() as any;
  await mirrorPublicLive(tid, m.court, {
    matchId: mid, court: m.court,
    teamAId: m.teamAId, teamBId: m.teamBId,
    setScores: m.state.setScores,
    current: { scoreA: m.state.scoreA, scoreB: m.state.scoreB, set: m.state.currentSet }
  });

  return res.json({ ok: true });
});

// End match
app.post("/api/matches/:mid/end", async (req, res) => {
  const { mid } = req.params;
  const { tid, fixtureId } = req.body;

  const mref = db.doc(`tournaments/${tid}/matches/${mid}`);
  const fsnap = await db.doc(`tournaments/${tid}/fixtures/${fixtureId}`).get();
  const matchSnap = await mref.get();
  const m = matchSnap.data() as any;

  // compute winner by setScores
  const sets = (m.state?.setScores || []) as [number, number][];
  let a = 0, b = 0;
  for (const [sa, sb] of sets) { if (sa > sb) a++; else if (sb > sa) b++; }
  const winnerTeamId = a > b ? m.teamAId : m.teamBId;

  await mref.update({ status: "done", endedAt: Date.now(), winnerTeamId });
  await db.doc(`tournaments/${tid}/fixtures/${fixtureId}`).update({ status: "done" });

  // unlock next fixture on same court (lowest orderOnCourt with status=scheduled)
  const next = await db.collection(`tournaments/${tid}/fixtures`)
    .where("court", "==", m.court).where("status", "==", "scheduled")
    .orderBy("orderOnCourt", "asc").limit(1).get();
  if (!next.empty) {
    // front-end shows Start button by visibility logic (no write needed)
  }

  return res.json({ ok: true, winnerTeamId });
});

exports.api = functions.region("asia-south1").https.onRequest(app);
