# Super Rebirth Tracker — Droid Tycoon

Published as a shareable web page:
**https://claude.ai/code/artifact/97834962-5a31-4c2e-823b-400ef1d53086**
(private until you share it from the page's share menu). Everyone who opens it gets their own
saved progress — it's stored per browser, not shared.

`index.html` is the whole app. Double-click it, or copy that one file to your phone and open
it — no install, no internet, nothing else needed. The droid art and all four cycle charts are
baked into the file.

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
| `build-app.ps1` | inlines `cycle*.json` + `sprites.js` into `..\index.html`, and writes `artifact.html` |

`build-app.ps1` emits two files from one template: `..\index.html` (a complete standalone page)
and `build\artifact.html` (the same page minus the `<!doctype>/<html>/<head>/<body>` wrapper,
which the Artifact host supplies itself). Republish `artifact.html` to update the shared link.

Both outputs are pure ASCII — every dash, minus and middle dot is written as an HTML entity,
CSS escape or JS `\u` escape. The artifact copy has no `<meta charset>` of its own, so anything
non-ASCII would be at the mercy of the host's encoding guess.

`cycle1.json` … `cycle4.json` are the source of truth for the chart data. Edit those and re-run
`validate.ps1`, then `build-app.ps1`, if the game updates.

## Crystal rewards

The full chart shows the crystals (gems) earned at each rebirth, starting at Rebirth 12 (the
`◆N` figure under each level's cost). The values were read from the posters' reward column and
verified identical across cycles, same as the money costs, so they live in the shared `CRYSTALS`
table in `build-app.ps1`. The chip `+N%` and XP `+N%` parts of that column are not shown.

Chart data is stamped **Droid Tycoon Update v1.23 (25 Jul 2026)**, shown in the app footer.
