pragma Singleton
import QtQuick

// Central theme singleton. Every other .qml file in this directory can
// reference "Theme.xxx" directly with no import statement needed, since
// Quickshell/QML resolves singletons declared in qmldir automatically for
// files in the same folder.
//
// To re-theme the whole shell, edit the values in this file only.
QtObject {
    id: theme

    // ---- Gruvbox Dark palette -------------------------------------
    // Kept as the original cal0..cal15 names so existing code/usages
    // that reference these names read the same way they always have.
    readonly property color cal0:  "#282828"
    readonly property color cal1:  "#3c3836"
    readonly property color cal2:  "#504945"
    readonly property color cal3:  "#7c6f64"
    readonly property color cal4:  "#a89984"
    readonly property color cal5:  "#d5c4a1"
    readonly property color cal6:  "#ebdbb2"
    readonly property color cal7:  "#83a598"
    readonly property color cal8:  "#fb4934"
    readonly property color cal9:  "#d3869b"
    readonly property color cal10: "#fabd2f"
    readonly property color cal11: "#cc241d"
    readonly property color cal12: "#458588"
    readonly property color cal13: "#b8bb26"
    readonly property color cal14: "#fe8019"
    readonly property color cal15: "#bdae93"

    // ---- Semantic aliases -------------------------------------------
    // Prefer these names in new/refactored code - they describe *role*
    // rather than palette index, so swapping the color scheme later
    // doesn't require re-reading every usage site to know what it meant.
    readonly property color background: cal0
    readonly property color surface: cal1
    readonly property color surfaceAlt: cal2
    readonly property color border: cal3
    readonly property color textMuted: cal4
    readonly property color textSubtle: cal5
    readonly property color text: cal6
    readonly property color info: cal7
    readonly property color danger: cal8
    readonly property color magenta: cal9
    readonly property color warning: cal10
    readonly property color dangerAlt: cal11
    readonly property color blue: cal12
    readonly property color success: cal13
    readonly property color accent: cal14
    readonly property color textAlt: cal15

    // Common derived/composite colors used by multiple components
    readonly property color osdBgColor: Qt.rgba(surface.r, surface.g, surface.b, 0.85)
    readonly property color overlayDim: "#000000AA"

    // Shared defaults for the ad-hoc Rectangle+MouseArea "buttons" and
    // dropdown popups used throughout the shell (PowerButton, pickers,
    // menus, etc). Components still expose their own color properties so
    // individual instances can override these, but the default now comes
    // from one place.
    readonly property color buttonBg: surfaceAlt
    readonly property color buttonHoverBg: border
    readonly property color buttonIcon: accent
    readonly property color buttonText: text

    readonly property color dropdownBg: background
    readonly property color dropdownBorder: border
    readonly property color dropdownItemHoverBg: surfaceAlt

    // ---- Typography ---------------------------------------------------
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 13
}
