import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

ShellRoot {
    PanelWindow {
        id: win
        visible: false
        color: "transparent"

        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        anchors { top: true; bottom: true; left: true; right: true }

        readonly property color cBase:    "#1e1e2e"
        readonly property color cSurface: "#313244"
        readonly property color cOverlay: "#45475a"
        readonly property color cText:    "#cdd6f4"
        readonly property color cSubtext: "#a6adc8"
        readonly property color cMauve:   "#cba6f7"

        readonly property string wallDir: "/home/aditya/Pictures/Wallpapers"

        IpcHandler {
            target: "wallpaper"
            function toggle(): void {
                win.visible = !win.visible
                if (win.visible) {
                    searchField.text = ""
                    win.reloadWalls()
                }
            }
        }

        ListModel { id: wallModel }
        ListModel { id: filteredModel }

        Process {
            id: scanProc
            command: ["sh", "-c", "ls -1 " + win.wallDir + " 2>/dev/null"]
            running: false

            property string buffer: ""

            stdout: SplitParser {
                onRead: line => {
                    if (line.trim().length > 0) scanProc.buffer += line + "\n"
                }
            }

            onRunningChanged: if (running) buffer = ""

            onExited: {
                wallModel.clear()
                const files = scanProc.buffer.trim().split("\n").filter(f => f.length > 0)
                for (const f of files) {
                    wallModel.append({ fileName: f, path: win.wallDir + "/" + f })
                }
                win.filterWalls()
            }
        }

        function reloadWalls() {
            scanProc.running = true
        }

        function filterWalls() {
            const q = searchField.text.toLowerCase()
            filteredModel.clear()
            for (let i = 0; i < wallModel.count; i++) {
                const item = wallModel.get(i)
                if (q === "" || item.fileName.toLowerCase().includes(q)) {
                    filteredModel.append(item)
                }
            }
            grid.currentIndex = filteredModel.count > 0 ? 0 : -1
        }

        Process {
            id: setWallProc
            running: false
        }

        function setWallpaper(path) {
            setWallProc.command = ["sh", "-c",
                "swww img '" + path + "' --transition-type grow --transition-duration 1 --transition-fps 60"]
            setWallProc.running = true
        }

        FocusScope {
            anchors.centerIn: parent
            width: 900
            height: 320
            focus: true
            Keys.onEscapePressed: win.visible = false

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: win.cBase
                border.width: 1
                border.color: win.cOverlay

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Text {
                        text: "Choose Wallpaper"
                        color: win.cText
                        font.pixelSize: 18
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Rectangle {
                        width: parent.width
                        height: 44
                        radius: 10
                        color: win.cSurface

                        TextField {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: 4
                            placeholderText: "Search wallpapers…"
                            color: win.cText
                            placeholderTextColor: win.cSubtext
                            font.pixelSize: 15
                            font.family: "JetBrainsMono Nerd Font"
                            background: null

                            onTextChanged: win.filterWalls()

                            Keys.onDownPressed: grid.moveCurrentIndexDown()
                            Keys.onUpPressed: grid.moveCurrentIndexUp()
                            Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                            Keys.onRightPressed: grid.moveCurrentIndexRight()
                            Keys.onReturnPressed: {
                                const item = filteredModel.get(grid.currentIndex)
                                if (item) {
                                    win.setWallpaper(item.path)
                                    win.visible = false
                                }
                            }
                            Keys.onEscapePressed: win.visible = false
                        }
                    }

                    GridView {
                        id: grid
                        width: parent.width
                        height: parent.height - 44 - 42 - 28
                        clip: true
                        cellWidth: 210
                        cellHeight: parent.height - 44 - 42 - 28 
                        model: filteredModel

                        delegate: Rectangle {
                            width: 200
                            height: grid.cellHeight - 10
                            radius: 10
                            color: win.cSurface
                            border.width: (mouseArea.containsMouse || GridView.isCurrentItem) ? 3 : 0
                            border.color: win.cMauve

                            Image {
                                anchors.fill: parent
                                anchors.margins: 4
                                source: "file://" + model.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                layer.enabled: true
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    grid.currentIndex = index
                                    win.setWallpaper(model.path)
                                    win.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}