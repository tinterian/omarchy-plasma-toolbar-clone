// ============================================================================
// FILE:    ~/.config/omarchy/plugins/spencer.bar/widgets/PinnedApp.qml
// TASK:    Bar launcher icons for Kodi / Clementine ("app" entries) not showing an icon or launching
// STATUS:  DONE
// OWNER:   Claude Code 2026-09-20 16:25
//
// WHAT THIS FILE DOES:
//   One pinned launcher icon per shell.json layout entry. "command" entries run a shell
//   command; "app" entries launch a .desktop id. The shell only injects appLibrary into
//   plugins of kind "menu", so under this "bar" plugin it is null: "app" entries now fall
//   back to DesktopEntries + the icon theme for the icon and to gtk-launch for launching.
//   "app" entries first focus an already-running window (ToplevelManager, like animated.dock)
//   because single-instance apps ignore a second launch and Wayland can't raise them.
//   Right-click opens a menu whose rows follow animated.dock's ContextMenu.qml (Desktop Actions,
//   New Window, Unpin, open windows, Close); Unpin calls Bar.removeModuleFromConfig.
//
// NEXT STEP (if not DONE):
//   none — right-click menu verified 2026-09-20 via a temporary IPC hook (removed): rows render
//   and Unpin removes the entry. A physical right-click and Close Window were not exercised.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// A single pinned launcher icon. One instance per pinned item — add more
// entries with this id to shell.json's bar layout to pin more than one.
// Either "command" (any shell command, e.g. "omarchy-agent") or "app" (an
// installed .desktop id, launched through the shared app library so it
// behaves exactly like picking it from the built-in app menu) must be set;
// "command" wins if both are present.
BarWidget {
  id: root
  moduleName: "spencer.bar.pinnedApp"

  readonly property string command: setting("command", "")
  readonly property string appId: setting("app", "")
  // Absolute path to an SVG/PNG, or a themed icon name resolved the same way
  // the app menu resolves .desktop Icon= values. Falls back to a generic
  // glyph when nothing resolves, so a typo'd icon path doesn't leave a blank
  // button.
  readonly property string iconPath: setting("icon", "")
  readonly property string label: setting("label", appId || command || "App")

  // Only injected for plugins whose manifest declares kind "menu", so this is
  // null under a "bar" plugin; everything below must work without it.
  readonly property var appLibrary: root.bar && root.bar.shell ? root.bar.shell.appLibrary : null
  // Reading .values makes the binding re-run once the desktop entries have
  // finished loading at shell start.
  readonly property var desktopEntry: {
    var loaded = DesktopEntries.applications.values
    return appId.length > 0 ? DesktopEntries.byId(appId) : null
  }
  readonly property string appIconName: desktopEntry && desktopEntry.icon ? String(desktopEntry.icon) : appId
  readonly property string resolvedIconSource: {
    if (iconPath.length > 0) return iconPath.charAt(0) === "/" ? Util.fileUrl(iconPath) : iconPath
    if (appId.length > 0) {
      if (appLibrary) return appLibrary.iconSource(appIconName)
      if (appIconName.charAt(0) === "/") return Util.fileUrl(appIconName)
      // Empty when the theme has no match, which falls through to the glyph.
      return Quickshell.iconPath(appIconName, true)
    }
    return ""
  }

  visible: command.length > 0 || appId.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Wayland app ids this pin owns, matched case-insensitively and also on the
  // last dot-segment ("clementine" vs "org.clementine_player.Clementine"), the
  // same looseness animated.dock's RunningModel uses.
  function matchesApp(toplevelAppId) {
    var keys = []
    if (desktopEntry && desktopEntry.startupClass) keys.push(String(desktopEntry.startupClass))
    keys.push(appId.replace(/\.desktop$/, ""))
    var a = String(toplevelAppId || "").toLowerCase()
    if (!a) return false
    for (var i = 0; i < keys.length; i++) {
      var b = keys[i].toLowerCase()
      if (!b) continue
      if (a === b || a.split(".").pop() === b || a === b.split(".").pop()) return true
    }
    return false
  }

  // Focus the already-running window if there is one. Single-instance apps
  // (Clementine) ignore a second launch and Wayland won't let them raise
  // themselves, so a repeat click otherwise does nothing visible.
  function focusRunning() {
    var vals = ToplevelManager.toplevels.values || []
    for (var i = 0; i < vals.length; i++) {
      if (!matchesApp(vals[i].appId)) continue
      if (vals[i].minimized) vals[i].minimized = false
      vals[i].activate()
      return true
    }
    return false
  }

  function launchNew() {
    if (command.length > 0) Util.execDetached(command)
    else if (appId.length > 0 && appLibrary) appLibrary.launch(appId, root.label)
    // Same command AppLibrary.launch() runs; the .desktop suffix is required.
    else if (appId.length > 0) Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(appId + ".desktop"))
  }

  function launch() {
    if (command.length === 0 && appId.length > 0 && focusRunning()) return
    launchNew()
  }

  // ---- Right-click menu. Rows, glyphs and behaviour follow animated.dock's
  // ContextMenu.qml: the app's own Desktop Actions, New Window, Unpin, then
  // its open windows and Close. Popup and outside-click dismissal are the
  // shell's PopupCard.

  property var menuRows: []
  property var menuWins: []

  function runningWindows() {
    if (command.length > 0 || appId.length === 0) return []
    var out = []
    var vals = ToplevelManager.toplevels.values || []
    for (var i = 0; i < vals.length; i++)
      if (matchesApp(vals[i].appId)) out.push(vals[i])
    return out
  }

  function desktopActions() {
    var entry = desktopEntry
    if (!entry || entry.runInTerminal || !entry.actions) return []
    var out = []
    for (var i = 0; i < entry.actions.length; i++) {
      var a = entry.actions[i]
      if (a && a.command && a.command.length > 0) out.push(a)
    }
    return out
  }

  function isNewWindowAction(action) {
    var id = String(action && action.id || "").toLowerCase().replace(/_/g, "-")
    return id === "new-window" || id === "newwindow"
  }

  function runDesktopAction(action) {
    if (!action || !action.command || action.command.length < 1) return
    var argv = ["uwsm-app", "--"]
    for (var i = 0; i < action.command.length; i++) argv.push(String(action.command[i]))
    var spec = { command: argv }
    if (desktopEntry && desktopEntry.workingDirectory) spec.workingDirectory = String(desktopEntry.workingDirectory)
    Quickshell.execDetached(spec)
  }

  // Apps that ship a new-window action run it; everything else launches plainly.
  function launchNewWindow() {
    var acts = desktopActions()
    for (var i = 0; i < acts.length; i++) {
      if (isNewWindowAction(acts[i])) { runDesktopAction(acts[i]); return }
    }
    launchNew()
  }

  function unpin() {
    if (root.bar && typeof root.bar.removeModuleFromConfig === "function")
      root.bar.removeModuleFromConfig(root.moduleName)
  }

  function buildMenuRows(wins) {
    var out = []
    var acts = desktopActions().filter(function(a) { return !isNewWindowAction(a) })
    for (var a = 0; a < acts.length; a++)
      out.push({ kind: "action", glyph: "󰅂", label: String(acts[a].name || acts[a].id || "Action"), act: "desktop-action", action: acts[a] })
    if (acts.length > 0) out.push({ kind: "sep" })
    out.push({ kind: "action", glyph: "󰐕", label: appId.length > 0 && command.length === 0 ? "New Window" : "Open", act: "launch" })
    out.push({ kind: "action", glyph: "󰐃", label: "Unpin", act: "unpin" })
    if (wins.length > 1) {
      out.push({ kind: "sep" })
      for (var i = 0; i < wins.length; i++)
        out.push({ kind: "window", glyph: "󱂬", label: String(wins[i].title || wins[i].appId || "window"), winIndex: i })
    }
    if (wins.length > 0) {
      out.push({ kind: "sep" })
      out.push({ kind: "action", glyph: "󰅖", label: wins.length > 1 ? "Close All Windows" : "Close Window", act: "close-wins" })
    }
    return out
  }

  function openMenu() {
    if (menu.open) { menu.open = false; return }
    root.menuWins = root.runningWindows()
    root.menuRows = root.buildMenuRows(root.menuWins)
    menu.open = true
  }

  function runMenuRow(row) {
    var wins = root.menuWins.slice()
    menu.open = false
    if (row.act === "desktop-action") root.runDesktopAction(row.action)
    else if (row.act === "launch") root.launchNewWindow()
    else if (row.act === "unpin") root.unpin()
    else if (row.act === "close-wins") { for (var i = 0; i < wins.length; i++) wins[i].close() }
    else if (row.kind === "window" && wins[row.winIndex]) wins[row.winIndex].activate()
  }


  FontMetrics {
    id: menuFm
    font.family: Style.font.resolvedFamily
    font.pixelSize: Style.font.bodySmall
  }

  readonly property int menuGlyphColumn: Style.space(22)
  readonly property int menuSepHeight: Style.spacing.sm * 2 + 1
  readonly property int menuItemHeight: Math.round(Style.font.bodySmall + Style.spacing.md * 2 + Style.spacing.xs * 2)
  // Measured from the model, not the delegates (sizing off the Column is a layout cycle).
  readonly property int menuRowWidth: {
    var w = menuWins.length > 0 ? Style.space(220) : Style.space(150)
    for (var i = 0; i < menuRows.length; i++) {
      if (menuRows[i].kind !== "action") continue
      w = Math.max(w, menuFm.advanceWidth(String(menuRows[i].label || "")))
    }
    return Math.min(Math.round(w), Style.space(300)) + menuGlyphColumn + Style.spacing.lg * 2
  }
  readonly property int menuRowsHeight: {
    var h = 0
    for (var i = 0; i < menuRows.length; i++) h += menuRows[i].kind === "sep" ? menuSepHeight : menuItemHeight
    return h
  }

  PopupCard {
    id: menu
    anchorItem: button
    bar: root.bar
    triggerMode: "click"
    contentWidth: root.menuRowWidth + menu.verticalContentInset
    contentHeight: root.menuRowsHeight + menu.verticalContentInset

    Column {
      width: parent.width

      Repeater {
        model: root.menuRows

        delegate: Item {
          id: row
          required property var modelData

          readonly property bool isSep: modelData.kind === "sep"

          implicitHeight: isSep ? root.menuSepHeight : root.menuItemHeight
          width: parent ? parent.width : 0

          Rectangle {
            visible: row.isSep
            anchors.verticalCenter: parent.verticalCenter
            x: Style.spacing.md
            width: parent.width - Style.spacing.md * 2
            height: 1
            color: Util.alpha(Color.popups.text, 0.2)
          }

          Rectangle {
            visible: rowHover.hovered && !row.isSep
            anchors.fill: parent
            radius: Math.max(2, Math.round(Style.cornerRadius / 2))
            color: Util.alpha(Color.accent, 0.16)
          }

          Text {
            visible: !row.isSep
            x: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.glyph || ""
            color: rowHover.hovered ? Color.accent : Color.popups.text
            font.family: Style.font.resolvedFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: !row.isSep
            x: Style.spacing.lg + root.menuGlyphColumn
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.label || ""
            color: rowHover.hovered ? Color.accent : Color.popups.text
            font.family: Style.font.resolvedFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: root.menuRowWidth - x - Style.spacing.lg
          }

          HoverHandler { id: rowHover; enabled: !row.isSep }
          TapHandler { enabled: !row.isSep; onTapped: root.runMenuRow(row.modelData) }
        }
      }
    }
  }

  Component {
    id: iconImageComponent
    Image {
      source: root.resolvedIconSource
      fillMode: Image.PreserveAspectFit
      smooth: true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰀻"
    iconComponent: root.resolvedIconSource.length > 0 ? iconImageComponent : null
    tooltipText: root.label
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.launch()
      else if (b === Qt.RightButton) root.openMenu()
    }
  }
}
