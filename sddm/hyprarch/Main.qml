import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Item {
    id: root
    width:  Screen.width
    height: Screen.height

    property var   now:        new Date()
    property string loginError: ""

    Timer {
        interval: 1000
        running:  true
        repeat:   true
        onTriggered: root.now = new Date()
    }

    // ── BACKGROUND ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#0b0b0f"
    }

    Image {
        anchors.fill: parent
        source:       Qt.resolvedUrl(config.background)
        fillMode:     Image.PreserveAspectCrop
        smooth:       true
        asynchronous: true
    }

    // ── TOP-RIGHT: DATE + TIME ────────────────────────────────────────────────
    Column {
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   52
        anchors.rightMargin: 60
        spacing: 2

        Text {
            anchors.right: parent.right
            text:          Qt.formatDateTime(root.now, "dddd, MMMM d")
            font.pixelSize: 20
            font.family:    "JetBrains Mono"
            color:          Qt.rgba(1, 1, 1, 0.65)
        }

        Text {
            anchors.right: parent.right
            text:          Qt.formatDateTime(root.now, "hh:mm AP")
            font.pixelSize: 62
            font.bold:      true
            font.family:    "JetBrains Mono"
            color:          "white"

            layer.enabled: true
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset:   2
                radius:           16
                samples:          33
                color:            Qt.rgba(0, 0, 0, 0.55)
            }
        }
    }

    // ── LEFT: POWER BUTTONS ──────────────────────────────────────────────────
    Column {
        anchors.left:           parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin:     20
        spacing: 8

        // Power off
        Rectangle {
            width: 40; height: 40; radius: 10
            color: powerOffArea.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.40)
            border.color: Qt.rgba(1,1,1,0.10); border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 15
                color: Qt.rgba(1,1,1,0.70)
            }
            MouseArea {
                id: powerOffArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    sddm.powerOff()
            }
        }

        // Reboot
        Rectangle {
            width: 40; height: 40; radius: 10
            color: rebootArea.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.40)
            border.color: Qt.rgba(1,1,1,0.10); border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "↺"
                font.pixelSize: 17
                color: Qt.rgba(1,1,1,0.70)
            }
            MouseArea {
                id: rebootArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    sddm.reboot()
            }
        }

        // Suspend
        Rectangle {
            width: 40; height: 40; radius: 10
            color: suspendArea.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.40)
            border.color: Qt.rgba(1,1,1,0.10); border.width: 1
            visible: sddm.canSuspend
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "⏾"
                font.pixelSize: 15
                color: Qt.rgba(1,1,1,0.70)
            }
            MouseArea {
                id: suspendArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    sddm.suspend()
            }
        }
    }

    // ── LOWER-LEFT: LOGIN PANEL ───────────────────────────────────────────────
    Column {
        anchors.left:         parent.left
        anchors.bottom:       parent.bottom
        anchors.leftMargin:   72
        anchors.bottomMargin: 90
        spacing: 10

        // Avatar
        Rectangle {
            width: 88; height: 88; radius: 44
            color: Qt.rgba(0,0,0,0.30)
            border.color: Qt.rgba(1,1,1,0.25); border.width: 2
            clip: true
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: faceImage
                anchors.fill:    parent
                fillMode:        Image.PreserveAspectCrop
                smooth:          true
                source:          "file:///var/lib/AccountsService/icons/" + (userModel.lastUser || "")
                visible:         status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible:          faceImage.status !== Image.Ready
                text:             (userModel.lastUser || "?").charAt(0).toUpperCase()
                font.pixelSize:   36
                font.bold:        true
                font.family:      "JetBrains Mono"
                color:            Qt.rgba(1,1,1,0.75)
            }
        }

        // Username
        Rectangle {
            width: 220; height: 42; radius: 12
            color: Qt.rgba(0,0,0,0.40)
            border.color: Qt.rgba(1,1,1,0.12); border.width: 1

            Text {
                anchors.centerIn: parent
                text:          userModel.lastUser || ""
                font.pixelSize: 14
                font.family:    "JetBrains Mono"
                color:          Qt.rgba(1,1,1,0.85)
            }
        }

        // Password
        Rectangle {
            width: 220; height: 42; radius: 12
            color: Qt.rgba(0,0,0,0.40)
            border.color: passwordField.activeFocus ? Qt.rgba(1,1,1,0.50) : Qt.rgba(1,1,1,0.12)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            TextInput {
                id:              passwordField
                anchors.fill:    parent
                anchors.margins: 14
                echoMode:        TextInput.Password
                passwordCharacter: "●"
                color:           "white"
                font.pixelSize:  14
                font.family:     "JetBrains Mono"
                verticalAlignment: TextInput.AlignVCenter
                focus:           true

                Keys.onReturnPressed: doLogin()
                Keys.onEnterPressed:  doLogin()

                Text {
                    anchors.fill: parent
                    text:         "Password"
                    color:        Qt.rgba(1,1,1,0.30)
                    font.pixelSize: 14
                    font.family:    "JetBrains Mono"
                    verticalAlignment: Text.AlignVCenter
                    visible: passwordField.text.length === 0 && !passwordField.activeFocus
                }
            }
        }

        // Error
        Text {
            width:   220
            visible: root.loginError !== ""
            text:    root.loginError
            font.pixelSize: 11
            font.family:    "JetBrains Mono"
            color:          "#ff6b6b"
            horizontalAlignment: Text.AlignHCenter
        }

        // Login button
        Rectangle {
            width: 220; height: 42; radius: 12
            color: loginArea.pressed        ? Qt.rgba(1,1,1,0.28)
                 : loginArea.containsMouse  ? Qt.rgba(1,1,1,0.20)
                 :                            Qt.rgba(1,1,1,0.13)
            border.color: Qt.rgba(1,1,1,0.18); border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text:          "Login"
                font.pixelSize: 14
                font.family:    "JetBrains Mono"
                color:          "white"
            }

            MouseArea {
                id:           loginArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                onClicked:    doLogin()
            }
        }
    }

    // ── BOTTOM-LEFT: HOSTNAME ─────────────────────────────────────────────────
    Text {
        anchors.bottom:       parent.bottom
        anchors.left:         parent.left
        anchors.bottomMargin: 22
        anchors.leftMargin:   72
        text:          sddm.hostName
        font.pixelSize: 11
        font.family:    "JetBrains Mono"
        color:          Qt.rgba(1,1,1,0.25)
    }

    // ── BOTTOM-RIGHT: SESSION ────────────────────────────────────────────────
    Text {
        anchors.bottom:       parent.bottom
        anchors.right:        parent.right
        anchors.bottomMargin: 22
        anchors.rightMargin:  28
        text:          sessionCombo.currentText
        font.pixelSize: 11
        font.family:    "JetBrains Mono"
        color:          Qt.rgba(1,1,1,0.25)
    }

    ComboBox {
        id:      sessionCombo
        model:   sessionModel
        textRole: "name"
        width:   0; height: 0; visible: false

        // Default to Hyprland if found, otherwise last used
        Component.onCompleted: {
            var hypr = -1
            for (var i = 0; i < sessionModel.rowCount(); i++) {
                var name = sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || ""
                if (name.toLowerCase().indexOf("hyprland") !== -1) { hypr = i; break }
            }
            currentIndex = (hypr !== -1) ? hypr : sessionModel.lastIndex
        }
    }

    // ── LOGIN LOGIC ──────────────────────────────────────────────────────────
    function doLogin() {
        root.loginError = ""
        sddm.login(userModel.lastUser, passwordField.text, sessionCombo.currentIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loginError = "Wrong password"
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }
}
