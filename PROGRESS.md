# Keep spencer.bar in sync with stock omarchy.bar
- **Last agent worked:** 2026-10-10 21:55 + Claude Code (opus-5.5)
- **Status:** DONE
- **Goal:** Port upstream omarchy.bar (4.0.4) into this fork and automate future re-syncs after Omarchy updates, so the bar stops breaking widgets (e.g. TekScan click did nothing).

## State
- master contains the 4.0.4 merge, upstream/ snapshot (VERSION 4.0.4-1) and bin/sync-upstream.
- Hooks installed: ~/.config/omarchy/hooks/{post-update,post-boot}.d/spencer-bar-sync.hook
  (thin wrapper calling bin/sync-upstream --quiet).
- floating-settings.json is runtime state and is now gitignored.

## Next steps
- [ ] User to click the TekScan bar button and confirm (verified via shell summon/hide IPC only).
- [ ] User to confirm PinnedApp right-click > Unpin still works (barHost path; not clicked).

## Open questions / blockers
- none

## Done
- Bar.qml 3-way merged (base 4.0.2, theirs 4.0.4); restored syncHidden IPC, tooltip
  PlainText, press-and-hold guard that the ~4.0.0 clone never had. Shell log clean for spencer.bar.
- widgets/, indicators/, BarModel.js replaced with stock 4.0.4 (fork had no edits there).
- Bar hide/show (omarchy-toggle-bar) verified with floating gap intact.
- TekScan opens/closes through the bar's summon path after `omarchy restart shell`.
- sync-upstream tested on a clone: no-op, clean merge (+add/delete), conflict (live untouched),
  dirty tree skip, rollback on simulated load error (+no retry).
- TekScan BarWidget (separate repo, uncommitted): lazy service lookup + IPC fallback.
