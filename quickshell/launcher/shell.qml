import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    PanelWindow {
        id: win
        visible: false
        implicitWidth: 560
        implicitHeight: 420
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        
        Keys.onEscapePressed: win.visible = false

        anchors { top: true }
        margins.top: 200

        // ---- palette (match your bar) ----
        readonly property color cBase:    "#1e1e2e"
        readonly property color cSurface: "#313244"
        readonly property color cOverlay: "#45475a"
        readonly property color cText:    "#cdd6f4"
        readonly property color cSubtext: "#a6adc8"
        readonly property color cMauve:   "#cba6f7"

        // ---- IPC toggle handler (Hyprland keybind calls this) ----
        IpcHandler {
            target: "launcher"
            function toggle(): void {
                win.visible = !win.visible
                if (win.visible) {
                    searchField.text = ""
                    searchField.forceActiveFocus()
                    appList.currentIndex = 0
                    win.reloadApps()
                }
            }
        }

        // ---- app model ----
        ListModel { id: appModel }
        ListModel { id: filteredModel }

        function reloadApps() {
            appScan.running = true
        }

        Process {
            id: appScan
            command: ["sh", "-c",
                "for f in /usr/share/applications/*.desktop ~/.local/share/applications/*.desktop; do " +
                "[ -f \"$f\" ] && echo \"===\" && cat \"$f\"; done"]
            running: false

            property string buffer: ""

            stdout: SplitParser {
                onRead: line => appScan.buffer += line + "\n"
            }

            onRunningChanged: if (running) buffer = ""

            onExited: {
                const blocks = appScan.buffer.split("===\n").filter(b => b.trim().length > 0)
                appModel.clear()
                const seen = new Set()

                for (const block of blocks) {
                    const lines = block.split("\n")
                    let name = "", exec = "", icon = "", noDisplay = false, isApp = true

                    for (const l of lines) {
                        if (l.startsWith("Name=") && !name) name = l.slice(5)
                        else if (l.startsWith("Exec=") && !exec) exec = l.slice(5)
                        else if (l.startsWith("Icon=") && !icon) icon = l.slice(5)
                        else if (l.startsWith("NoDisplay=true")) noDisplay = true
                        else if (l.startsWith("Type=") && !l.includes("Application")) isApp = false
                    }

                    if (!name || !exec || noDisplay || !isApp || seen.has(name)) continue
                    seen.add(name)

                    // strip desktop-file field codes like %U %f etc.
                    exec = exec.replace(/%[a-zA-Z]/g, "").trim()

                    appModel.append({ name: name, exec: exec, icon: icon })
                }
                win.filterApps()
            }
        }

        Process {
            id: launchProc
            running: false
        }

        property var recentApps: []  // list of exec strings, most recent first

        function fuzzyScore(query, text) {
            query = query.toLowerCase()
            text = text.toLowerCase()
            if (text.includes(query)) return 100 - text.indexOf(query)  // substring = strong match

            // simple fuzzy: all query chars appear in order in text
            let qi = 0
            for (let i = 0; i < text.length && qi < query.length; i++) {
                if (text[i] === query[qi]) qi++
            }
            return qi === query.length ? 10 : -1  // matched all chars, weak score
        }

        function filterApps() {
            const q = searchField.text
            filteredModel.clear()

            if (q === "") {
                // empty search: show recent apps first, then the rest alphabetically
                const recentSet = new Set(win.recentApps)
                const recent = []
                const rest = []
                for (let i = 0; i < appModel.count; i++) {
                    const item = appModel.get(i)
                    if (recentSet.has(item.exec)) recent.push(item)
                    else rest.push(item)
                }
                recent.sort((a, b) => win.recentApps.indexOf(a.exec) - win.recentApps.indexOf(b.exec))
                rest.sort((a, b) => a.name.localeCompare(b.name))
                for (const item of recent.concat(rest)) filteredModel.append(item)
            } else {
                const scored = []
                for (let i = 0; i < appModel.count; i++) {
                    const item = appModel.get(i)
                    const score = fuzzyScore(q, item.name)
                    if (score >= 0) scored.push({ item: item, score: score })
                }
                scored.sort((a, b) => b.score - a.score)
                for (const s of scored) filteredModel.append(s.item)
            }

            appList.currentIndex = filteredModel.count > 0 ? 0 : -1
        }

        function launchSelected() {
            if (appList.currentIndex < 0) return
            const item = filteredModel.get(appList.currentIndex)
            launchProc.command = ["sh", "-c", item.exec + " &"]
            launchProc.running = true

            win.recentApps = [item.exec].concat(win.recentApps.filter(e => e !==item.exec)).slice(0, 8);
            win.visible = false
        }

        // ---- UI ----
        Rectangle {
            anchors.fill: parent
            radius: 14
            color: win.cBase
            border.width: 1
            border.color: win.cOverlay

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 10
                    color: win.cSurface

                    TextField {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 4
                        placeholderText: "Search apps…"
                        color: win.cText
                        placeholderTextColor: win.cSubtext
                        font.pixelSize: 15
                        font.family: "JetBrainsMono Nerd Font"
                        background: null

                        onTextChanged: win.filterApps()

                        Keys.onDownPressed: appList.incrementCurrentIndex()
                        Keys.onUpPressed: appList.decrementCurrentIndex()
                        Keys.onReturnPressed: win.launchSelected()
                        Keys.onEscapePressed: win.visible = false
                    }
                }

                ListView {
                    id: appList
                    width: parent.width
                    height: parent.height - 52
                    clip: true
                    model: filteredModel
                    spacing: 2
                    highlightMoveDuration: 80

                    delegate: Rectangle {
                        width: appList.width
                        height: 44
                        radius: 8
                        color: index === appList.currentIndex ? win.cMauve : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Image {
                                width: 26; height: 26
                                source: model.icon ? Quickshell.iconPath(model.icon, true) : ""
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: model.name
                                color: index === appList.currentIndex ? win.cBase : win.cText
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: { appList.currentIndex = index; win.launchSelected() }
                        }
                    }
                }
            }
        }
    }
}