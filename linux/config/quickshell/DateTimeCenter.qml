pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Controls.Basic as Controls

Scope {
  id: popup

  required property var controller
  required property var panel
  required property var weather
  property bool pinned: false
  property bool closing: false
  property bool closeImmediately: false
  property bool promotionPending: false
  property var promotionSnapshot: null
  property var promotionWindow: null
  property int pinRequest: 0
  property bool detailsExpanded: false
  readonly property bool visible: preview.visible || pinnedPopup.visible
  readonly property date today: controller.currentDate
  property date displayedMonth: new Date(today.getFullYear(), today.getMonth(), 1, 12)
  readonly property bool currentMonth: displayedMonth.getFullYear() === today.getFullYear() && displayedMonth.getMonth() === today.getMonth()
  readonly property real width: Math.max(1, Math.min(584, (panel.screen ? panel.screen.width : panel.width) - 24))
  readonly property bool stacked: width < 520
  readonly property real availableHeight: Math.max(1, (panel.screen ? panel.screen.height : 768) - panel.height - 24)
  readonly property real height: Math.min(availableHeight, sections.implicitHeight + 32)

  function resetMonth() {
    popup.displayedMonth = new Date(popup.today.getFullYear(), popup.today.getMonth(), 1, 12)
  }

  function changeMonth(delta) {
    popup.requestOpen(true)
    popup.displayedMonth = new Date(popup.displayedMonth.getFullYear(), popup.displayedMonth.getMonth() + delta, 1, 12)
  }

  function goToday() {
    popup.requestOpen(true)
    popup.resetMonth()
  }

  function calendarDate(index) {
    const year = popup.displayedMonth.getFullYear()
    const month = popup.displayedMonth.getMonth()
    const offset = (new Date(year, month, 1, 12).getDay() + 6) % 7
    return new Date(year, month, index - offset + 1, 12)
  }

  function isToday(date) {
    return date.getFullYear() === popup.today.getFullYear() && date.getMonth() === popup.today.getMonth() && date.getDate() === popup.today.getDate()
  }

  function forecastDate(value) {
    // This date denotes the city's day, not a UTC instant. Parse at local noon.
    const parts = value.split("-")
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12)
  }

  function updatedText() {
    if (!popup.weather.updatedAt)
      return ""
    const minutes = Math.max(0, Math.floor((popup.today.getTime() / 1000 - popup.weather.updatedAt) / 60))
    return minutes < 1 ? "Updated just now" : minutes < 60 ? "Updated " + minutes + " min ago" : minutes < 1440 ? "Updated " + Math.floor(minutes / 60) + " h ago" : "Updated " + Math.floor(minutes / 1440) + " d ago"
  }

  function openPinned(request) {
    if (request !== popup.pinRequest)
      return
    if (popup.pinned && !popup.closing)
      pinnedPopup.open()
    popup.promotionPending = false
  }

  function requestOpen(pin = false) {
    if (!pin && popup.closing && popup.pinned)
      return
    const fresh = !popup.visible && !popup.pinned
    popup.cancelClose()
    closeAnim.stop()
    popup.closing = false
    popup.closeImmediately = false
    if (fresh) {
      popup.resetMonth()
      popup.detailsExpanded = false
      scroll.contentY = 0
      popup.weather.refresh()
    }
    if (pin || popup.pinned) {
      popup.pinned = true
      if (pinnedPopup.visible || popup.promotionPending)
        return
      popup.promotionPending = true
      const request = ++popup.pinRequest
      if (preview.visible) {
        const captured = content.grabToImage(result => {
          if (request !== popup.pinRequest || !popup.pinned || popup.closing)
            return
          popup.promotionSnapshot = result
        })
        if (!captured) {
          popup.promotionPending = false
          popup.pinned = false
        }
      } else {
        Qt.callLater(popup.openPinned, request)
      }
    } else {
      preview.visible = true
      if (content.opacity < 1 && !openAnim.running)
        openAnim.start()
    }
  }

  function requestClose(immediate = false) {
    popup.pinRequest++
    popup.promotionPending = false
    popup.promotionSnapshot = null
    popup.promotionWindow = null
    popup.closing = true
    popup.cancelClose()
    openAnim.stop()
    popup.closeImmediately = immediate
    if (pinnedPopup.visible)
      pinnedPopup.close()
    else
      popup.pinned = false
    if (immediate) {
      closeAnim.stop()
      preview.visible = false
    } else if (preview.visible && !closeAnim.running) {
      closeAnim.start()
    }
  }

  function scheduleClose() {
    if (!popup.pinned)
      closeTimer.restart()
  }

  function cancelClose() {
    closeTimer.stop()
  }

  onVisibleChanged: {
    if (!visible) {
      closeTimer.stop()
      openAnim.stop()
      closeAnim.stop()
      content.opacity = 0
      content.y = 10
    }
  }

  PopupWindow {
    id: preview
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, (popup.panel.width - popup.width) / 2)
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: false

    Image {
      anchors.fill: parent
      source: popup.promotionSnapshot ? popup.promotionSnapshot.url : ""
      visible: popup.promotionSnapshot !== null
      z: 1
      onStatusChanged: {
        if (status === Image.Ready)
          Qt.callLater(popup.openPinned, popup.pinRequest)
      }
    }
  }

  Connections {
    target: popup.promotionWindow
    function onFrameSwapped() {
      if (pinnedPopup.visible && popup.promotionSnapshot) {
        preview.visible = false
        popup.promotionSnapshot = null
        popup.promotionWindow = null
      }
    }
  }

  PopupWindow {
    id: pinnedPopup
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, (popup.panel.width - popup.width) / 2)
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: true

    function open() {
      pinnedPopup.visible = true
      // The preview snapshot bridges the first pinned frame.
      if (popup.promotionSnapshot) {
        popup.promotionWindow = content.nativeWindow
        preview.contentItem.Window.window.raise()
      }
      content.forceActiveFocus()
      if (content.opacity < 1 && !openAnim.running)
        openAnim.start()
    }

    function close() {
      pinnedPopup.visible = false
      popup.pinned = false
      preview.visible = false
      popup.promotionSnapshot = null
      popup.promotionWindow = null
    }
  }

  Timer {
    id: closeTimer
    interval: 600
    onTriggered: {
      if (!popup.pinned)
        popup.requestClose()
    }
  }

  ParallelAnimation {
    id: openAnim
    NumberAnimation {
      target: content
      property: "opacity"
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: content
      property: "y"
      to: 0
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  ParallelAnimation {
    id: closeAnim
    NumberAnimation {
      target: content
      property: "opacity"
      to: 0
      duration: 120
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: content
      property: "y"
      to: 6
      duration: 120
      easing.type: Easing.InCubic
    }
    onFinished: preview.visible = false
  }

  component Label: Text {
    color: popup.controller.controlSecondaryText
    font.family: popup.controller.fontFamily
    font.pixelSize: 11
    textFormat: Text.PlainText
    elide: Text.ElideRight
  }

  component Action: Controls.AbstractButton {
    id: action
    property string iconName: ""
    implicitWidth: iconName ? 32 : Math.max(56, actionLabel.implicitWidth + 16)
    implicitHeight: 32
    opacity: enabled ? 1 : 0.55
    hoverEnabled: true
    focusPolicy: popup.pinned ? Qt.StrongFocus : Qt.NoFocus
    Accessible.name: text
    background: Rectangle {
      radius: 8
      color: action.hovered || action.down ? popup.controller.controlSurface : "transparent"
      border.width: action.visualFocus ? 1 : 0
      border.color: popup.controller.controlActiveIcon
    }
    contentItem: Item {
      Label {
        id: actionLabel
        anchors.centerIn: parent
        visible: !action.iconName
        text: action.text
        color: popup.controller.controlPrimaryText
      }
      LucideIcon {
        anchors.centerIn: parent
        width: 16
        height: 16
        visible: action.iconName !== ""
        source: action.iconName ? popup.controller.icon(action.iconName) : ""
        color: popup.controller.controlSecondaryText
      }
    }
    Controls.ToolTip {
      parent: action
      x: action.width - implicitWidth
      y: -implicitHeight - 6
      visible: action.hovered && action.iconName !== ""
      delay: 600
      padding: 8
      contentItem: Label {
        text: action.text
        color: popup.controller.controlPrimaryText
      }
      background: Rectangle {
        color: popup.controller.controlSurface
        border.color: popup.controller.controlSecondaryText
        radius: 7
      }
    }
  }

  FocusScope {
    id: content
    readonly property var nativeWindow: Window.window
    parent: pinnedPopup.visible ? pinnedPopup.contentItem : preview.contentItem
    width: popup.width
    height: popup.height
    opacity: 0
    y: 10
    focus: popup.pinned
    Keys.onEscapePressed: popup.requestClose()
    Keys.onLeftPressed: function (event) {
      event.accepted = popup.pinned
      if (popup.pinned)
        popup.changeMonth(-1)
    }
    Keys.onRightPressed: function (event) {
      event.accepted = popup.pinned
      if (popup.pinned)
        popup.changeMonth(1)
    }

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          popup.cancelClose()
        else
          popup.scheduleClose()
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: 26
      color: popup.controller.controlBackground
      border.width: 1
      border.color: popup.controller.darkMode ? "#3A424E" : "#D8DDE4"
    }

    Flickable {
      id: scroll
      x: 16
      y: 16
      width: Math.max(1, parent.width - 32)
      height: Math.max(1, parent.height - 32)
      contentWidth: width
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      Controls.ScrollBar.vertical: Controls.ScrollBar {
        policy: Controls.ScrollBar.AsNeeded
      }

      Column {
        id: sections
        width: scroll.width - (scroll.contentHeight > scroll.height ? 12 : 0)
        spacing: 16

        Row {
          width: parent.width
          height: 36
          spacing: 8
          Column {
            width: parent.width - 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Label {
              width: parent.width
              text: Qt.formatDate(popup.today, "dddd") + " / " + Qt.formatTime(popup.today, "HH:mm")
            }
            Label {
              width: parent.width
              text: Qt.formatDate(popup.today, "d MMMM yyyy")
              font.pixelSize: 15
              color: popup.controller.controlPrimaryText
            }
          }
          Action {
            text: "Close"
            iconName: "x"
            onClicked: popup.requestClose()
          }
        }

        Rectangle {
          width: parent.width
          height: columns.implicitHeight + 24
          color: popup.controller.controlSurface
          radius: 18

          Grid {
            id: columns
            x: 12
            y: 12
            width: parent.width - 24
            columns: popup.stacked ? 1 : 2
            columnSpacing: 20
            rowSpacing: 20

            Column {
              id: calendar
              width: popup.stacked ? columns.width : (columns.width - columns.columnSpacing) * 0.57
              spacing: 10

              Row {
                width: parent.width
                spacing: 4
                Label {
                  width: parent.width - 72
                  anchors.verticalCenter: parent.verticalCenter
                  text: Qt.formatDate(popup.displayedMonth, "MMMM yyyy")
                  color: popup.controller.controlPrimaryText
                  font.pixelSize: 14
                }
                Action {
                  text: "Previous month"
                  iconName: "chevron-left"
                  onClicked: popup.changeMonth(-1)
                }
                Action {
                  text: "Next month"
                  iconName: "chevron-right"
                  onClicked: popup.changeMonth(1)
                }
              }

              Row {
                width: parent.width
                Repeater {
                  model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                  delegate: Label {
                    required property string modelData
                    width: calendar.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 10
                    text: modelData
                  }
                }
              }

              Grid {
                width: parent.width
                columns: 7
                rowSpacing: 4
                Repeater {
                  model: 42
                  delegate: Item {
                    id: dayCell
                    required property int index
                    readonly property date date: popup.calendarDate(index)
                    readonly property bool today: popup.isToday(date)
                    readonly property bool inMonth: date.getMonth() === popup.displayedMonth.getMonth()
                    width: calendar.width / 7
                    height: 30
                    Rectangle {
                      anchors.centerIn: parent
                      width: Math.min(30, parent.width)
                      height: 30
                      radius: 15
                      color: dayCell.today ? popup.controller.controlActive : "transparent"
                    }
                    Label {
                      anchors.centerIn: parent
                      text: dayCell.date.getDate()
                      font.pixelSize: 12
                      font.bold: dayCell.today
                      opacity: dayCell.inMonth || dayCell.today ? 1 : 0.5
                      color: dayCell.today || dayCell.inMonth ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
                    }
                  }
                }
              }

              Item {
                width: parent.width
                height: 32
                Action {
                  anchors.right: parent.right
                  visible: !popup.currentMonth
                  text: "Today"
                  onClicked: popup.goToday()
                }
              }
            }

            Column {
              id: weatherColumn
              width: popup.stacked ? columns.width : columns.width - calendar.width - columns.columnSpacing
              spacing: 8

              Label {
                text: "Weather"
                font.pixelSize: 12
              }

              Column {
                width: parent.width
                spacing: 7
                visible: popup.weather.available
                Row {
                  width: parent.width
                  spacing: 10
                  LucideIcon {
                    width: 30
                    height: 30
                    source: popup.controller.icon(popup.weather.conditionIcon)
                    color: popup.controller.controlActiveIcon
                  }
                  Label {
                    width: parent.width - 40
                    text: Math.round(popup.weather.temperature) + "\u00b0C"
                    font.pixelSize: 24
                    color: popup.controller.controlPrimaryText
                  }
                }
                Label {
                  width: parent.width
                  text: [popup.weather.city, popup.weather.country].filter(value => value !== "").join(", ")
                  color: popup.controller.controlPrimaryText
                  wrapMode: Text.Wrap
                  elide: Text.ElideNone
                }
                Label {
                  width: parent.width
                  text: popup.weather.description
                  wrapMode: Text.Wrap
                  elide: Text.ElideNone
                }
                Label {
                  width: parent.width
                  text: "Feels like " + Math.round(popup.weather.feelsLike) + "\u00b0C"
                }
              }

              Column {
                width: parent.width
                spacing: 4
                visible: popup.weather.available && popup.weather.forecast.length > 0
                Label {
                  text: "Forecast / low - high"
                  font.pixelSize: 10
                }
                Repeater {
                  model: popup.weather.available ? popup.weather.forecast.slice(0, 3) : []
                  delegate: Row {
                    id: forecastRow
                    required property var modelData
                    width: weatherColumn.width
                    height: 28
                    spacing: 8
                    Accessible.role: Accessible.StaticText
                    Accessible.name: Qt.formatDate(popup.forecastDate(modelData.date), "dddd") + ", " + modelData.condition + ", low " + modelData.low + ", high " + modelData.high
                    Label {
                      width: 32
                      anchors.verticalCenter: parent.verticalCenter
                      text: Qt.formatDate(popup.forecastDate(forecastRow.modelData.date), "ddd")
                    }
                    LucideIcon {
                      width: 18
                      height: 18
                      anchors.verticalCenter: parent.verticalCenter
                      source: popup.controller.icon(forecastRow.modelData.icon)
                      color: popup.controller.controlSecondaryText
                    }
                    Label {
                      width: parent.width - 66
                      anchors.verticalCenter: parent.verticalCenter
                      horizontalAlignment: Text.AlignRight
                      text: Math.round(forecastRow.modelData.low) + "\u00b0 / " + Math.round(forecastRow.modelData.high) + "\u00b0"
                      color: popup.controller.controlPrimaryText
                    }
                  }
                }
              }

              Label {
                width: parent.width
                text: popup.weather.loading ? (popup.weather.available ? "Refreshing..." : "Loading weather...") : !popup.weather.available ? "No weather data" : popup.weather.stale ? "Stale weather data" : ""
                visible: text !== ""
                wrapMode: Text.Wrap
                elide: Text.ElideNone
              }
              Label {
                width: parent.width
                text: popup.updatedText()
                visible: text !== ""
              }
              Label {
                width: parent.width
                text: popup.weather.error
                visible: text !== ""
                color: popup.controller.urgent
                wrapMode: Text.Wrap
                elide: Text.ElideNone
              }
              Action {
                text: popup.weather.loading ? "Refreshing..." : popup.weather.retryAfter > 0 ? "Retry in " + popup.weather.retryAfter + "s" : "Retry"
                enabled: !popup.weather.loading && !(popup.weather.retryAfter > 0)
                visible: !popup.weather.available || popup.weather.stale || popup.weather.error !== ""
                onClicked: {
                  popup.requestOpen(true)
                  popup.weather.refresh(true)
                }
              }
              Action {
                text: popup.detailsExpanded ? "Hide details" : "Details"
                visible: popup.weather.available && (popup.weather.humidity !== null || popup.weather.wind !== null)
                onClicked: {
                  popup.requestOpen(true)
                  popup.detailsExpanded = !popup.detailsExpanded
                }
              }
              Column {
                width: parent.width
                spacing: 6
                visible: popup.weather.available && popup.detailsExpanded
                Label {
                  width: parent.width
                  visible: popup.weather.humidity !== null
                  text: "Humidity " + popup.weather.humidity + "%"
                }
                Label {
                  width: parent.width
                  visible: popup.weather.wind !== null
                  text: "Wind " + popup.weather.wind + " m/s"
                }
              }
            }
          }
        }
      }
    }
  }
}
