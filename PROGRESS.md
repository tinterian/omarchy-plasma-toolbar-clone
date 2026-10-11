# Keep spencer.bar in sync with stock omarchy.bar
- **Last agent worked:** 2026-10-10 21:50 + Claude Code (opus-5.5)
- **Status:** IN PROGRESS
- **Goal:** Port upstream omarchy.bar (4.0.4) into this fork and automate future re-syncs after Omarchy updates, so the bar stops breaking widgets (e.g. TekScan click did nothing).

## State
- Branch `upstream-sync-4.0.4` created off master.
- Root cause of widget breakage: fork was cloned from ~4.0.0 and lacks upstream's
  per-plugin PluginBarApi machinery (pluginBarApiFor etc.); injectProps hands every
  widget `bar = root`, and Bar has no `shell` property.
- No 4.0.0 package available (pacman cache has 4.0.2, 4.0.4; pkgs.omarchy.org dropped 4.0.0).
  Using 4.0.2 as merge base; lines 4.0.2 had but the initial clone lacked must be restored by hand.
- Note: even fully synced, a replacement bar gets service-less widget facades by
  Omarchy design. TekScan BarWidget now falls back to `omarchy-shell tekscan <action>` IPC.

## Next steps
- [ ] 3-way merge Bar.qml (base 4.0.2, ours fork, theirs 4.0.4); resolve conflicts
- [ ] Restore 4.0.2 features missing from initial clone (syncHidden IPC, barHidden margins, etc.)
- [ ] Sync widgets/, indicators/, BarModel.js with 4.0.4
- [ ] Store stock snapshot in upstream/ + UPSTREAM_VERSION
- [ ] Write bin/sync-upstream (3-way merge vs snapshot, notify on conflict)
- [ ] Install as post-update and post-boot hooks
- [ ] Verify shell log clean, bar renders, TekScan + PinnedApp clicks work

## Open questions / blockers
- none

## Done
- TekScan BarWidget: lazy service resolution + IPC fallback (its own repo).
