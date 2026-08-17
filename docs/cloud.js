// Optional cloud sync for the Droid Tycoon Rebirth Tracker.
//
// Wires up Firebase (Auth + Firestore) so progress can follow you across devices with live
// updates, and so the game-data tables (cycles/costs/rarities) can be edited by an admin and
// pushed live to every device with no code change or redeploy.
//
// SETUP: see FIREBASE_SETUP.md at the repo root. Paste your project's public web config into
// `firebaseConfig` below. Until you do, FIREBASE_ENABLED stays false and this file makes NO
// network calls at all - the app behaves exactly as it does today (localStorage-only, fully
// offline, no accounts).
//
// This is a <script type="module">, loaded from index.html's <head>. A module can't share
// closures with the classic (non-module) app script, so the two talk over `window`:
//   this file DISPATCHES on window:
//     "cloud:ready"    detail: true                          - Firebase initialized OK
//     "cloud:auth"     detail: {uid,email,displayName,photoURL} | null
//     "cloud:admin"    detail: boolean                        - is the signed-in user an admin
//     "cloud:gamedata" detail: <config/gamedata doc data>      - fires on every change, incl. first load
//     "cloud:userdoc"  detail: {exists, data} - the signed-in user's progress doc (already
//                       filtered so this never fires for an echo of a write this tab made
//                       itself - see the sessionId comment below)
//   this file EXPOSES window.Cloud = {
//     signIn(), signOut(),
//     saveUserDoc(uid, state) -> Promise,
//     publishGameData(data, uid) -> Promise
//   }
//
// Firestore layout:
//   config/gamedata  - one doc, the whole game dataset. Public read, admin-only write.
//   users/{uid}       - one doc per signed-in user, their `state` object. Owner read/write only.
//   admins/{uid}      - existence-only allowlist doc; its presence is what "admin" means.
// See firestore.rules at the repo root for the enforced version of the two rules above.
// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional


// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);

const firebaseConfig = {
  apiKey: "AIzaSyA_BKMpZ2WAwpbNGC0mcetNyBQDDJF55dw",
  authDomain: "srbtracker.firebaseapp.com",
  projectId: "srbtracker",
  storageBucket: "srbtracker.firebasestorage.app",
  messagingSenderId: "941631322932",
  appId: "1:941631322932:web:827a5178794663ef290361",
  measurementId: "G-D1Y9V6SC27"
};

const FIREBASE_ENABLED = !!(firebaseConfig.apiKey && firebaseConfig.projectId);

if (FIREBASE_ENABLED) {
  init().catch(function (e) {
    console.warn("[cloud] Firebase failed to start - continuing local-only.", e);
  });
} else {
  console.log("[cloud] Firebase not configured - running local-only. See FIREBASE_SETUP.md.");
}

async function init() {
  const SDK = "https://www.gstatic.com/firebasejs/10.14.1/";
  const [{ initializeApp }, authMod, fsMod] = await Promise.all([
    import(SDK + "firebase-app.js"),
    import(SDK + "firebase-auth.js"),
    import(SDK + "firebase-firestore.js")
  ]);
  const {
    getAuth, GoogleAuthProvider, signInWithPopup, signInWithRedirect,
    getRedirectResult, onAuthStateChanged, signOut: fbSignOut
  } = authMod;
  const {
    getFirestore, doc, getDoc, setDoc, onSnapshot, serverTimestamp,
    enableIndexedDbPersistence
  } = fsMod;

  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);

  // Offline cache so the app still has the last-known progress/data with no network. Can
  // legitimately fail (e.g. a second tab open without multi-tab support) - non-fatal either
  // way, matches the try/catch-and-carry-on pattern the rest of the app already uses for
  // localStorage access.
  try { await enableIndexedDbPersistence(db); } catch (e) { /* ignore */ }

  function fire(name, detail) { window.dispatchEvent(new CustomEvent(name, { detail: detail })); }

  // Firestore rejects an array directly containing another array ("nested arrays are not
  // supported"). The app's in-memory shape has two spots that are array-of-arrays - each
  // cycle (an array of 3-cell rows, each row itself an array) and the chips table (an array
  // of rows, each row [label, ...numbers]) - so those two get wrapped in an object one level
  // down purely for Firestore storage, and unwrapped again on the way back. Everything else
  // in the app (validateGameData, applyGameData, rendering) only ever sees plain arrays; this
  // translation is entirely local to talking to Firestore.
  function cyclesToFirestore(cycles) {
    var out = {};
    for (var c in cycles) out[c] = cycles[c].map(function (row) { return { cells: row }; });
    return out;
  }
  function cyclesFromFirestore(cycles) {
    var out = {};
    for (var c in cycles) out[c] = cycles[c].map(function (r) { return r.cells; });
    return out;
  }
  function chipsToFirestore(chips) {
    return { cols: chips.cols, rows: chips.rows.map(function (r) { return { label: r[0], values: r.slice(1) }; }) };
  }
  function chipsFromFirestore(chips) {
    return { cols: chips.cols, rows: chips.rows.map(function (r) { return [r.label].concat(r.values); }) };
  }
  function gameDataToFirestore(data) {
    return Object.assign({}, data, { cycles: cyclesToFirestore(data.cycles), chips: chipsToFirestore(data.chips) });
  }
  function gameDataFromFirestore(data) {
    return Object.assign({}, data, { cycles: cyclesFromFirestore(data.cycles), chips: chipsFromFirestore(data.chips) });
  }

  // ---- game data: public read, admin write, live for everyone ------------------------
  onSnapshot(doc(db, "config", "gamedata"), function (snap) {
    if (!snap.exists()) return;
    try {
      fire("cloud:gamedata", gameDataFromFirestore(snap.data()));
    } catch (e) {
      // Firestore delivers an optimistic local snapshot for ANY write attempt - including one
      // security rules will go on to reject - before the rejection is known (e.g. someone
      // poking at the SDK directly with devtools, bypassing the admin editor's own validation).
      // Ignore a snapshot that doesn't even parse as game data and wait for the next one -
      // either the rollback once the rejection lands, or a genuinely valid publish - rather
      // than letting a malformed shape crash this listener.
      console.warn("[cloud] ignoring malformed gamedata snapshot", e);
    }
  }, function (err) {
    console.warn("[cloud] gamedata watch error", err);
  });

  // ---- auth ----------------------------------------------------------------------------
  let stopUserWatch = null;

  // A per-page-load id, stamped onto every progress write this tab makes (_writerSession). It
  // is NOT about ordering writes in time - a wall-clock/timestamp comparison across devices
  // would be vulnerable to ordinary clock skew (a device running a few minutes slow could have
  // its genuinely newer edits permanently discarded as "stale"). Instead the listener asks a
  // simpler, clock-free question: "was the doc's last writer literally this tab?" If so, we
  // already have that state applied locally (we just wrote it) and can ignore the confirmation
  // - covering both the immediate optimistic echo AND a later, server-confirmed echo of an
  // already-superseded write from this same tab (e.g. the very first "seed the cloud doc"
  // write, confirmed seconds after a real edit already moved past it - Firestore's own
  // hasPendingWrites flag alone doesn't catch that case, since that confirmation isn't
  // pending, just stale). Anything written by a DIFFERENT session - necessarily a different
  // device, since a page reload gets a fresh id too - always has a different id and is applied.
  const sessionId = Math.random().toString(36).slice(2) + Date.now().toString(36);

  onAuthStateChanged(auth, function (user) {
    fire("cloud:auth", user ? {
      uid: user.uid, email: user.email, displayName: user.displayName, photoURL: user.photoURL
    } : null);

    if (stopUserWatch) { stopUserWatch(); stopUserWatch = null; }
    fire("cloud:admin", false);
    if (!user) return;

    // Admin check: existence of admins/{uid}. A stranger's read of their own admin doc is
    // harmless (it carries no data, just presence), so this needs no special rule beyond
    // "signed-in users can read their own admins/{uid}" - see firestore.rules.
    getDoc(doc(db, "admins", user.uid)).then(function (snap) {
      fire("cloud:admin", snap.exists());
    }).catch(function () { fire("cloud:admin", false); });

    stopUserWatch = onSnapshot(doc(db, "users", user.uid), function (snap) {
      if (snap.metadata.hasPendingWrites) return; // always our own not-yet-confirmed write
      const data = snap.exists() ? snap.data() : null;
      if (data && data._writerSession === sessionId) return; // confirms a write we made ourselves
      fire("cloud:userdoc", { exists: snap.exists(), data: data });
    }, function (err) {
      console.warn("[cloud] user doc watch error", err);
    });
  });

  // Installed/standalone PWAs frequently block or silently fail signInWithPopup, so go
  // straight to redirect there; everywhere else, try the popup first (it keeps you on the
  // same page/scroll position) and fall back to redirect only if the popup itself fails.
  const preferRedirect = (function () {
    try { return window.matchMedia("(display-mode: standalone)").matches; } catch (e) { return false; }
  })();

  // Resolve a pending redirect (from a previous signInWithRedirect) if there is one. Errors
  // here (e.g. no redirect in progress) are expected and non-fatal.
  getRedirectResult(auth).catch(function () { /* ignore */ });

  window.Cloud = {
    signIn: function () {
      const provider = new GoogleAuthProvider();
      if (preferRedirect) return signInWithRedirect(auth, provider);
      return signInWithPopup(auth, provider).catch(function (err) {
        const code = err && err.code;
        if (code === "auth/popup-blocked" || code === "auth/operation-not-supported-in-this-environment") {
          return signInWithRedirect(auth, provider);
        }
        throw err;
      });
    },
    signOut: function () { return fbSignOut(auth); },
    saveUserDoc: function (uid, state) {
      return setDoc(doc(db, "users", uid), Object.assign({}, state, {
        updatedAt: serverTimestamp(), _writerSession: sessionId
      }));
    },
    publishGameData: function (data, uid) {
      // gameDataToFirestore can throw on a malformed shape (e.g. a caller that bypasses the
      // admin editor's own validateGameData check); wrap it so that surfaces as a normal
      // rejected promise like any other failed write, instead of an uncaught exception that
      // leaves the editor's "Publishing..." status stuck forever.
      let payload;
      try { payload = gameDataToFirestore(data); }
      catch (e) { return Promise.reject(e); }
      return setDoc(doc(db, "config", "gamedata"), Object.assign(payload, {
        updatedAt: serverTimestamp(), updatedBy: uid
      }));
    }
  };

  fire("cloud:ready", true);
}
