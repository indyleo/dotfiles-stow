import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Generic process for one-shot power actions (suspend, hibernate,
    // reboot, shutdown, logout). Previously a failure only logged to the
    // console - since the power menu closes immediately on click, the user
    // had no way to know an action silently failed. notify-send routes
    // through the desktop notification protocol, which this same shell's
    // NotificationController implements, so the error surfaces as a normal
    // notification popup rather than disappearing into a log file.
    Process {
        id: pwrProc
        property string actionLabel: "Power action"
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[PowerController]", pwrProc.actionLabel, "failed with exit code", code, pwrProc.stderr.text)
                root.notifyFailure(pwrProc.actionLabel)
            }
        }
    }

    Process { id: notifyProc }

    function notifyFailure(action) {
        notifyProc.command = ["notify-send", "-u", "critical", "-a", "Power Menu",
            action + " failed", "Check the logs for details."]
        notifyProc.running = false
        notifyProc.running = true
    }

    function run(cmd, label) {
        pwrProc.actionLabel = label
        pwrProc.command = cmd
        pwrProc.running = false
        pwrProc.running = true
    }

    // loginctl lock-session depends on logind session tracking, which isn't
    // guaranteed to be wired up correctly on every compositor/setup. Falls
    // back to launching hyprlock directly if it fails. hyprlock blocks until
    // the session is unlocked, so it's launched detached (fire-and-forget)
    // rather than tracked by a Process here.
    Process {
        id: lockProc
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("[PowerController] loginctl lock-session failed, trying hyprlock fallback:", code, lockProc.stderr.text)
                Quickshell.execDetached({ command: ["hyprlock"] })
            }
        }
    }

    function lock() {
        lockProc.command = ["loginctl", "lock-session"]
        lockProc.running = false
        lockProc.running = true
    }

    function suspend()   { run(["systemctl", "suspend"], "Suspend") }
    function hibernate() { run(["systemctl", "hibernate"], "Hibernate") }
    function reboot()    { run(["systemctl", "reboot"], "Reboot") }
    function shutdown()  { run(["systemctl", "poweroff"], "Shutdown") }
    function logout()    { run(["hyprctl", "dispatch", "exit"], "Logout") }
}