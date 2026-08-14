# Super Rebirth Tracker — Droid Tycoon

Three ways to open it:

- **GitHub Pages (recommended on iOS):** https://btroyer2011.github.io/DroidTycoonTracker/
  — a real page you own, not embedded in anything else. See [iOS: install it properly](#ios-install-it-properly-so-progress-actually-saves)
  below — this is the one that fixes progress resetting on iPhone.
- **Claude Artifact:** https://claude.ai/code/artifact/97834962-5a31-4c2e-823b-400ef1d53086
  (private until you share it from the page's share menu). Convenient for sharing a link in
  chat, but on iOS this one is prone to losing progress — see below.
- **The file itself:** `index.html` is the whole app. Double-click it, or copy that one file to
  your phone and open it — no install, no internet, nothing else needed.

All three are the same app. The droid art and all four cycle charts are baked into each one.
Progress is saved per browser/device, not shared between them.

## iOS: install it properly, so progress actually saves

If you're on an iPhone and progress resets every time you close and reopen the app, it's iOS
Safari's storage rules, not a bug in the tracker: sites you haven't opened directly in Safari for
a few days get their saved data wiped, and content embedded in someone else's page (which is how
the Claude Artifact link works) is restricted even harder — that's very likely why the Artifact
link resets constantly on iPhone specifically.

The fix is to open the **GitHub Pages** link above in Safari, then add it to your Home Screen:

1. Open https://btroyer2011.github.io/DroidTycoonTracker/ in **Safari** (not the Claude app,
   not Chrome — it has to be Safari for this step).
2. Tap the **Share** icon → **Add to Home Screen** → **Add**.
3. Always launch it from that Home Screen icon from now on.

A web app added to the Home Screen this way runs outside Safari's normal tab rules and gets its
own storage that only clears if *the app itself* goes unused for a long stretch — not the
7-day-since-any-Safari-tab timer that a bookmark or shared link is subject to.

## What it does

- **Pick your cycle** (1–4). Each cycle remembers its own rebirth level, so switching back and
  forth never loses your place.
- **Step your rebirth level** with − / + . Progress is saved in the browser automatically.
- **Reset to Rebirth 1** opens a cycle picker rather than just resetting. After a super rebirth
  you don't necessarily land on the cycle you were just on, so it shows all four cycles' Rebirth 1
  droids side by side — match whichever trio the game is asking you for and it sets the cycle for
  you. Only the cycle you pick is reset; the other three keep their levels. Cancel, Escape or a
  tap outside all back out without changing anything.

  Each cycle's Rebirth 1 trio is unique, so the set identifies the cycle. Individual droids are
  not enough on their own — PIT starts cycles 1, 3 and 4 — which is why all three are shown.
- **You need now** — the three droids and money cost for your current rebirth.
- **Sell or keep** — for each droid you're holding, one of:
  - **SELL** — not required again anywhere in this cycle.
  - **SELL, but needed again** — safe to sell now, but the chart asks for it again in the
    Rebirth 21–30 block.
  - **KEEP** — required again before Rebirth 21, and it tells you exactly which rebirth and at
    what rarity.
- **Up next** — the following rebirth, so you can pre-plan.
- **New vs. owned marker** — every droid tile shows whether this is the first rebirth in the
  cycle that needs it (a **✦ NEW** badge, a fresh pull or build) or one you should already own
  from earlier (a **↺ R*n*** badge naming the rebirth you first got it, so this one just upgrades
  its rarity). On the full chart, first appearances get a small cyan dot.
- **Find a droid** — search any droid name and get its whole timeline for the selected cycle:
  every rebirth it's needed at and the rarity each time, with the first (the ✦ acquisition point)
  flagged. The search is scoped to the current cycle and refreshes when you switch cycles.
- **Full chart** — all 30 rebirths for the selected cycle, laid out like the original poster,
  with your current row highlighted and scrolled into view.
- **Upgrade chip costs** — the reference table from the posters' Additional Info panel.

The sell/keep verdicts are computed from the chart data, not copied from the poster's SELL
banners. That means they stay correct no matter which rebirth you're on, and they name the
exact rebirth a droid is next needed at rather than just saying "keep".

## Where the data came from

Transcribed from `Cycle 1.jpg` … `Cycle 4.jpg` in the parent folder. Those files are never
modified.

All 360 cells (4 cycles × 30 rebirths × 3 droids) were cross-checked against the posters' own
SELL banners using this rule — for a droid needed at level `L`, let `L'` be the next level above
`L` in the same cycle where it appears again:

| condition | expected banner |
|---|---|
| no `L'` | yellow SELL |
| `L < 21` and `L' >= 21` | red SELL |
| otherwise | no banner |

Because the banners are redundant with the droid line-ups, any disagreement means something was
misread. `build\validate.ps1` runs that check; it currently reports **360/360 clean**.

Money costs and the Upgrade Chips table are identical on all four posters, so they're stored
once and shared.

## Rebuilding

Everything under `build\` regenerates `index.html` from the posters. Run from `build\`:

```bash
powershell -ExecutionPolicy Bypass -File make-sprites.ps1
```

```bash
powershell -ExecutionPolicy Bypass -File build-app.ps1
```

| script | what it does |
|---|---|
| `detect-grid.ps1` | finds the cell rectangles on a poster by locating the bright cell frames |
| `grid.ps1` | the resulting geometry, shared by the other scripts |
| `make-panels.ps1` | cuts each poster into 24 readable 5-level panels (for re-transcribing) |
| `zoom-cell.ps1` | blows up specific cells to double-check a reading |
| `make-sprites.ps1` | cuts the 195 unique droid+rarity tiles into `sprites.js` |
| `sheet.ps1` / `sprite-check.html` | contact sheets for eyeballing the tiles |
| `validate.ps1` | the 360-cell banner cross-check |
| `build-app.ps1` | inlines `cycle*.json` + `sprites.js` into `..\index.html`, `build\artifact.html`, and `..\..\docs\index.html` |
| `make-icons.ps1` | (re)generates the `docs\icon-*.png` Home Screen icons — run by hand, not part of the normal build |

`build-app.ps1` emits three files from one template:

- `..\index.html` — the complete standalone page, no sibling files needed.
- `build\artifact.html` — the same page minus the `<!doctype>/<html>/<head>/<body>` wrapper,
  which the Artifact host supplies itself. Republish this to update the shared Artifact link.
- `..\..\docs\index.html` (repo root `docs\`) — the GitHub Pages copy, plus `docs\manifest.json`.
  This is the only variant with the `<link rel="manifest">` / Apple `apple-mobile-web-app-*`
  tags that make "Add to Home Screen" install as a real standalone app instead of a bookmark
  (see the iOS section above for why that matters). It references `manifest.json` and the
  `icon-*.png` files as sibling paths rather than inlining them, since GitHub Pages is a proper
  multi-file static site, not a copy-this-one-file distribution like the other two.

The plain `index.html` and `artifact.html` outputs are pure ASCII — every dash, minus and middle
dot is written as an HTML entity, CSS escape or JS `\u` escape. The artifact copy has no
`<meta charset>` of its own, so anything non-ASCII would be at the mercy of the host's encoding
guess. `docs\index.html` keeps the same ASCII discipline for consistency, even though it has its
own `<meta charset>` and doesn't strictly need it.

### GitHub Pages setup (one-time, in the repo's Settings)

`docs\` is checked in, but GitHub Pages still has to be pointed at it once:
**Settings → Pages → Source: Deploy from a branch → Branch: `master`, folder: `/docs` → Save.**
After that, every push that touches `docs\` updates the live Pages site automatically — no
separate deploy step.

`cycle1.json` … `cycle4.json` are the source of truth for the chart data. Edit those and re-run
`validate.ps1`, then `build-app.ps1`, if the game updates.

## Crystal rewards

The full chart shows the crystals (gems) earned at each rebirth, starting at Rebirth 12 (the
`◆N` figure under each level's cost). The values were read from the posters' reward column and
verified identical across cycles, same as the money costs, so they live in the shared `CRYSTALS`
table in `build-app.ps1`. The chip `+N%` and XP `+N%` parts of that column are not shown.

Chart data is stamped **Droid Tycoon Update v1.23 (25 Jul 2026)**, shown in the app footer.
