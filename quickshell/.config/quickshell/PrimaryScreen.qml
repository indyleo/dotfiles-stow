pragma Singleton
import QtQuick
import Quickshell

// Single source of truth for "which screen is the primary one".
// Every picker / OSD / popup uses `PrimaryScreen.screen` instead of
// hardcoding `Quickshell.screens[0]`, and the bar's `isPrimary` check
// uses `PrimaryScreen.isPrimary(modelData)` too.
//
// To re-target everything at once, change `preferredName`:
//   ""            -> fall back to Quickshell.screens[0] (default)
//   "DP-1"        -> use the screen named DP-1, if present
//   "HDMI-A-1"    -> use the screen named HDMI-A-1, if present
//   "1"           -> use Quickshell.screens[1] by index
QtObject {
    property string preferredName: "DP-1"

    readonly property var screen: {
        var screens = Quickshell.screens;
        if (!screens || screens.length === 0)
            return null;

        if (preferredName !== "") {
            // Match by name first
            for (var i = 0; i < screens.length; i++) {
                if (screens[i].name === preferredName)
                    return screens[i];
            }
            // Then by index (numeric string)
            var idx = parseInt(preferredName, 10);
            if (!isNaN(idx) && idx >= 0 && idx < screens.length)
                return screens[idx];
            console.warn("[PrimaryScreen] No screen matching '" + preferredName + "', falling back to screens[0]");
        }

        return screens[0];
    }

    function isPrimary(s) {
        return s != null && s === screen;
    }
}
