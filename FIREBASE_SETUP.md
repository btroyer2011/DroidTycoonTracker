# Turning on cloud sync

The tracker works today with **zero setup** — progress lives in each browser's storage,
and `docs/cloud.js` makes no network calls at all until you configure it. This is the one-time,
console-only setup (no command line needed) to turn on:

- **Cross-device progress**, updated live, once you sign in with Google.
- **A live-editable game dataset** — an in-app admin editor to change cycles/droids/costs and
  publish the change to every device instantly, no code change or redeploy.

Takes about 15 minutes.

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com/> and click **Add project**.
2. Name it anything (e.g. "droid-tycoon-tracker"). Google Analytics is optional — skip it.
3. Wait for the project to finish provisioning.

## 2. Turn on Google sign-in

1. In the left sidebar: **Build → Authentication → Get started**.
2. Under **Sign-in method**, click **Google**, toggle it **Enable**, pick a support email, **Save**.
3. Still in Authentication, open **Settings → Authorized domains** and click **Add domain**.
   Add `btroyer2011.github.io` (or your actual Pages domain, if different) — without this,
   sign-in will fail with an `auth/unauthorized-domain` error once you're live on Pages.

## 3. Create the Firestore database

1. **Build → Firestore Database → Create database**.
2. Pick any location close to you (can't be changed later, but it doesn't matter much for a
   single-user app like this).
3. Start in **production mode** — we're about to paste in our own rules, which are stricter
   than the "test mode" default anyway.

## 4. Paste in the security rules

1. In Firestore, open the **Rules** tab.
2. Replace the contents with the file `firestore.rules` from this repo (open it, copy
   everything, paste over what's there).
3. Click **Publish**.

These rules: let anyone read the game dataset (`config/gamedata`) but only an admin write it;
let a signed-in user read/write only their own progress (`users/{their-uid}`); and let a
signed-in user check only their own `admins/{their-uid}` doc (used to decide whether to show
the admin editor). Nothing else is reachable.

## 5. Register a Web App and get the public config

1. Project **Settings** (gear icon, top left) → scroll to **Your apps** → click the **</>**
   (web) icon.
2. Give it a nickname (e.g. "tracker"), **do not** check "Firebase Hosting" (we're staying on
   GitHub Pages), click **Register app**.
3. You'll see a `firebaseConfig` object like:
   ```js
   const firebaseConfig = {
     apiKey: "AIza...",
     authDomain: "droid-tycoon-tracker.firebaseapp.com",
     projectId: "droid-tycoon-tracker",
     storageBucket: "droid-tycoon-tracker.firebasestorage.app",
     messagingSenderId: "123456789012",
     appId: "1:123456789012:web:abcdef1234567890"
   };
   ```
4. Open `docs/cloud.js` in this repo and paste your six values into the `firebaseConfig`
   object near the top of the file (it starts with empty strings — fill those in, leave
   everything else in the file alone). Commit and push.

> These six values are **public identifiers**, not secrets — they're meant to be embedded in
> client-side code (that's how every Firebase web app ships them). Your data is protected by
> the security rules from step 4 and by Google sign-in, not by hiding this config. Never
> commit a *service-account* JSON key, though — that's a different, genuinely secret thing,
> and this setup never needs one.

## 6. Make yourself an admin

1. Open the live app (on GitHub Pages, once `docs/cloud.js` with your config is deployed).
   Scroll down the main page to the **Account & sync** section (it's its own collapsible
   section alongside "Backup & restore" — not inside the gear-icon Settings popup) and click
   **Sign in with Google**. (The "Account & sync" section only appears once `docs/cloud.js` is
   configured.)
2. In the Firebase console, go to **Authentication → Users** and copy the **User UID** next to
   the account you just signed in with.
3. Go to **Firestore Database → Data**, click **Start collection**, name it `admins`.
4. For the **Document ID**, paste your UID from step 2. Add any field (e.g. `note: "me"` —
   the content doesn't matter, only that the document exists at that ID) and **Save**.
5. Reload the app. The **Game data (admin)** section should now appear under Account & sync.

## 7. Publish the game dataset for the first time

The app already ships with the full current dataset built in (that's what it uses until
something's published, and what it falls back to if the network is down). To seed Firestore
with it:

1. In the app, open the **Account & sync** section and find **Game data (admin)** underneath it.
2. Click **Load current** — this fills the text box with the currently-active dataset as JSON.
3. Click **Validate** to confirm it's well-formed (it will be, since it just came from the app
   itself).
4. Click **Publish live**. Every signed-in device now reads this dataset, live, going forward.

## Editing the game data later

Whenever the game changes: **Load current** (to start from what's live), edit the JSON
(droid names/rarities in `cycles`, money in `costs`, crystal rewards in `crystals`, chip costs
in `chips`, rarity-class lists in `rarityClasses`), **Validate**, then **Publish live**. It
updates every signed-in device within about a second, no deploy required.

A cell in `cycles` looks like `{"n": "R9", "r": "GOLD"}` (name + rarity/variation), or
`{"n": "?", "r": "?", "u": true}` for an undocumented placeholder (shown as a red "?"). Each
cycle needs exactly `maxlvl` rows of exactly 3 cells each.

**Note:** publishing new cycle data doesn't add sprite art. A droid/rarity combo with no image
already baked into `docs/index.html` shows its name as text instead of a picture — same as it
does today for the few tiles that already lack art. Adding new art still requires an app code
change.

## Everyday use after setup

- Signed out: exactly today's behavior — local device only.
- Signed in: your progress follows you, live, across every device you sign into with the same
  Google account. The on-device export/import backup code still works too, independent of
  this — it's an extra safety net, not replaced by cloud sync.
