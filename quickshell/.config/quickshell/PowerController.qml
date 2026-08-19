import QtQuick
import Quickshell.Io

Item {
    id: root

    Process {
        id: pwrProc
        onExited: (code, status) => {
            // optional: show error if non‑zero exit
            if (code !== 0) {
                console.warn("Power action failed with exit code", code)
            }
        }
    }

    function run(cmd) {
        pwrProc.command = cmd
        pwrProc.running = false
        pwrProc.running = true
    }

    function lock()      { run(["loginctl", "lock-session"]) }
    function suspend()   { run(["systemctl", "suspend"]) }
    function hibernate() { run(["systemctl", "hibernate"]) }
    function reboot()    { run(["systemctl", "reboot"]) }
    function shutdown()  { run(["systemctl", "poweroff"]) }
    function logout()    { run(["hyprctl", "dispatch", "exit"]) }
}
