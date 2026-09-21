#!/bin/bash
# ============================================================================
# FILE:    install.sh
# TASK:    One-step install of the toolbar + menu "package deal"
# STATUS:  DONE
# OWNER:   agent A 2026-09-20 18:50
#
# WHAT THIS FILE DOES:
#   Omarchy scans third-party plugins one folder deep with one manifest each,
#   so this repo's menu/ (id spencer.menu) is invisible on its own. This links
#   it into ~/.config/omarchy/plugins/spencer.menu, rescans, enables both
#   spencer.bar and spencer.menu, and restarts the shell. Idempotent.
#   A symlink (not a copy) means `omarchy plugin update spencer.bar` or a
#   plain `git pull` updates the menu too; nothing to sync by hand.
#
# NEXT STEP (if not DONE):
#   none — file complete
# ============================================================================
#
# Usage: install.sh [--no-restart]
# Fresh machine, one line:
#   omarchy plugin add https://github.com/tinterian/omarchy-plasma-toolbar-clone.git --yes \
#     && ~/.config/omarchy/plugins/spencer.bar/install.sh

set -euo pipefail

PLUGINS_DIR="$HOME/.config/omarchy/plugins"
BAR_ID="spencer.bar"
MENU_ID="spencer.menu"

fail() {
  echo "install.sh: $*" >&2
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

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
[[ -d $PLUGINS_DIR/$BAR_ID ]] || fail "this repo must live at $PLUGINS_DIR/$BAR_ID (see the one-line install in the header)"
[[ $here == "$(cd "$PLUGINS_DIR/$BAR_ID" && pwd -P)" ]] || fail "run the copy at $PLUGINS_DIR/$BAR_ID, not $here"
[[ -f $here/menu/manifest.json ]] || fail "menu/manifest.json missing from $here"

plugin_enabled() {
  omarchy plugin list --json | jq -e --arg id "$1" '.[] | select(.id == $id and .enabled)' >/dev/null
}

plugin_known() {
  omarchy plugin list --json | jq -e --arg id "$1" '.[] | select(.id == $id)' >/dev/null
}

# 1. Link menu/ in as its own plugin folder. A real folder already there (an
#    old `omarchy plugin clone` + copy install) is moved aside, never deleted;
#    dot-prefixed folders are ignored by the plugin scanner.
link="$PLUGINS_DIR/$MENU_ID"
if [[ -L $link && $(readlink "$link") == "$BAR_ID/menu" ]]; then
  echo "menu link already in place"
else
  if [[ -e $link || -L $link ]]; then
    backup="$PLUGINS_DIR/.$MENU_ID.bak.$(date +%s)"
    mv "$link" "$backup"
    echo "moved existing $MENU_ID aside to $backup"
  fi
  ln -s "$BAR_ID/menu" "$link"
  echo "linked $link -> $BAR_ID/menu"
fi

# 2. Rescan and wait for the shell to see it.
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || fail "could not reach omarchy-shell (is the shell running?)"
for _ in $(seq 1 20); do
  plugin_known "$MENU_ID" && break
  sleep 0.5
done
plugin_known "$MENU_ID" || fail "shell did not pick up $MENU_ID; run: omarchy plugin validate $here/menu"

# 3. Enable both. Enabling the menu clone swaps it into the stock menu's bar
#    slot and disables omarchy.menu; enabling the bar sets bar.id.
for id in "$BAR_ID" "$MENU_ID"; do
  if plugin_enabled "$id"; then
    echo "$id already enabled"
  else
    omarchy plugin enable "$id"
    echo "enabled $id"
  fi
done

# 4. Menu changes only load after a shell restart.
if (( restart )); then
  omarchy restart shell
  echo "shell restarted"
else
  echo "skipped shell restart; run 'omarchy restart shell' to load the menu"
fi

echo "Done. Example bar layout: $here/shell.json.example"
