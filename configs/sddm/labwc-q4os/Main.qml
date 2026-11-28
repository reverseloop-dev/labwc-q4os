// =============================================================================
//  SDDM theme "Labwc Q4OS" - login moderno, colorato, futuristico
//  Progetto: https://github.com/reverseloop-dev/labwc-q4os
// =============================================================================
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080

    property color bgColor: config.background || "#050b18"
    property color surfaceColor: config.surface || "#0f172a"
    property color surfaceAlt: config.surface_alt || "#1e293b"
    property color accent: config.accent || "#3b82f6"
    property color accentSoft: config.accent_soft || "#60a5fa"
    property color violet: config.violet || "#8b5cf6"
    property color cyan: config.cyan || "#22d3ee"
    property color textColor: config.text || "#e2e8f0"
    property color muted: config.muted || "#94a3b8"
    property color borderColor: config.border || "#334155"
    property color danger: config.danger || "#f87171"
    property string keyboardLayout: config.keyboard || "IT"
    property var itLocale: Qt.locale("it_IT")

    color: bgColor

    // ---------------------------------------------------------------------
    // Sfondo: gradiente + aurora animata + griglia di punti
    // ---------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#050b18" }
            GradientStop { position: 0.55; color: "#0b1224" }
            GradientStop { position: 1.0; color: "#11132a" }
        }
    }

    // Logo reverseloop-dev "tono su tono" (logo-pattern.png dal tema corrente).
    // Pattern del logo reverseloop-dev "tono su tono": logo-pattern.png
    // generato da generate-login-logo.py (un logo grande, centrato, 2 cm dai bordi).
    Image {
        id: brandLogo
        source: "logo-pattern.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
    }

    Rectangle {
        width: root.width * 0.70
        height: width
        radius: width / 2
        x: root.width * -0.18
        y: root.height * -0.30
        color: accent
        opacity: 0.20
        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * -0.08; duration: 14000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * -0.18; duration: 14000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * -0.18; duration: 18000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * -0.30; duration: 18000; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        width: root.width * 0.58
        height: width
        radius: width / 2
        x: root.width * 0.62
        y: root.height * 0.34
        color: violet
        opacity: 0.17
        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.50; duration: 16000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.62; duration: 16000; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.22; duration: 20000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.34; duration: 20000; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        width: root.width * 0.42
        height: width
        radius: width / 2
        x: root.width * 0.40
        y: root.height * 0.72
        color: cyan
        opacity: 0.11
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.58; duration: 12000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.72; duration: 12000; easing.type: Easing.InOutSine }
        }
    }

    // Anelli decorativi
    Rectangle {
        width: 760; height: 760; radius: 380
        x: root.width * 0.72; y: -260
        color: "transparent"
        border.width: 1
        border.color: "#3b82f640"
        rotation: 12
    }
    Rectangle {
        width: 980; height: 980; radius: 490
        x: root.width * 0.66; y: -330
        color: "transparent"
        border.width: 1
        border.color: "#8b5cf62e"
        rotation: -8
    }

    // Griglia di punti disegnata su canvas: leggera e a schermo intero
    Canvas {
        anchors.fill: parent
        opacity: 0.55
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#94a3b826"
            var step = 34
            for (var x = 18; x < width; x += step) {
                for (var y = 18; y < height; y += step) {
                    ctx.beginPath()
                    ctx.arc(x, y, 1.1, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }

    // ---------------------------------------------------------------------
    // Intestazione
    // ---------------------------------------------------------------------
    RowLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 54
        spacing: 14

        Rectangle {
            width: 46; height: 46; radius: 14
            color: accent
            Text {
                anchors.centerIn: parent
                text: "L"
                color: bgColor
                font.family: "Inter"
                font.pixelSize: 24
                font.bold: true
            }
        }
        ColumnLayout {
            spacing: 1
            Text {
                text: "LABWC · Q4OS"
                color: textColor
                font.family: "Inter"
                font.pixelSize: 20
                font.bold: true
                font.letterSpacing: 2
            }
            Text {
                text: "reverseloop-dev  ·  Wayland desktop"
                color: muted
                font.family: "Inter"
                font.pixelSize: 12
            }
        }
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 54
        spacing: 0

        Text {
            id: clock
            text: itLocale.toString(new Date(), "HH:mm")
            color: textColor
            font.family: "Inter"
            font.pixelSize: 36
            font.bold: true
            Layout.alignment: Qt.AlignRight
        }
        Text {
            id: date
            text: itLocale.toString(new Date(), "dddd d MMMM")
            color: muted
            font.family: "Inter"
            font.pixelSize: 13
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

    // ---------------------------------------------------------------------
    // Card di login
    // ---------------------------------------------------------------------
    Rectangle {
        id: card
        width: 470
        height: 590
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 18
        radius: 30
        color: "#0f172aE8"
        border.width: 1
        border.color: "#60a5fa70"

        Rectangle {
            width: parent.width - 2
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
            anchors.fill: parent
            anchors.margins: 34
            spacing: 12

            Text {
                text: "Bentornato"
                color: textColor
                font.family: "Inter"
                font.pixelSize: 30
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Accedi alla sessione Labwc"
                color: muted
                font.family: "Inter"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
            }

            Text {
                text: "UTENTE"
                color: muted
                font.family: "Inter"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
                Layout.topMargin: 4
            }
            ComboBox {
                id: userCombo
                model: userModel
                textRole: "name"
                currentIndex: userModel.lastIndex
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                font.family: "Inter"
                font.pixelSize: 14

                background: Rectangle {
                    color: surfaceAlt
                    radius: 12
                    border.width: 1
                    border.color: userCombo.activeFocus ? accent : borderColor
                }
                contentItem: Text {
                    leftPadding: 14
                    text: userCombo.displayText
                    color: textColor
                    font: userCombo.font
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    width: userCombo.width
                    contentItem: Text {
                        text: model.name
                        color: textColor
                        font.family: "Inter"
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: highlighted ? accent : surfaceAlt
                    }
                    highlighted: userCombo.highlightedIndex === index
                }
            }

            Text {
                text: "PASSWORD"
                color: muted
                font.family: "Inter"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
                Layout.topMargin: 4
            }
            TextField {
                id: password
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                placeholderText: "Inserisci la password"
                echoMode: TextInput.Password
                selectByMouse: true
                font.family: "Inter"
                font.pixelSize: 14
                focus: true
                color: textColor
                placeholderTextColor: muted
                leftPadding: 14
                background: Rectangle {
                    color: surfaceAlt
                    radius: 12
                    border.width: 1
                    border.color: password.activeFocus ? accent : borderColor
                }
                onAccepted: root.login()
            }

            Text {
                text: "SESSIONE"
                color: muted
                font.family: "Inter"
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1.5
                Layout.topMargin: 4
            }
            ComboBox {
                id: sessionCombo
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                font.family: "Inter"
                font.pixelSize: 13

                background: Rectangle {
                    color: surfaceAlt
                    radius: 12
                    border.width: 1
                    border.color: borderColor
                }
                contentItem: Text {
                    leftPadding: 14
                    text: sessionCombo.displayText
                    color: textColor
                    font: sessionCombo.font
                    verticalAlignment: Text.AlignVCenter
                }
                delegate: ItemDelegate {
                    width: sessionCombo.width
                    contentItem: Text {
                        text: model.name
                        color: textColor
                        font.family: "Inter"
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: highlighted ? accent : surfaceAlt
                    }
                    highlighted: sessionCombo.highlightedIndex === index
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 3
                Text {
                    text: "Tastiera: " + keyboardLayout + "  ·  cambia con localectl"
                    color: muted
                    font.family: "Inter"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: cyan
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.topMargin: 4
                radius: 12
                color: loginArea.containsMouse ? accentSoft : accent
                border.width: 1
                border.color: accentSoft

                Text {
                    anchors.centerIn: parent
                    text: "Accedi"
                    color: bgColor
                    font.family: "Inter"
                    font.pixelSize: 15
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
                text: ""
                color: danger
                font.family: "Inter"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }

    // ---------------------------------------------------------------------
    // Footer e alimentazione
    // ---------------------------------------------------------------------
    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 14

        Repeater {
            model: [
                { "label": "Spegni", "action": "powerOff" },
                { "label": "Riavvia", "action": "reboot" },
                { "label": "Sospendi", "action": "suspend" }
            ]
            Rectangle {
                width: 94; height: 34; radius: 17
                color: powerArea.containsMouse ? "#1e293b" : "transparent"
                border.width: 1
                border.color: borderColor
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: muted
                    font.family: "Inter"
                    font.pixelSize: 11
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
        anchors.bottomMargin: 8
        text: "labwc-q4os · login moderno · reverseloop-dev"
        color: "#94a3b866"
        font.family: "Inter"
        font.pixelSize: 10
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
        if (userModel.count > 0) {
            userCombo.currentIndex = userModel.lastIndex >= 0 ? userModel.lastIndex : 0
        }
        if (sessionModel.count > 0) {
            sessionCombo.currentIndex = sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
        }
        password.forceActiveFocus()
    }
}
