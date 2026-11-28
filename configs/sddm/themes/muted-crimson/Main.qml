// =============================================================================
//  SDDM theme "Labwc Q4OS — Split Studio" (muted-crimson)
//  Pannello brand a tutta altezza a sinistra, form squadrato a destra.
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

    property color bgColor: col(config.background, "#120b0d")
    property color surfaceColor: col(config.surface, "#261c1e")
    property color surfaceAlt: col(config.surface_alt, "#332528")
    property color accent: col(config.accent, "#c0565b")
    property color accentSoft: col(config.accent_soft, "#d98a8e")
    property color violet: col(config.violet, "#b07a7d")
    property color cyan: col(config.cyan, "#d9a3a3")
    property color textColor: col(config.text, "#f1e6e6")
    property color muted: col(config.muted, "#b39a9c")
    property color borderColor: col(config.border, "#4a3336")
    property color danger: col(config.danger, "#e57373")
    property string keyboardLayout: config.keyboard || "IT"
    property var itLocale: Qt.locale("it_IT")

    // Scala unica: 0.8 a 1280x720, 1.0 a 1920x1080, 2.0 a 4K
    property real s: Math.max(0.8, Math.min(Math.min(root.width / 1920, root.height / 1080), 2.0))

    color: bgColor

    // Logo reverseloop-dev "tono su tono" (logo-pattern.png dal tema corrente).
    // Pattern del logo reverseloop-dev "tono su tono": logo-pattern.png
    // generato da generate-login-logo.py (quattro copie, dimensioni e
    // posizioni diverse, mai sovrapposte).
    Image {
        id: brandLogo
        source: "logo-pattern.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
    }

    // ---------------------------------------------------------------------
    // Area destra: tono leggermente più chiaro + trama diagonale sottile
    // ---------------------------------------------------------------------
    Rectangle {
        anchors.left: brandPanel.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Qt.rgba(surfaceAlt.r, surfaceAlt.g, surfaceAlt.b, 0.22)
    }

    Canvas {
        anchors.left: brandPanel.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        opacity: 0.5
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = Qt.rgba(borderColor.r, borderColor.g, borderColor.b, 0.55)
            ctx.lineWidth = 1
            var step = Math.max(20, 28 * s)
            for (var x = -height; x < width; x += step) {
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x + height, height)
                ctx.stroke()
            }
        }
    }

    // ---------------------------------------------------------------------
    // Pannello brand a sinistra (34% della larghezza)
    // ---------------------------------------------------------------------
    Rectangle {
        id: brandPanel
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(root.width * 0.34, 260 * s)
        color: surfaceColor
        clip: true

        // Linea accento verticale sul bordo destro del pannello
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(2, 3 * s)
            gradient: Gradient {
                GradientStop { position: 0.0; color: accentSoft }
                GradientStop { position: 0.5; color: accent }
                GradientStop { position: 1.0; color: Qt.rgba(violet.r, violet.g, violet.b, 0.15) }
            }
        }

        // Grande lettera "L" decorativa, parzialmente fuori dal pannello
        Text {
            text: "L"
            x: -brandPanel.width * 0.18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -brandPanel.width * 0.22
            color: Qt.rgba(accent.r, accent.g, accent.b, 0.10)
            font.family: "Inter"
            font.pixelSize: brandPanel.width * 1.05
            font.bold: true
        }

        RowLayout {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 40 * s
            spacing: 12 * s

            Rectangle {
                width: 40 * s; height: 40 * s
                radius: Math.min(10 * s, 10)
                color: accent
                Text {
                    anchors.centerIn: parent
                    text: "L"
                    color: bgColor
                    font.family: "Inter"
                    font.pixelSize: 20 * s
                    font.bold: true
                }
            }
            ColumnLayout {
                spacing: 1 * s
                Text {
                    text: "LABWC · Q4OS"
                    color: textColor
                    font.family: "Inter"
                    font.pixelSize: 17 * s
                    font.bold: true
                    font.letterSpacing: 2
                }
                Text {
                    text: "Wayland desktop"
                    color: muted
                    font.family: "Inter"
                    font.pixelSize: 11 * s
                }
            }
        }

        // Orologio enorme e data, centro del pannello
        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 40 * s
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -root.height * 0.04
            spacing: 6 * s

            Text {
                id: clock
                text: itLocale.toString(new Date(), "HH:mm")
                color: textColor
                font.family: "Inter"
                font.pixelSize: Math.min(brandPanel.width * 0.235, root.height * 0.155)
                font.bold: true
                font.letterSpacing: -2
            }
            Text {
                id: date
                text: itLocale.toString(new Date(), "dddd d MMMM")
                color: muted
                font.family: "Inter"
                font.pixelSize: 15 * s
            }
            Rectangle {
                width: 64 * s
                height: Math.max(2, 3 * s)
                color: accent
                Layout.topMargin: 10 * s
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

        // Tastiera e alimentazione in fondo al pannello
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 40 * s
            spacing: 14 * s

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36 * s
                radius: Math.min(8 * s, 10)
                color: Qt.rgba(surfaceAlt.r, surfaceAlt.g, surfaceAlt.b, 0.6)
                border.width: 1
                border.color: borderColor
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12 * s
                    anchors.rightMargin: 12 * s
                    spacing: 8 * s
                    Text {
                        text: "TASTIERA"
                        color: muted
                        font.family: "Inter"
                        font.pixelSize: 10 * s
                        font.bold: true
                        font.letterSpacing: 1.5
                    }
                    Text {
                        text: keyboardLayout
                        color: accentSoft
                        font.family: "Inter"
                        font.pixelSize: 12 * s
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * s
                Repeater {
                    model: [
                        { "label": "Spegni", "action": "powerOff" },
                        { "label": "Riavvia", "action": "reboot" },
                        { "label": "Sospendi", "action": "suspend" }
                    ]
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36 * s
                        radius: Math.min(8 * s, 10)
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
        }
    }

    // ---------------------------------------------------------------------
    // Form di login a destra, allineato a destra, angoli vivi (radius <= 10)
    // ---------------------------------------------------------------------
    ColumnLayout {
        id: loginForm
        width: Math.min(root.width * 0.34, 520 * s)
        anchors.right: parent.right
        anchors.rightMargin: Math.max(root.width * 0.06, 40 * s)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 13 * s

        Text {
            text: "Bentornato"
            color: textColor
            font.family: "Inter"
            font.pixelSize: 34 * s
            font.bold: true
        }
        Text {
            text: "Accedi alla sessione Labwc"
            color: muted
            font.family: "Inter"
            font.pixelSize: 14 * s
            Layout.bottomMargin: 10 * s
        }

        Text {
            text: "UTENTE"
            color: muted
            font.family: "Inter"
            font.pixelSize: 10 * s
            font.bold: true
            font.letterSpacing: 1.5
        }
        ComboBox {
            id: userCombo
            model: userModel
            textRole: "name"
            currentIndex: userModel.lastIndex
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * s
            font.family: "Inter"
            font.pixelSize: 14 * s

            background: Rectangle {
                color: surfaceAlt
                radius: Math.min(8 * s, 10)
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
                height: 42 * s
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
                    radius: Math.min(6 * s, 8)
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
                    radius: Math.min(8 * s, 10)
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
        }
        TextField {
            id: password
            Layout.fillWidth: true
            Layout.preferredHeight: 50 * s
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
                radius: Math.min(8 * s, 10)
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
        }
        ComboBox {
            id: sessionCombo
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * s
            font.family: "Inter"
            font.pixelSize: 13 * s

            background: Rectangle {
                color: surfaceAlt
                radius: Math.min(8 * s, 10)
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
                height: 42 * s
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
                    radius: Math.min(6 * s, 8)
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
                    radius: Math.min(8 * s, 10)
                    border.width: 1
                    border.color: borderColor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52 * s
            Layout.topMargin: 8 * s
            radius: Math.min(8 * s, 10)
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
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.Wrap
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22 * s
        text: "reverseloop-dev"
        opacity: 0.38
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