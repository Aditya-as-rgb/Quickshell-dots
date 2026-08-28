import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

ShellRoot {
    NotificationServer {
        id: notifServer
        onNotification: notif => {
            notif.tracked = true
            popupModel.append({
                notifId: notif.id,
                summary: notif.summary,
                body: notif.body,
                appName: notif.appName,
                urgency: notif.urgency
            })

            dismissTimer.createObject(null, { notifId: notif.id }).start()
        }
    }

    ListModel { id: popupModel }

    Component {
        id: dismissTimer
        Timer {
            property int notifId
            interval: 5000
            running: false
            onTriggered: {
                for (let i = 0; i < popupModel.count; i++) {
                    if (popupModel.get(i).notifId === notifId) {
                        popupModel.remove(i)
                        break
                    }
                }
                destroy()
            }
        }
    }

    PanelWindow {
        id: win
        color: "transparent"
        anchors { bottom: true; right: true }
        margins.bottom: 16
        margins.right: 16

        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: 340
        implicitHeight: popupColumn.height

        readonly property color cBase:    "#1e1e2e"
        readonly property color cSurface: "#313244"
        readonly property color cOverlay: "#45475a"
        readonly property color cText:    "#cdd6f4"
        readonly property color cSubtext: "#a6adc8"
        readonly property color cMauve:   "#cba6f7"
        readonly property color cRed:     "#f38ba8"

        Column {
            id: popupColumn
            width: parent.width
            spacing: 8

            Repeater {
                model: popupModel

                Rectangle {
                    width: popupColumn.width
                    height: contentCol.height + 24
                    radius: 12
                    color: Qt.rgba(0.12, 0.12, 0.18, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1) ? win.cRed : win.cOverlay

                    Column {
                        id: contentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            text: model.appName
                            color: win.cMauve
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text: model.summary
                            color: win.cText
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                        Text {
                            visible: model.body.length > 0
                            text: model.body
                            color: win.cSubtext
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            for (let i = 0; i < popupModel.count; i++) {
                                if (popupModel.get(i).notifId === model.notifId) {
                                    popupModel.remove(i)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}