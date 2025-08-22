import { initializeTestEnvironment, assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { readFileSync } from "fs";
import { setDoc, doc, getFirestore } from "firebase/firestore";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-badminton",
    firestore: {
      rules: readFileSync("../rules/firestore.rules", "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

function authedCtx(claims: any) {
  return testEnv.authenticatedContext("user123", { roles: claims });
}

test("organizer can write fixtures", async () => {
  const ctx = authedCtx({ organizer: true });
  const db = ctx.firestore();
  await assertSucceeds(setDoc(doc(db, "tournaments/t1/fixtures/f1"), { court: 1, status: "scheduled" }));
});

test("referee cannot write fixtures", async () => {
  const ctx = authedCtx({ referee: true });
  const db = ctx.firestore();
  await assertFails(setDoc(doc(db, "tournaments/t1/fixtures/f1"), { court: 1, status: "scheduled" }));
});

test("referee can write matches", async () => {
  const ctx = authedCtx({ referee: true });
  const db = ctx.firestore();
  await assertSucceeds(setDoc(doc(db, "tournaments/t1/matches/m1"), { status: "live", court: 1 }));
});
