// =============================================================================
//  SDDM theme "Labwc Q4OS — Bottom Dock" (sage-emerald)
//  Alto libero con brand e orologio, login in un dock orizzontale in basso.
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

    property color bgColor: col(config.background, "#08110f")
    property color surfaceColor: col(config.surface, "#1b2624")
    property color surfaceAlt: col(config.surface_alt, "#24332f")
    property color accent: col(config.accent, "#4d9375")
    property color accentSoft: col(config.accent_soft, "#6fbf9a")
    property color violet: col(config.violet, "#5f8f86")
    property color cyan: col(config.cyan, "#8fd4b4")
    property color textColor: col(config.text, "#e3ece7")
    property color muted: col(config.muted, "#9db3a8")
    property color borderColor: col(config.border, "#33473f")
    property color danger: col(config.danger, "#e07a6a")
    property string keyboardLayout: config.keyboard || "IT"
    property var itLocale: Qt.locale("it_IT")

    // Scala unica: 0.8 a 1280x720, 1.0 a 1920x1080, 2.0 a 4K
    property real s: Math.max(0.8, Math.min(Math.min(root.width / 1920, root.height / 1080), 2.0))
    // Su schermi stretti i campi del dock passano da riga a colonna
    property bool wide: root.width >= 960

    color: bgColor

    // ---------------------------------------------------------------------
    // Sfondo: gradiente tenue + bagliore radiale morbido (nessuna card centrale)
    // ---------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.tint(bgColor, Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.55)) }
            GradientStop { position: 1.0; color: bgColor }
        }
    }

    // Logo reverseloop-dev "tono su tono" (logo.png dal tema corrente).
    // Pattern del logo reverseloop-dev "tono su tono": logo-pattern.png
    // generato da generate-login-logo.py (piu' copie, dimensioni e
    // trasparenze diverse, mai sovrapposte).
    Image {
        id: brandLogo
        source: "logo-pattern.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
    }

    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var r1 = Math.max(width, height) * 0.55
            var g1 = ctx.createRadialGradient(width * 0.5, height * 0.40, 0, width * 0.5, height * 0.40, r1)
            g1.addColorStop(0.0, Qt.rgba(accent.r, accent.g, accent.b, 0.20))
            g1.addColorStop(0.55, Qt.rgba(violet.r, violet.g, violet.b, 0.07))
            g1.addColorStop(1.0, Qt.rgba(accent.r, accent.g, accent.b, 0.0))
            ctx.fillStyle = g1
            ctx.fillRect(0, 0, width, height)
            var r2 = width * 0.5
            var g2 = ctx.createRadialGradient(width * 0.5, height * 1.02, 0, width * 0.5, height * 1.02, r2)
            g2.addColorStop(0.0, Qt.rgba(cyan.r, cyan.g, cyan.b, 0.10))
            g2.addColorStop(1.0, Qt.rgba(cyan.r, cyan.g, cyan.b, 0.0))
            ctx.fillStyle = g2
            ctx.fillRect(0, 0, width, height)
        }
    }

    // ---------------------------------------------------------------------
    // Brand piccolo e orologio, centrati in alto; il resto dello spazio è vuoto
    // ---------------------------------------------------------------------
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 44 * s
        spacing: 10 * s

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10 * s
            Rectangle {
                width: 34 * s; height: 34 * s; radius: 10 * s
                color: accent
                Text {
                    anchors.centerIn: parent
                    text: "L"
                    color: bgColor
                    font.family: "Inter"
                    font.pixelSize: 17 * s
                    font.bold: true
                }
            }
            Text {
                text: "LABWC · Q4OS"
                color: textColor
                font.family: "Inter"
                font.pixelSize: 16 * s
                font.bold: true
                font.letterSpacing: 2
            }
        }

        Text {
            id: clock
            text: itLocale.toString(new Date(), "HH:mm")
            color: textColor
            font.family: "Inter"
            font.pixelSize: 54 * s
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
        Text {
            id: date
            text: itLocale.toString(new Date(), "dddd d MMMM")
            color: muted
            font.family: "Inter"
            font.pixelSize: 13 * s
            Layout.alignment: Qt.AlignHCenter
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
    // Dock di login in basso: riga su schermi larghi, colonna su quelli stretti
    // ---------------------------------------------------------------------
    Rectangle {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30 * s
        width: root.wide ? Math.min(root.width - 80 * s, 1240 * s)
                         : Math.min(root.width - 48 * s, 560 * s)
        height: dockCol.implicitHeight + 36 * s
        radius: 22 * s
        color: Qt.rgba(surfaceColor.r, surfaceColor.g, surfaceColor.b, 0.95)
        border.width: 1
        border.color: borderColor

        Rectangle {
            width: parent.width * 0.6
            height: 2
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: accentSoft }
                GradientStop { position: 0.65; color: cyan }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        ColumnLayout {
            id: dockCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18 * s
            spacing: 12 * s

            // I campi sono figli diretti della griglia: l'ordine visivo è
            // sempre Utente, Password, Sessione, Accedi (niente reparenting)
            GridLayout {
                id: dockGrid
                Layout.fillWidth: true
                columns: root.wide ? 4 : 1
                flow: GridLayout.LeftToRight
                columnSpacing: 12 * s
                rowSpacing: 10 * s

                ComboBox {
                    id: userCombo
                    model: userModel
                    textRole: "name"
                    currentIndex: userModel.lastIndex
                    Layout.fillWidth: true
                    Layout.preferredWidth: 240 * s
                    Layout.preferredHeight: 48 * s
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

                TextField {
                    id: password
                    Layout.fillWidth: true
                    Layout.preferredWidth: 260 * s
                    Layout.preferredHeight: 48 * s
                    placeholderText: "Password"
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

                ComboBox {
                    id: sessionCombo
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    Layout.fillWidth: true
                    Layout.preferredWidth: 200 * s
                    Layout.preferredHeight: 48 * s
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

                Rectangle {
                    id: loginBtn
                    Layout.fillWidth: !root.wide
                    Layout.preferredWidth: 140 * s
                    Layout.preferredHeight: 48 * s
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
            }

            // Barra inferiore del dock: tastiera, errore, alimentazione
            RowLayout {
                Layout.fillWidth: true
                spacing: 12 * s

                Text {
                    text: "Tastiera " + keyboardLayout
                    color: muted
                    font.family: "Inter"
                    font.pixelSize: 11 * s
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    id: errorText
                    text: ""
                    color: danger
                    font.family: "Inter"
                    font.pixelSize: 12 * s
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14 * s
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
                Repeater {
                    model: [
                        { "label": "Spegni", "action": "powerOff" },
                        { "label": "Riavvia", "action": "reboot" },
                        { "label": "Sospendi", "action": "suspend" }
                    ]
                    Rectangle {
                        width: 84 * s; height: 30 * s; radius: 15 * s
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

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16 * s
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