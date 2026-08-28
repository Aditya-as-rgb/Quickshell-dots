import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick

ShellRoot {
    PanelWindow {
        id: panel
        anchors { top: true; left: true; right: true }
        implicitHeight: 38
        color: "transparent" 

        // ---- Catppuccin Mocha palette ----
        readonly property color cCrust:    "#11111b"
        readonly property color cMantle:   "#181825"
        readonly property color cBase:     "#1e1e2e"
        readonly property color cSurface:  "#313244"
        readonly property color cOverlay:  "#45475a"
        readonly property color cText:      "#cdd6f4"
        readonly property color cSubtext:  "#a6adc8"
        readonly property color cBlue:      "#89b4fa"
        readonly property color cGreen:     "#a6e3a1"
        readonly property color cRed:      "#f38ba8"
        readonly property color cYellow:    "#f9e2af"
        readonly property color cMauve:    "#cba6f7"
        readonly property color cPeach:    "#fab387"
        readonly property color cTeal:     "#94e2d5"

        // wifi state lives here so we can reset it cleanly between runs
        property string wifiSsid: "off"
        property int    wifiSignal: 0

        SystemClock { id: clock; precision: SystemClock.Seconds }
        PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

        // ---- wifi status polling ----
        Process {
            id: wifiProc
            // --rescan no avoids the scan delay/permission issue
            command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi", "list", "--rescan", "no"]
            running: true

            stdout: SplitParser {
                // each `line` is already a single line — no need to split again
                onRead: line => {
                    if (line.startsWith("yes:")) {
                        const parts = line.split(":")
                        panel.wifiSsid = parts[1] || "hidden"
                        panel.wifiSignal = parseInt(parts[2]) || 0
                    }
                    // ignore "no:" lines — they no longer clobber the active SSID
                }
            }
        }

        Timer {
            interval: 10000
            running: true
            repeat: true
            onTriggered: {
                // reset before re-scan; if wifi went down, this surfaces it
                panel.wifiSsid = "off"
                panel.wifiSignal = 0
                // toggle to actually restart a finished process
                wifiProc.running = false
                wifiProc.running = true
            }
        }

        // ---- wifi network scan (on-demand, for the popup) ----
        Process {
            id: wifiListProc
            command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
            running: false

            property string buffer: ""

            stdout: SplitParser {
                onRead: line => {
                    if (line.trim() === "") return
                    wifiListProc.buffer += line + "\n"
                }
            }

            onRunningChanged: {
                if (running) buffer = ""
            }

            onExited: {
                const lines = buffer.trim().split("\n").filter(l => l.length > 0)
                const seen = new Set()
                const nets = []
                for (const l of lines) {
                    const parts = l.split(":")
                    const ssid = parts[0]
                    if (!ssid || seen.has(ssid)) continue
                    seen.add(ssid)
                    nets.push({ ssid: ssid, signal: parts[1], secure: parts[2] !== "" })
                }
                networkModel.clear()
                for (const n of nets) networkModel.append(n)
            }
        }

        ListModel { id: networkModel }

        Process {
            id: wifiConnectProc
            running: false
        }

        PopupWindow {
            id: wifiPopup
            visible: false
            anchor.window: panel
            anchor.rect.x: panel.width - 260
            anchor.rect.y: 38
            implicitWidth: 240
            implicitHeight: Math.min(300, networkModel.count * 36 + 16)
            color: panel.cMantle

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Repeater {
                    model: networkModel

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: 6
                        color: netMouse.containsMouse ? panel.cSurface : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: model.secure ? "󰌾" : "󰖩"
                                color: panel.cSubtext
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: model.ssid + " (" + model.signal + "%)"
                                color: panel.cText
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                wifiConnectProc.command = ["nmcli", "dev", "wifi", "connect", model.ssid]
                                wifiConnectProc.running = true
                                wifiPopup.visible = false
                            }
                        }
                    }
                }
            }
        }

        // ================== LEFT ==================
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // workspaces
            Row {
                spacing: 4
                Repeater {
                    model: Hyprland.workspaces.values.filter(w => w.id > 0)
                    Rectangle {
                        width: 26; height: 26; radius: 7
                        color: modelData.active ? panel.cMauve : panel.cSurface
                        border.width: modelData.active ? 0 : 1
                        border.color: panel.cOverlay

                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            color: modelData.active ? panel.cBase : panel.cText
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 18; color: panel.cOverlay; anchors.verticalCenter: parent.verticalCenter }

            // active window
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Hyprland.activeToplevel?.title ?? "—"
                color: Qt.rgba(238, 238, 238, 0.8)
                font.pixelSize: 13
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
                width: 360
            }
        }

        // ================== CENTER ==================
        Rectangle {
            anchors.centerIn: parent
            width: clockRow.width + 28
            height: 28
            radius: 14
            color: panel.cSurface

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰥔"
                    color: panel.cMauve
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "hh:mm:ss")
                    color: panel.cText
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ================== RIGHT ==================
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // system tray
            Row {
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: SystemTray.items
                    Rectangle {
                        width: 26; height: 26; radius: 7
                        color: panel.cSurface
                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }
                        MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
                    }
                }
            }

            // volume
            Rectangle {
                width: volRow.width + 20; height: 26; radius: 13
                color: panel.cSurface
                Row {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: Pipewire.defaultAudioSink?.audio?.muted ? "󰸈" : "󰕾"
                        color: panel.cBlue
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Pipewire.defaultAudioSink?.audio?.muted
                            ? "muted"
                            : Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                        color: panel.cText
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (Pipewire.defaultAudioSink?.audio)
                            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                    }
                }
            }

            // battery
            Rectangle {
                visible: UPower.displayDevice?.isPresent ?? false
                width: batRow.width + 20; height: 26; radius: 13
                color: panel.cSurface
                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: {
                            const pct = (UPower.displayDevice?.percentage ?? 0) * 100
                            const charging = UPower.displayDevice?.state === UPowerDeviceState.Charging
                            if (charging) return "󰂄"
                            if (pct >= 90) return "󰁹"
                            if (pct >= 70) return "󰂀"
                            if (pct >= 50) return "󰁾"
                            if (pct >= 30) return "󰁼"
                            if (pct >= 10) return "󰁺"
                            return "󰂃"
                        }
                        color: panel.cGreen
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "%"
                        color: (UPower.displayDevice?.percentage ?? 1) < 0.2 ? panel.cRed : panel.cText
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // wifi
            Rectangle {
                width: wifiRow.width + 20; height: 26; radius: 13
                color: panel.cSurface
                Row {
                    id: wifiRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: panel.wifiSsid === "off" ? "󰖭" : "󰖩"
                        color: panel.wifiSsid === "off" ? panel.cSubtext : panel.cGreen
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: panel.wifiSsid === "off"
                              ? "off"
                              : panel.wifiSsid + " " + panel.wifiSignal + "%"
                        color: panel.cText
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        wifiPopup.visible = !wifiPopup.visible
                        if (wifiPopup.visible) wifiListProc.running = true
                    }
                }
            }

            // date
            Rectangle {
                width: dateRow.width + 20; height: 26; radius: 13
                color: panel.cSurface
                Row {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰃭"
                        color: panel.cPeach
                        font.pixelSize: 14
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: Qt.formatDateTime(clock.date, "ddd MMM d")
                        color: panel.cText
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
