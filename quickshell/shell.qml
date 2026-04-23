import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 50
    exclusionMode: ExclusionMode.Auto
    color: "transparent"

    property int activeWorkspace: 1
    property var occupiedWorkspaces: []
    property string volumePercent: "0%"
    property bool isMuted: false
    property bool discordRunning: false
    property bool musicRunning: false
    property bool codeRunning: false
    property bool githubRunning: false
    property bool steamRunning: false
    property bool soberRunning: false

    // Lyrics easter egg state
    property bool lyricsOpen: false
    property var lyricsLines: []
    property int lyricsIdx: -1
    property string lyricsCurrentLine: ""
    property string trackKey: ""
    property double trackWallBase: 0   // Date.now() snapshot when trackPosBase was set
    property double trackPosBase: 0    // playback position in seconds at trackWallBase
    property bool trackPlaying: false

    // Rotating quotes list — cycles through instead of random shuf
    property var quotes: [
        "I use Arch btw",
        "404 motivation not found",
        "works on my machine",
        "git blame yourself",
        "it's not a bug, it's a feature",
        "have you tried turning it off and on again",
        "sudo make me a sandwich",
        "there are 2 types of people",
        "still compiling...",
        "segmentation fault (core dumped)",
        "why is it always DNS",
        "to be or not to be",
        "technically correct is the best kind of correct",
        "rm -rf node_modules",
        "it works on my machine → ship the machine",
        "coffee.exe has stopped responding",
        "undefined is not a function",
        "have you met my friend NaN",
        "while (alive) { eat(); sleep(); code(); }",
        "0 bugs found... in my opinion"
    ]
    property int quoteIndex: 0
    property string currentQuote: quotes[0]

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            quoteIndex = (quoteIndex + 1) % root.quotes.length
            root.currentQuote = root.quotes[quoteIndex]
        }
    }

    // VOLUME — event driven via pactl subscribe
    Process {
        id: volFetcher
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                isMuted = data.indexOf("[MUTED]") !== -1
                let val = data.match(/[0-9.]+/)
                if (val) volumePercent = Math.round(parseFloat(val[0]) * 100) + "%"
            }
        }
        onRunningChanged: {
            if (!running) volTimer.running = true
        }
    }
    Timer {
        id: volTimer
        interval: 100
        repeat: false
        onTriggered: volFetcher.running = true
    }

    // Volume change watcher — triggers fetch on any audio event
    Process {
        id: volWatcher
        command: ["sh", "-c", "pactl subscribe 2>/dev/null | grep --line-buffered \"sink\""]
        running: true
        stdout: SplitParser {
            onRead: (_) => {
                volFetcher.running = false
                volFetcher.running = true
            }
        }
        onRunningChanged: {
            if (!running) {
                volWatcherRestartTimer.running = true
            }
        }
    }
    Timer {
        id: volWatcherRestartTimer
        interval: 1000
        repeat: false
        onTriggered: volWatcher.running = true
    }

    // WORKSPACES — single-line output so SplitParser fires once: "activeId:id1,id2,..."
    Process {
        id: hyprFetcher
        command: ["sh", "-c",
            "printf '%d:%s\\n' " +
            "\"$(hyprctl activeworkspace -j | jq '.id')\" " +
            "\"$(hyprctl workspaces -j | jq -r '[.[].id] | join(\",\")')\""]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                let parts = data.trim().split(":")
                if (parts.length < 2) return
                activeWorkspace = parseInt(parts[0])
                occupiedWorkspaces = parts[1].split(",").map(id => parseInt(id)).filter(n => !isNaN(n))
            }
        }
        onRunningChanged: {
            if (!running) hyprTimer.running = true
        }
    }
    Timer {
        id: hyprTimer
        interval: 200
        repeat: false
        onTriggered: hyprFetcher.running = true
    }

    // APP CHECKER — fixed Discord Flatpak false positive
    Process {
        id: appChecker
        command: ["sh", "-c",
            "pgrep -f '/app/discord/Discord$' > /dev/null 2>&1 && echo 'D_ON' || echo 'D_OFF'; " +
            "pgrep -xi 'spotify|amberol' > /dev/null 2>&1 && echo 'M_ON' || echo 'M_OFF'; " +
            "pgrep -xi 'code|vscodium|zed' > /dev/null 2>&1 && echo 'C_ON' || echo 'C_OFF'; " +
            "pgrep -xi 'github-desktop' > /dev/null 2>&1 && echo 'G_ON' || echo 'G_OFF'; " +
            "pgrep -xi 'steam|lutris' > /dev/null 2>&1 && echo 'X_ON' || echo 'X_OFF'; " +
            "pgrep -xi 'sober' > /dev/null 2>&1 && echo 'S_ON' || echo 'S_OFF'"
        ]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                if (data.indexOf("D_ON") !== -1) discordRunning = true
                else if (data.indexOf("D_OFF") !== -1) discordRunning = false
                if (data.indexOf("M_ON") !== -1) musicRunning = true
                else if (data.indexOf("M_OFF") !== -1) { musicRunning = false; lyricsOpen = false }
                if (data.indexOf("C_ON") !== -1) codeRunning = true
                else if (data.indexOf("C_OFF") !== -1) codeRunning = false
                if (data.indexOf("G_ON") !== -1) githubRunning = true
                else if (data.indexOf("G_OFF") !== -1) githubRunning = false
                if (data.indexOf("X_ON") !== -1) steamRunning = true
                else if (data.indexOf("X_OFF") !== -1) steamRunning = false
                if (data.indexOf("S_ON") !== -1) soberRunning = true
                else if (data.indexOf("S_OFF") !== -1) soberRunning = false
            }
        }
        onRunningChanged: {
            if (!running) appTimer.running = true
        }
    }
    Timer {
        id: appTimer
        interval: 1000
        repeat: false
        onTriggered: appChecker.running = true
    }

    // METADATA WATCHER — triggers lyrics fetch on track change
    Process {
        id: metaWatcher
        command: ["playerctl", "--follow", "metadata", "--format",
                  "{{artist}}|{{title}}|{{mpris:length}}"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                let key = data.trim()
                if (key === root.trackKey) return
                root.trackKey = key
                root.lyricsLines = []
                root.lyricsIdx = -1
                root.lyricsCurrentLine = ""
                root.trackPosBase = 0
                root.trackWallBase = Date.now()
                root.trackPlaying = true
                // Sync real position — overrides the 0 estimate once playerctl responds
                posQueryer.running = false
                posQueryer.running = true
                let parts = key.split("|")
                if (parts.length >= 2 && parts[0] !== "" && parts[1] !== "") {
                    lyricsFetcher.command = [
                        "python3",
                        "/home/arch/.config/scripts/lyrics-fetch.py",
                        parts[0], parts[1],
                        parts.length >= 3 ? parts[2] : "0"
                    ]
                    lyricsFetcher.running = false
                    lyricsFetcher.running = true
                }
            }
        }
        onRunningChanged: {
            if (!running) metaRestartTimer.running = true
        }
    }
    Timer {
        id: metaRestartTimer
        interval: 3000
        repeat: false
        onTriggered: metaWatcher.running = true
    }

    // LYRICS FETCHER — calls lyrics-fetch.py, fills lyricsLines array
    Process {
        id: lyricsFetcher
        command: ["echo", ""]
        stdout: SplitParser {
            onRead: (data) => {
                let pipe = data.indexOf("|")
                if (pipe < 0) return
                let t = parseFloat(data.substring(0, pipe))
                let txt = data.substring(pipe + 1).trim()
                if (!isNaN(t) && txt.length > 0)
                    root.lyricsLines = root.lyricsLines.concat([{time: t, text: txt}])
            }
        }
    }

    // STATUS WATCHER — tracks play/pause so wall-clock position stays accurate
    Process {
        id: statusWatcher
        command: ["playerctl", "--follow", "status"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                let s = data.trim()
                if (s === "Playing" && !root.trackPlaying) {
                    root.trackWallBase = Date.now()
                    root.trackPlaying = true
                    // Re-sync position — user may have seeked while paused
                    posQueryer.running = false
                    posQueryer.running = true
                } else if (s !== "Playing" && root.trackPlaying) {
                    root.trackPosBase += (Date.now() - root.trackWallBase) / 1000
                    root.trackWallBase = Date.now()
                    root.trackPlaying = false
                }
            }
        }
        onRunningChanged: {
            if (!running) statusRestartTimer.running = true
        }
    }
    Timer {
        id: statusRestartTimer
        interval: 2000
        repeat: false
        onTriggered: statusWatcher.running = true
    }

    // POSITION SYNC — gets real playerctl position to correct wall-clock drift from seeks
    Process {
        id: posQueryer
        command: ["playerctl", "position"]
        stdout: SplitParser {
            onRead: (data) => {
                let pos = parseFloat(data.trim())
                if (!isNaN(pos) && pos >= 0) {
                    root.trackPosBase = pos
                    root.trackWallBase = Date.now()
                }
            }
        }
    }
    Timer {
        id: posResyncTimer
        interval: 2500
        repeat: true
        running: root.musicRunning && root.trackPlaying
        onTriggered: {
            posQueryer.running = false
            posQueryer.running = true
        }
    }

    // POSITION TIMER — pure wall-clock arithmetic, no process spawning
    Timer {
        id: posTimer
        interval: 300
        repeat: true
        running: true
        onTriggered: {
            if (root.lyricsLines.length === 0 || !root.trackPlaying) return
            let pos = root.trackPosBase + (Date.now() - root.trackWallBase) / 1000
            let idx = -1
            for (let i = 0; i < root.lyricsLines.length; i++) {
                if (root.lyricsLines[i].time <= pos + 0.2) idx = i
                else break
            }
            if (idx !== root.lyricsIdx) {
                root.lyricsIdx = idx
                root.lyricsCurrentLine = idx >= 0 ? root.lyricsLines[idx].text : ""
            }
        }
    }

    Item {
        anchors.fill: parent

        // LEFT: Workspaces + Volume
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Workspace dots
            Rectangle {
                implicitWidth: wsRow.width + 24
                implicitHeight: 36
                radius: 18
                color: Qt.rgba(0.06, 0.06, 0.06, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 7

                    Repeater {
                        model: [1, 2, 3, 4, 5, 6, 7, 8]
                        Item {
                            width: (activeWorkspace === modelData) ? 22 : (occupiedWorkspaces.includes(modelData) ? 8 : 6)
                            height: 8
                            Behavior on width {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: (activeWorkspace === modelData) ? "white" : (occupiedWorkspaces.includes(modelData)) ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.15)
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }
                        }
                    }
                }
            }

            // Volume
            Rectangle {
                implicitWidth: volRow.width + 18
                implicitHeight: 36
                radius: 18
                color: Qt.rgba(0.06, 0.06, 0.06, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Row {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: isMuted ? "󰝟" : "󰕾"
                        color: isMuted ? "#ff5555" : Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 12
                        font.family: "Symbols Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text: volumePercent
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 11
                        font.family: "JetBrains Mono"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Lyrics pill — toggled by clicking the music icon
            Rectangle {
                id: lyricsPill
                implicitHeight: 36
                implicitWidth: lyricsOpen ? 290 : 0
                radius: 18
                color: Qt.rgba(0.06, 0.06, 0.06, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                clip: true

                Behavior on implicitWidth {
                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                }

                Text {
                    id: lyricsDisplay
                    anchors.centerIn: parent
                    text: root.lyricsCurrentLine
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 10
                    font.italic: true
                    font.family: "JetBrains Mono"
                    width: 266
                    elide: Text.ElideRight
                    opacity: root.lyricsCurrentLine !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }

        // CENTER: Clock + Date
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            height: 36
            radius: 18
            color: Qt.rgba(0.06, 0.06, 0.06, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1

            Rectangle {
                id: separatorDot
                width: 3
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.2)
                anchors.centerIn: parent
            }

            Text {
                id: timeText
                anchors.right: separatorDot.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(), "HH:mm:ss")
                color: Qt.rgba(1, 1, 1, 0.85)
                font.pixelSize: 15
                font.bold: true
                font.family: "JetBrains Mono"
            }

            Text {
                id: dateText
                anchors.left: separatorDot.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(new Date(), "ddd, MMM dd")
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 11
                font.family: "JetBrains Mono"
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    timeText.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
                    dateText.text = Qt.formatDateTime(new Date(), "ddd, MMM dd")
                }
            }
        }

        // RIGHT: Quote + Apps
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Marquee quote
            Rectangle {
                implicitWidth: 180
                implicitHeight: 36
                radius: 18
                color: Qt.rgba(0.06, 0.06, 0.06, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                clip: true

                Text {
                    id: quoteText
                    text: root.currentQuote
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 10
                    font.italic: true
                    font.family: "JetBrains Mono"
                    anchors.verticalCenter: parent.verticalCenter

                    NumberAnimation on x {
                        from: 180
                        to: -quoteText.implicitWidth
                        duration: 7000
                        loops: Animation.Infinite
                        running: true
                    }
                }
            }

            // Apps pill
            Rectangle {
                id: appPill
                implicitHeight: 36
                radius: 18
                color: Qt.rgba(0.06, 0.06, 0.06, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                clip: true
                implicitWidth: appRow.width + 24

                Behavior on implicitWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                Row {
                    id: appRow
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: "󰙯"
                        color: "#5865F2"
                        font.pixelSize: 16
                        font.family: "Symbols Nerd Font"
                        opacity: discordRunning ? 0.9 : 0
                        width: discordRunning ? 16 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Text {
                        text: "󰓇"
                        color: "#1DB954"
                        font.pixelSize: 16
                        font.family: "Symbols Nerd Font"
                        opacity: musicRunning ? 0.9 : 0
                        width: musicRunning ? 16 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        TapHandler {
                            onTapped: if (root.musicRunning) root.lyricsOpen = !root.lyricsOpen
                        }
                    }
                    Text {
                        text: "󰨞"
                        color: "#007ACC"
                        font.pixelSize: 16
                        font.family: "Symbols Nerd Font"
                        opacity: codeRunning ? 0.9 : 0
                        width: codeRunning ? 16 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Text {
                        text: "󰊤"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 16
                        font.family: "Symbols Nerd Font"
                        opacity: githubRunning ? 0.9 : 0
                        width: githubRunning ? 16 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Text {
                        text: "󰓓"
                        color: "#66c0f4"
                        font.pixelSize: 16
                        font.family: "Symbols Nerd Font"
                        opacity: steamRunning ? 0.9 : 0
                        width: steamRunning ? 16 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "file:///var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/org.vinegarhq.Sober.svg"
                        width: soberRunning ? 16 : 0
                        height: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: soberRunning ? 0.9 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                    Text {
                        text: "󰖩"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 14
                        font.family: "Symbols Nerd Font"
                    }
                }
            }
        }
    }
}