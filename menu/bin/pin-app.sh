#!/bin/bash
# ============================================================================
# FILE:    ~/.config/omarchy/plugins/spencer.menu/bin/pin-app.sh
# TASK:    Pin/unpin an app (desktop id) to the bar or the dock, from the menu's right-click popup
# STATUS:  DONE
# OWNER:   Claude Code 2026-09-20 16:05
#
# WHAT THIS FILE DOES:
#   usage: pin-app.sh bar-pin|bar-unpin|dock-pin|dock-unpin <desktop-id> [label]
#   bar-*  edits shell.json's bar layout: appends/removes a spencer.bar PinnedApp entry ({"app": id}).
#   dock-* delegates to animated.dock's own omarchy-dock-config (atomic, validated writer).
#   The shell re-reads shell.json on save, so changes show up live.
#
# NEXT STEP (if not DONE):
#   none — verified 2026-09-20 via the menu popup: bar-pin/bar-unpin/dock-pin/dock-unpin on a real app.
# ============================================================================
set -uo pipefail

CFG="${PIN_APP_CFG:-$HOME/.config/omarchy/shell.json}"
DOCK_CFG="$HOME/.config/omarchy/plugins/animated.dock/bin/omarchy-dock-config"
DEFAULT_SRC="~/.config/omarchy/plugins/spencer.bar/widgets/PinnedApp.qml"

verb=${1:-}
app=${2:-}
app=${app%.desktop}
label=${3:-$app}

[[ -n $verb && -n $app ]] || { echo "usage: pin-app.sh bar-pin|bar-unpin|dock-pin|dock-unpin <desktop-id> [label]" >&2; exit 2; }

notify() {
  command -v omarchy-notification-send >/dev/null 2>&1 \
    && omarchy-notification-send -g 󰐃 "$1" "$2" >/dev/null 2>&1
  return 0
}

# Write a mutated shell.json atomically, only if it is still valid JSON with a bar layout.
apply_bar() {
  local expr=$1 tmp
  shift
  tmp=$(mktemp "$CFG.XXXXXX") || return 1
  if ! jq "$@" "$expr" "$CFG" >"$tmp" 2>/dev/null || ! jq -e '.bar.layout | type == "object"' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "error: update failed — nothing changed." >&2
    return 1
  fi
  mv "$tmp" "$CFG"
}

case "$verb" in
  bar-pin)
    if jq -e --arg k "${app,,}" '[.bar.layout[]?[]? | (.app // empty | ascii_downcase | sub("\\.desktop$"; ""))] | index($k) != null' "$CFG" >/dev/null 2>&1; then
      notify "Already on the bar" "$label"
      exit 0
    fi
    slug=$(printf '%s' "${app,,}" | tr -c 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')
    apply_bar '
      (([.bar.layout[]?[]? | select((.source // "") | endswith("PinnedApp.qml")) | .source] | first) // $src) as $s
      | .bar.layout.left += [{app: $app, id: ($slug + "-launcher"), label: $label, source: $s, type: "qml"}]
    ' --arg app "$app" --arg label "$label" --arg slug "$slug" --arg src "$DEFAULT_SRC" || exit 1
    notify "Pinned to bar" "$label"
    ;;
  bar-unpin)
    apply_bar '
      .bar.layout |= with_entries(.value |= (if type == "array"
        then map(select(((.app // "") | ascii_downcase | sub("\\.desktop$"; "")) != $k)) else . end))
    ' --arg k "${app,,}" || exit 1
    notify "Unpinned from bar" "$label"
    ;;
  dock-pin)
    [[ -x $DOCK_CFG ]] || { echo "error: animated.dock not installed" >&2; exit 1; }
    "$DOCK_CFG" pin "$app" || exit 1
    notify "Pinned to dock" "$label"
    ;;
  dock-unpin)
    [[ -x $DOCK_CFG ]] || { echo "error: animated.dock not installed" >&2; exit 1; }
    idx=$(jq -r --arg k "${app,,}" '
      .plugins[]? | select(.id == "animated.dock") | .items | to_entries[]
      | select(((.value.desktop // "") | ascii_downcase | sub("\\.desktop$"; "")) == $k) | .key' "$CFG" | head -1)
    [[ -n $idx ]] || { notify "Not on the dock" "$label"; exit 0; }
    "$DOCK_CFG" unpin "$idx" || exit 1
    notify "Unpinned from dock" "$label"
    ;;
  *)
    echo "unknown verb '$verb'" >&2
    exit 2
    ;;
esac
