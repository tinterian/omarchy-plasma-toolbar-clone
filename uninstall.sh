#!/bin/bash
# ============================================================================
# FILE:    uninstall.sh
# TASK:    Reverse install.sh: hand the bar and start menu back to stock
# STATUS:  DONE
# OWNER:   agent A 2026-09-20 18:50
#
# WHAT THIS FILE DOES:
#   Undoes everything install.sh and the bar changed outside this checkout:
#   - re-enables the stock omarchy.menu and omarchy.bar (the shell restores
#     the start button's slot and clears bar.id)
#   - removes the spencer.menu symlink, and puts back a spencer.menu folder
#     install.sh had moved aside
#   - removes the bar's pinned-app entries from shell.json (they load
#     widgets/PinnedApp.qml from this checkout; backup saved first)
#   - removes the post-boot/post-update hooks and their sync state
#   - removes the blur block from ~/.config/hypr/looknfeel.lua
#   - restarts the shell
#   Leaves this checkout in place; delete it with
#   `omarchy plugin remove spencer.bar --yes` if you want it gone.
#
# NEXT STEP (if not DONE):
#   none — file complete
# ============================================================================
#
# Usage: uninstall.sh [--no-restart]

set -euo pipefail

PLUGINS_DIR="$HOME/.config/omarchy/plugins"
MENU_ID="spencer.menu"

fail() {
  echo "uninstall.sh: $*" >&2
  exit 1
}

restart=1
for arg in "$@"; do
  case "$arg" in
  --no-restart) restart=0 ;;
  -h | --help)
    sed -n '/^# Usage:/,/^$/p' "$0"
    exit 0
    ;;
  *) fail "unknown option: $arg" ;;
  esac
done

command -v omarchy >/dev/null || fail "omarchy CLI not found"
command -v jq >/dev/null || fail "jq not found"

# Order matters: the shell restores a clone's source only while the clone is
# still installed, so switch back to the stock ones BEFORE removing the link.
omarchy plugin enable omarchy.menu
omarchy plugin enable omarchy.bar

link="$PLUGINS_DIR/$MENU_ID"
if [[ -L $link ]]; then
  rm "$link"
  echo "removed link $link"
elif [[ -e $link ]]; then
  echo "left $link alone: it is a real folder, not the install.sh symlink"
fi
# install.sh moves a pre-existing spencer.menu folder aside rather than
# deleting it; put the newest one back.
if [[ ! -e $link ]]; then
  moved=$(ls -d "$PLUGINS_DIR/.$MENU_ID.bak."* 2>/dev/null | sort | tail -1 || true)
  if [[ -n $moved ]]; then
    mv "$moved" "$link"
    echo "restored $link from $moved"
  fi
fi
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

# Pinned-app icons are bar layout entries whose source is this checkout's
# widgets/PinnedApp.qml; they break once the checkout is gone.
cfg="$HOME/.config/omarchy/shell.json"
pinned='[.. | objects | select((.source? // "") | type == "string" and test("/plugins/spencer\\.bar/"))] | length'
if [[ -f $cfg ]] && (( $(jq "$pinned" "$cfg") > 0 )); then
  n=$(jq "$pinned" "$cfg")
  backup="$cfg.bak.$(date +%s)"
  cp "$cfg" "$backup"
  tmp=$(mktemp "$cfg.XXXXXX")
  if jq '(.bar.layout // {}) |= with_entries(.value |= (if type == "array" then map(select(((.source? // "") | type == "string" and test("/plugins/spencer\\.bar/")) | not)) else . end))' "$cfg" >"$tmp" \
    && (( $(jq "$pinned" "$tmp") == 0 )); then
    mv "$tmp" "$cfg"
    echo "removed $n pinned-app entries from $cfg (backup: $backup)"
  else
    rm -f "$tmp"
    echo "could not remove pinned-app entries from $cfg; left it unchanged" >&2
  fi
fi

# Remove the boot/update hooks, their sync state, and the blur block.
rm -f "$HOME/.config/omarchy/hooks/post-boot.d/spencer-bar-sync.hook" \
  "$HOME/.config/omarchy/hooks/post-update.d/spencer-bar-sync.hook"
rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/spencer.bar-sync"
# install.sh may have created these; remove them only if nothing else uses them.
rmdir "$HOME/.config/omarchy/hooks/post-boot.d" "$HOME/.config/omarchy/hooks/post-update.d" 2>/dev/null || true
rmdir "$HOME/.config/omarchy/hooks" 2>/dev/null || true
lnf="$HOME/.config/hypr/looknfeel.lua"
if [[ -f $lnf ]] && grep -qF -- "-- spencer.bar: blur behind the floating bar only." "$lnf"; then
  python3 - "$lnf" <<'PY'
import sys
p = sys.argv[1]
lines = open(p).read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("-- spencer.bar: blur behind"))
end = next(i for i in range(start, len(lines)) if 'namespace = "omarchy-bar"' in lines[i])
while start > 0 and lines[start - 1] == "":
    start -= 1
open(p, "w").write("\n".join(lines[:start] + lines[end + 1:]))
PY
  hyprctl reload >/dev/null 2>&1 || true
  echo "removed the blur block from $lnf"
fi

if (( restart )); then
  omarchy restart shell
  echo "shell restarted"
fi

echo "Done. Stock bar and menu restored. To delete this checkout: omarchy plugin remove spencer.bar --yes"
