// ============================================================================
// FILE:    ~/.config/omarchy/plugins/spencer.menu/LocalAppLibrary.qml
// TASK:    Fallback app list for the cloned menu when the host hands it a null appLibrary
// STATUS:  DONE
// OWNER:   Claude Code 2026-09-20 13:40
//
// WHAT THIS FILE DOES:
//   Same surface as the shell's AppLibrary (sortedEntries/entryName/entrySubtext/iconSource/
//   refreshIcons/launch/remove + appsChanged) built directly on DesktopEntries. Used only when
//   shell.appLibrary is null: the host destroys a third-party plugin's API during startup
//   pruning and can later hand back the stale (null) app-library object.
//
// NEXT STEP (if not DONE):
//   none — verified 2026-09-20: Apps submenu lists 68 apps, Open runs gtk-launch. Uninstall not exercised.
// ============================================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "AppSearch.js" as AppSearch

Item {
  id: root
  visible: false

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var hiddenIds: ({})

  signal appsChanged()

  function normalizeId(id) {
    var value = String(id || "").trim()
    return value.slice(-8) === ".desktop" ? value.slice(0, -8) : value
  }

  function loadHides(rawText) {
    var lines = String(rawText || "").split(/\n/)
    var next = ({})
    for (var i = 0; i < lines.length; i++) {
      var id = root.normalizeId(lines[i])
      if (id.length > 0) next[id] = true
    }
    root.hiddenIds = next
    root.appsChanged()
  }

  function isHiddenEntry(entry) {
    return root.hiddenIds[String((entry && entry.id) || "")] === true
  }

  function entryName(entry) { return AppSearch.entryName(entry) }
  function entrySubtext(entry) { return AppSearch.entrySubtext(entry) }

  function sortedEntries(query) {
    var values = DesktopEntries.applications.values || []
    return AppSearch.sortedEntries(values, query, function(entry) { return root.isHiddenEntry(entry) })
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    var themed = Quickshell.iconPath(value, true)
    return themed.length > 0 ? themed : Quickshell.iconPath("application-x-executable", true)
  }

  function refreshIcons() {}

  function launch(desktopId, name) {
    var id = String(desktopId || "")
    if (!id) return
    // Same command the shell's AppLibrary runs; the .desktop suffix is required.
    Util.execDetached("uwsm-app -- gtk-launch " + Util.shellQuote(id + ".desktop"))
  }

  function remove(desktopId, name) {
    var id = String(desktopId || "")
    if (!id) return
    Util.execDetached(Util.shellQuote(root.omarchyPath + "/bin/omarchy-remove-launcher-entry") + " " + Util.shellQuote(id) + " " + Util.shellQuote(String(name || id)))
  }


  FileView {
    path: root.omarchyPath + "/default/omarchy/launcher.hides"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadHides(text())
    onFileChanged: root.loadHides(text())
    onLoadFailed: root.loadHides("")
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.appsChanged() }
  }
}
