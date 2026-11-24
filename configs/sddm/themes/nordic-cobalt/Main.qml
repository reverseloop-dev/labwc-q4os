// =============================================================================
//  SDDM theme "Labwc Q4OS — Aurora Card" (nordic-cobalt)
//  Card centrale in vetro, aurora animata, griglia di punti.
//  Progetto: https://github.com/reverseloop-dev/labwc-q4os
// =============================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1280
    height: 720
    // theme.conf salva i colori senza "#": normalizza prima di assegnare a QColor
    function col(value, fallback) {
        if (!value)
            return fallback
        var v = String(value)
        return v.charAt(0) === "#" ? v : "#" + v
    }
    // alone radiale morbido per le aurora (niente moduli grafici esterni)
    function paintBlob(ctx, w, h, c, alpha) {
        ctx.clearRect(0, 0, w, h)
        var g = ctx.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2)
        g.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, alpha))
        g.addColorStop(1.0, Qt.rgba(c.r, c.g, c.b, 0.0))
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
    }
    property color bgColor: col(config.background, "#050b18")
    property color surfaceColor: col(config.surface, "#0f172a")
    property color surfaceAlt: col(config.surface_alt, "#1e293b")
    property color accent: col(config.accent, "#3b82f6")
    property color accentSoft: col(config.accent_soft, "#60a5fa")
    property color violet: col(config.violet, "#8b5cf6")
    property color cyan: col(config.cyan, "#22d3ee")
    property color textColor: col(config.text, "#e2e8f0")
    property color muted: col(config.muted, "#94a3b8")
    property color borderColor: col(config.border, "#334155")
    property color danger: col(config.danger, "#f87171")
    property string keyboardLayout: config.keyboard || "IT"
    property var itLocale: Qt.locale("it_IT")
    // Scala unica: 0.8 a 1280x720, 1.0 a 1920x1080, 2.0 a 4K
    property real s: Math.max(0.8, Math.min(Math.min(root.width / 1920, root.height / 1080), 2.0))

    color: bgColor
    // Sfondo: gradiente + aurora morbida (canvas radiali) + griglia di punti
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: bgColor }
            GradientStop { position: 0.55; color: Qt.tint(bgColor, Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.65)) }
            GradientStop { position: 1.0; color: Qt.tint(bgColor, Qt.rgba(violet.r, violet.g, violet.b, 0.10)) }
        }
    }

    Canvas {
        id: auroraA
        width: root.width * 0.72
        height: width
        x: root.width * -0.16
        y: root.height * -0.28
        opacity: 0.85
        onPaint: paintBlob(getContext("2d"), width, height, accent, 0.30)
    }

    Canvas {
        id: auroraB
        width: root.width * 0.58
        height: width
        x: root.width * 0.62
        y: root.height * 0.34
        opacity: 0.75
        onPaint: paintBlob(getContext("2d"), width, height, violet, 0.26)
    }

    Canvas {
        id: auroraC
        width: root.width * 0.44
        height: width
        x: root.width * 0.38
        y: root.height * 0.70
        opacity: 0.65
        onPaint: paintBlob(getContext("2d"), width, height, cyan, 0.18)
    }
    // Anello decorativo, dimensione relativa allo schermo
    Rectangle {
        width: root.height * 0.72
        height: width
        radius: width / 2
        x: root.width * 0.70
        y: -root.height * 0.24
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
        rotation: 12
    }

    Canvas {
        anchors.fill: parent
        opacity: 0.6
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Qt.rgba(muted.r, muted.g, muted.b, 0.16)
            var step = Math.max(24, 34 * s)
            for (var x = step / 2; x < width; x += step) {
                for (var y = step / 2; y < height; y += step) {
                    ctx.beginPath()
                    ctx.arc(x, y, 1.1 * s, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
    // Brand in alto a sinistra, orologio in alto a destra
    RowLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 48 * s
        spacing: 14 * s

        Rectangle {
            width: 44 * s; height: 44 * s; radius: 14 * s
            color: accent
            Text {
                anchors.centerIn: parent
                text: "L"
                color: bgColor
                font.family: "Inter"
                font.pixelSize: 22 * s
                font.bold: true
            }
        }
        ColumnLayout {
            spacing: 1 * s
            Text {
                text: "LABWC · Q4OS"
                color: textColor
                font.family: "Inter"
                font.pixelSize: 19 * s
                font.bold: true
                font.letterSpacing: 2
            }
            Text {
                text: "reverseloop-dev  ·  Wayland desktop"
                color: muted
                font.family: "Inter"
                font.pixelSize: 11 * s
            }
        }
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 48 * s
        spacing: 0

        Text {
            id: clock
            text: itLocale.toString(new Date(), "HH:mm")
            color: textColor
            font.family: "Inter"
            font.pixelSize: 38 * s
            font.bold: true
            Layout.alignment: Qt.AlignRight
        }
        Text {
            id: date
            text: itLocale.toString(new Date(), "dddd d MMMM")
            color: muted
            font.family: "Inter"
            font.pixelSize: 13 * s
            Layout.alignment: Qt.AlignRight
        }
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                clock.text = itLocale.toString(new Date(), "HH:mm")
                date.text = itLocale.toString(new Date(), "dddd d MMMM")
            }
        }
    }
    // Card di login in vetro
    Rectangle {
        id: card
        width: 470 * s
        height: cardCol.implicitHeight + 68 * s
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 8 * s
        radius: 30 * s
        color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(accentSoft.r, accentSoft.g, accentSoft.b, 0.45)

        NumberAnimation on opacity {
            from: 0.0; to: 1.0
            duration: 600
            easing.type: Easing.OutCubic
        }
        Rectangle {
            width: parent.width * 0.72
            height: 2
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: accentSoft }
                GradientStop { position: 0.7; color: violet }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 34 * s
            spacing: 11 * s

            Text {
                text: "Bentornato"
                color: textColor
                font.family: "Inter"
                font.pixelSize: 29 * s
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Accedi alla sessione Labwc"
                color: muted
                font.family: "Inter"
                font.pixelSize: 13 * s
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 6 * s
            }
            Text {
                text: "UTENTE"
                color: muted
                font.family: "Inter"
                font.pixelSize: 10 * s
                font.bold: true
                font.letterSpacing: 1.5
                Layout.topMargin: 2 * s
            }
            ComboBox {
                id: userCombo
                model: userModel
                textRole: "name"
                currentIndex: userModel.lastIndex
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * s
                font.family: "Inter"
                font.pixelSize: 14 * s

                background: Rectangle {
                    color: surfaceAlt
                    radius: 12 * s
                    border.width: 1
                    border.color: userCombo.activeFocus ? accent : borderColor
                }
                contentItem: Text {
                    leftPadding: 14 * s
                    rightPadding: 34 * s
                    text: userCombo.displayText
                    color: textColor
                    font: userCombo.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: userCombo.width - width - 14 * s
                    y: (userCombo.height - height) / 2
                    text: "▾"
                    color: muted
                    font.pixelSize: 12 * s
                }
                delegate: ItemDelegate {
                    width: userCombo.width - 8 * s
                    height: 40 * s
                    contentItem: Text {
                        text: model.name
                        color: textColor
                        font.family: "Inter"
                        font.pixelSize: 14 * s
                        leftPadding: 12 * s
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: (highlighted || hovered) ? Qt.rgba(accent.r, accent.g, accent.b, 0.30) : "transparent"
                        radius: 8 * s
                    }
                    highlighted: userCombo.highlightedIndex === index
                }
                popup: Popup {
                    y: userCombo.height + 6 * s
                    width: userCombo.width
                    padding: 4 * s
                    implicitHeight: Math.min(contentItem.implicitHeight, root.height * 0.42) + 8 * s
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: userCombo.popup.visible ? userCombo.delegateModel : null
                        currentIndex: userCombo.highlightedIndex
                    }
                    background: Rectangle {
                        color: surfaceAlt
                        radius: 12 * s
                        border.width: 1
                        border.color: borderColor
                    }
                }
            }
            Text {
                text: "PASSWORD"
                color: muted
                font.family: "Inter"
                font.pixelSize: 10 * s
                font.bold: true
                font.letterSpacing: 1.5
                Layout.topMargin: 2 * s
            }
            TextField {
                id: password
                Layout.fillWidth: true
                Layout.preferredHeight: 46 * s
                placeholderText: "Inserisci la password"
                echoMode: TextInput.Password
                selectByMouse: true
                font.family: "Inter"
                font.pixelSize: 14 * s
                focus: true
                color: textColor
                placeholderTextColor: muted
                leftPadding: 14 * s
                background: Rectangle {
                    color: surfaceAlt
                    radius: 12 * s
                    border.width: 1
                    border.color: password.activeFocus ? accent : borderColor
                }
                onAccepted: root.login()
            }
            Text {
                text: "SESSIONE"
                color: muted
                font.family: "Inter"
                font.pixelSize: 10 * s
                font.bold: true
                font.letterSpacing: 1.5
                Layout.topMargin: 2 * s
            }
            ComboBox {
                id: sessionCombo
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                Layout.fillWidth: true
                Layout.preferredHeight: 44 * s
                font.family: "Inter"
                font.pixelSize: 13 * s

                background: Rectangle {
                    color: surfaceAlt
                    radius: 12 * s
                    border.width: 1
                    border.color: sessionCombo.activeFocus ? accent : borderColor
                }
                contentItem: Text {
                    leftPadding: 14 * s
                    rightPadding: 34 * s
                    text: sessionCombo.displayText
                    color: textColor
                    font: sessionCombo.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                indicator: Text {
                    x: sessionCombo.width - width - 14 * s
                    y: (sessionCombo.height - height) / 2
                    text: "▾"
                    color: muted
                    font.pixelSize: 12 * s
                }
                delegate: ItemDelegate {
                    width: sessionCombo.width - 8 * s
                    height: 40 * s
                    contentItem: Text {
                        text: model.name
                        color: textColor
                        font.family: "Inter"
                        font.pixelSize: 13 * s
                        leftPadding: 12 * s
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: (highlighted || hovered) ? Qt.rgba(accent.r, accent.g, accent.b, 0.30) : "transparent"
                        radius: 8 * s
                    }
                    highlighted: sessionCombo.highlightedIndex === index
                }
                popup: Popup {
                    y: sessionCombo.height + 6 * s
                    width: sessionCombo.width
                    padding: 4 * s
                    implicitHeight: Math.min(contentItem.implicitHeight, root.height * 0.42) + 8 * s
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: sessionCombo.popup.visible ? sessionCombo.delegateModel : null
                        currentIndex: sessionCombo.highlightedIndex
                    }
                    background: Rectangle {
                        color: surfaceAlt
                        radius: 12 * s
                        border.width: 1
                        border.color: borderColor
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2 * s
                Text {
                    text: "Tastiera: " + keyboardLayout + "  ·  cambia con localectl"
                    color: muted
                    font.family: "Inter"
                    font.pixelSize: 11 * s
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: 8 * s; height: 8 * s; radius: 4 * s
                    color: cyan
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48 * s
                Layout.topMargin: 4 * s
                radius: 12 * s
                color: loginArea.containsMouse ? accentSoft : accent
                border.width: 1
                border.color: accentSoft
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "Accedi"
                    color: bgColor
                    font.family: "Inter"
                    font.pixelSize: 15 * s
                    font.bold: true
                }
                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.login()
                }
            }
            Text {
                id: errorText
                Layout.fillWidth: true
                Layout.preferredHeight: 16 * s
                text: ""
                color: danger
                font.family: "Inter"
                font.pixelSize: 12 * s
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
    // Alimentazione in basso al centro
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 * s
        spacing: 12 * s

        Repeater {
            model: [
                { "label": "Spegni", "action": "powerOff" },
                { "label": "Riavvia", "action": "reboot" },
                { "label": "Sospendi", "action": "suspend" }
            ]
            Rectangle {
                width: 96 * s; height: 34 * s; radius: 17 * s
                color: powerArea.containsMouse ? surfaceAlt : "transparent"
                border.width: 1
                border.color: borderColor
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: powerArea.containsMouse ? textColor : muted
                    font.family: "Inter"
                    font.pixelSize: 11 * s
                }
                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "powerOff") sddm.powerOff()
                        else if (modelData.action === "reboot") sddm.reboot()
                        else if (modelData.action === "suspend") sddm.suspend()
                    }
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8 * s
        text: "labwc-q4os · login moderno"
        color: Qt.rgba(muted.r, muted.g, muted.b, 0.4)
        font.family: "Inter"
        font.pixelSize: 10 * s
    }
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18 * s
        text: "reverseloop-dev"
        opacity: 0.35
        color: muted
        font.family: "Inter"
        font.pixelSize: 10 * s
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            errorText.text = "Password errata o utente non valido"
            password.text = ""
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            errorText.text = ""
        }
    }
    function login() {
        if (password.text.length === 0) {
            errorText.text = "Inserisci la password"
            password.forceActiveFocus()
            return
        }
        errorText.text = ""
        var user = userCombo.currentText
        if (userModel.lastUser && user === "") {
            user = userModel.lastUser
        }
        sddm.login(user, password.text, sessionCombo.currentIndex)
    }

    Component.onCompleted: {
        if (userCombo.count > 0) {
            userCombo.currentIndex = userModel.lastIndex >= 0 ? userModel.lastIndex : 0
        }
        if (sessionCombo.count > 0) {
            // Preferisce la sessione Labwc; lastIndex è solo il ripiego
            var target = sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
            for (var i = 0; i < sessionCombo.count; i++) {
                if (sessionCombo.textAt(i).toLowerCase().indexOf("labwc") !== -1) {
                    target = i
                    break
                }
            }
            sessionCombo.currentIndex = target
        }
        password.forceActiveFocus()
    }
}