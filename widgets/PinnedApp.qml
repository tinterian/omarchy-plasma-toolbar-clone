import QtQuick
import Quickshell
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

  readonly property var appLibrary: root.bar && root.bar.shell ? root.bar.shell.appLibrary : null
  readonly property string resolvedIconSource: {
    if (iconPath.length > 0) return iconPath.charAt(0) === "/" ? Util.fileUrl(iconPath) : iconPath
    if (appId.length > 0 && appLibrary) return appLibrary.iconSource(appId)
    return ""
  }

  visible: command.length > 0 || appId.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function launch() {
    if (command.length > 0) Util.execDetached(command)
    else if (appId.length > 0 && appLibrary) appLibrary.launch(appId, root.label)
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
    onPressed: function(b) { if (b === Qt.LeftButton) root.launch() }
  }
}
