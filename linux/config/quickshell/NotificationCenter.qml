import Quickshell
import QtQuick
import QtQml

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service

  anchor.window: panel
  anchor.rect.x: parentWindow.width - width - 12
  anchor.rect.y: parentWindow.height + 12
  color: "transparent"
  grabFocus: true
  implicitHeight: 548
  implicitWidth: 432
  surfaceFormat.opaque: false

  component HeaderIconButton: Item {
    id: button

    required property string iconName
    property color idleColor: popup.controller.controlPrimaryText
    property color activeColor: popup.controller.urgent
    property bool active: false
    property bool destructive: false
    signal clicked

    height: 32
    width: 32

    Rectangle {
      anchors.fill: parent
      color: button.active
        ? Qt.rgba(button.activeColor.r, button.activeColor.g, button.activeColor.b, area.containsMouse ? 0.35 : 0.18)
        : (area.containsMouse
          ? (button.destructive
            ? Qt.rgba(button.activeColor.r, button.activeColor.g, button.activeColor.b, 0.25)
            : popup.controller.controlSurface)
          : "transparent")
      radius: 8
    }

    LucideIcon {
      anchors.centerIn: parent
      color: button.active || (button.destructive && area.containsMouse) ? button.activeColor : button.idleColor
      height: 16
      source: popup.controller.icon(button.iconName)
      width: 16
    }

    MouseArea {
      id: area

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: button.clicked()
    }
  }

  component NotificationCard: Item {
    id: card

    required property var controller
    required property var record
    required property var service

    readonly property bool isLive: Boolean(service.live[record.id])
    readonly property var icon: service.iconFor(card.record)
    readonly property real contentHeight: textColumn.height + 24

    property bool showTrash: false
    property bool dismissing: false
    property real bellAngle: 0
    property bool groupDismissing: false
    property int groupDismissDelay: 0
    property real groupDismissOffset: 0

    transform: [
      Translate {
        id: urgentTranslate
      },
      Translate {
        x: card.groupDismissOffset
      }
    ]
    width: parent.width
    height: card.contentHeight

    Behavior on y {
      enabled: !card.dismissing && !card.groupDismissing

      YAnimator {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    SequentialAnimation {
      id: urgentWiggle

      loops: Animation.Infinite
      running: card.isLive && card.record.urgency === "critical" && !card.dismissing

      PauseAnimation { duration: 1800 }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: 5; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "bellAngle"; to: -12; duration: 70; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: -5; duration: 110; easing.type: Easing.InOutSine }
        NumberAnimation { target: card; property: "bellAngle"; to: 10; duration: 110; easing.type: Easing.InOutSine }
      }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: 3; duration: 90; easing.type: Easing.InOutSine }
        NumberAnimation { target: card; property: "bellAngle"; to: -6; duration: 90; easing.type: Easing.InOutSine }
      }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: 0; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "bellAngle"; to: 0; duration: 100; easing.type: Easing.OutQuad }
      }

      onStopped: {
        urgentTranslate.x = 0
        card.bellAngle = 0
      }
    }

    // Red reveal layer shown while the card slides out on dismiss.
    Rectangle {
      id: deleteLayer

      anchors.fill: parent
      color: card.controller.urgent
      opacity: 0
      radius: 18

      LucideIcon {
        anchors {
          right: parent.right
          rightMargin: 18
          verticalCenter: parent.verticalCenter
        }
        color: card.controller.controlPrimaryText
        height: 22
        source: card.controller.icon("trash")
        width: 22
      }
    }

    // Declared first so the buttons inside the surface keep their clicks.
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onEntered: card.showTrash = true
      onExited: card.showTrash = false
      onClicked: card.activate()
    }

    Item {
      id: surface

      height: parent.height
      width: parent.width

      Rectangle {
        anchors.fill: parent
        border.color: card.controller.darkMode ? "#33404D" : "#D7DCE3"
        border.width: 1
        color: card.controller.controlSurface
        radius: 18
      }

      Rectangle {
        id: urgentBreath

        anchors.fill: parent
        color: Qt.rgba(card.controller.urgent.r, card.controller.urgent.g, card.controller.urgent.b, 0.12)
        opacity: 0.18
        radius: 18
        visible: card.isLive && card.record.urgency === "critical"

        SequentialAnimation {
          loops: Animation.Infinite
          running: urgentBreath.visible

          NumberAnimation {
            target: urgentBreath
            property: "opacity"
            from: 0.18
            to: 0.85
            duration: 1100
            easing.type: Easing.InOutSine
          }
          PauseAnimation { duration: 150 }
          NumberAnimation {
            target: urgentBreath
            property: "opacity"
            from: 0.85
            to: 0.18
            duration: 1100
            easing.type: Easing.InOutSine
          }
          PauseAnimation { duration: 450 }
        }
      }

      Column {
        id: textColumn

        anchors {
          left: parent.left
          leftMargin: 64
          right: parent.right
          rightMargin: 14
          top: parent.top
          topMargin: 12
        }
        spacing: 3

        Row {
          height: 22
          spacing: 6
          width: parent.width

          Text {
            color: card.controller.controlSecondaryText
            elide: Text.ElideRight
            font.family: card.controller.fontFamily
            font.pixelSize: 10
            text: card.record.appName
            width: parent.width - timeLabel.width - dismissButton.width - parent.spacing
          }

          Text {
            id: timeLabel

            anchors.verticalCenter: parent.verticalCenter
            color: card.controller.controlSecondaryText
            font.family: card.controller.fontFamily
            font.pixelSize: 10
            text: service.timeAgo(card.record)
          }

          Item {
            id: dismissButton

            anchors.verticalCenter: parent.verticalCenter
            height: 18
            opacity: card.showTrash || trashArea.containsMouse ? 1 : 0
            width: 18

            Behavior on opacity {
              NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(card.controller.urgent.r, card.controller.urgent.g, card.controller.urgent.b, 0.25)
              opacity: trashArea.containsMouse ? 1 : 0
              radius: 5

              Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
              }
            }

            LucideIcon {
              anchors.centerIn: parent
              color: trashArea.containsMouse ? card.controller.urgent : card.controller.controlSecondaryText
              height: 14
              source: card.controller.icon("trash")
              width: 14
            }

            MouseArea {
              id: trashArea

              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              hoverEnabled: true
              onEntered: card.showTrash = true
              onExited: card.showTrash = false
              onClicked: card.startDismiss()
            }
          }
        }

        Text {
          color: card.controller.controlPrimaryText
          elide: Text.ElideRight
          font.family: card.controller.fontFamily
          font.pixelSize: 12
          text: card.record.summary
          width: parent.width
        }

        Text {
          color: card.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: card.controller.fontFamily
          font.pixelSize: 11
          maximumLineCount: 2
          text: card.record.body
          visible: card.record.body.length > 0
          width: parent.width
          wrapMode: Text.Wrap
        }

        Row {
          height: 26
          spacing: 8
          visible: card.isLive && card.record.actions.length > 0
          width: parent.width

          Repeater {
            model: card.record.actions

            delegate: Item {
              required property var modelData
              required property int index

              height: 26
              width: buttonLabel.implicitWidth + 20

              Rectangle {
                anchors.fill: parent
                color: card.controller.controlBackground
                radius: 8
              }

              Text {
                id: buttonLabel

                anchors.centerIn: parent
                color: card.controller.controlPrimaryText
                font.family: card.controller.fontFamily
                font.pixelSize: 11
                text: modelData.text
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: service.invokeAction(card.record.id, index)
              }
            }
          }
        }
      }

      Rectangle {
        anchors {
          left: parent.left
          leftMargin: 12
          top: parent.top
          topMargin: 12
        }
        color: card.record.urgency === "critical" ? card.controller.urgent : card.controller.controlActive
        height: 40
        radius: 12
        width: 40

        Image {
          anchors.fill: parent
          anchors.margins: 8
          fillMode: Image.PreserveAspectFit
          source: card.icon.kind === "image" ? card.icon.source : ""
          visible: card.icon.kind === "image"
        }

        LucideIcon {
          id: notificationIcon

          anchors.centerIn: parent
          color: card.controller.controlPrimaryText
          height: 20
          source: card.icon.kind === "lucide" ? card.controller.icon(card.icon.source) : ""
          visible: card.icon.kind === "lucide"
          width: 20

          transform: Rotation {
            id: bellRotation

            angle: card.icon.kind === "lucide" && card.icon.source === "bell" ? card.bellAngle : 0
            origin.x: notificationIcon.width / 2
            origin.y: 0
          }
        }
      }
    }

    function startDismiss() {
      if (card.dismissing)
        return
      card.dismissing = true
      dismissAnim.start()
    }

    function activate() {
      if (card.dismissing)
        return
      card.service.activateRecord(card.record.id)
      card.service.dismissRecord(card.record.id)
    }

    onGroupDismissingChanged: {
      if (groupDismissing)
        groupDismissAnimation.start()
    }

    SequentialAnimation {
      id: groupDismissAnimation

      PauseAnimation { duration: Math.max(0, card.groupDismissDelay) }
      NumberAnimation {
        target: card
        property: "groupDismissOffset"
        to: card.width
        duration: 260
        easing.type: Easing.InCubic
      }
    }

    ParallelAnimation {
      id: dismissAnim

      XAnimator {
        target: surface
        to: -card.width
        duration: 260
        easing.type: Easing.OutCubic
      }
      OpacityAnimator {
        target: deleteLayer
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
      }
      onStopped: {
        if (card.dismissing)
          card.service.dismissRecord(card.record.id)
      }
    }
  }

  component NotificationGroup: Item {
    id: notificationGroup

    required property var controller
    required property var group
    required property var service

    property var records: group.records
    readonly property bool grouped: recordModel.count > 1
    readonly property var icon: recordModel.count > 0 ? service.iconFor(recordModel.get(0).notification) : ({ kind: "lucide", source: "bell" })
    readonly property bool expanded: popup.expandedGroupKey === group.key
    property bool dismissing: false
    property real headerDismissOffset: 0

    ListModel {
      id: recordModel

      dynamicRoles: true
    }

    clip: true
    height: grouped ? groupHeader.height + (expanded ? cardList.height + 8 : 0) : cardList.height
    width: parent.width

    Behavior on height {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: {
      for (const record of notificationGroup.records)
        recordModel.append({ notification: record })
    }

    Timer {
      id: groupDismissTimer

      interval: 320 + Math.max(0, recordModel.count - 1) * 70
      onTriggered: notificationGroup.service.dismissRecords(notificationGroup.recordsForDismissal())
    }

    NumberAnimation {
      id: headerDismissAnimation

      target: notificationGroup
      property: "headerDismissOffset"
      to: notificationGroup.width
      duration: 260
      easing.type: Easing.InCubic
    }

    Item {
      id: groupHeader

      enabled: !notificationGroup.dismissing
      height: 56
      transform: Translate { x: notificationGroup.headerDismissOffset }
      visible: notificationGroup.grouped
      width: parent.width

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notificationGroup.toggleExpanded()
        z: -1
      }

      Rectangle {
        anchors.fill: parent
        border.color: notificationGroup.controller.darkMode ? "#33404D" : "#D7DCE3"
        border.width: 1
        color: notificationGroup.controller.controlSurface
        radius: 16
      }

      Rectangle {
        anchors {
          left: parent.left
          leftMargin: 10
          verticalCenter: parent.verticalCenter
        }
        color: notificationGroup.controller.controlActive
        height: 36
        radius: 10
        width: 36

        Image {
          anchors.fill: parent
          anchors.margins: 7
          fillMode: Image.PreserveAspectFit
          source: notificationGroup.icon.kind === "image" ? notificationGroup.icon.source : ""
          visible: notificationGroup.icon.kind === "image"
        }

        LucideIcon {
          anchors.centerIn: parent
          color: notificationGroup.controller.controlPrimaryText
          height: 18
          source: notificationGroup.icon.kind === "lucide" ? notificationGroup.controller.icon(notificationGroup.icon.source) : ""
          visible: notificationGroup.icon.kind === "lucide"
          width: 18
        }
      }

      Column {
        anchors {
          left: parent.left
          leftMargin: 58
          right: clearGroupButton.left
          rightMargin: 10
          verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
          color: notificationGroup.controller.controlPrimaryText
          elide: Text.ElideRight
          font.family: notificationGroup.controller.fontFamily
          font.pixelSize: 12
          text: recordModel.count > 0 ? recordModel.get(0).notification.appName : ""
          width: parent.width
        }

        Text {
          color: notificationGroup.controller.controlSecondaryText
          font.family: notificationGroup.controller.fontFamily
          font.pixelSize: 10
          text: recordModel.count + " notifications"
        }
      }

      HeaderIconButton {
        id: clearGroupButton

        anchors {
          right: expandIcon.left
          rightMargin: 6
          verticalCenter: parent.verticalCenter
        }
        destructive: true
        iconName: "trash"
        onClicked: notificationGroup.dismissGroup()
      }

      LucideIcon {
        id: expandIcon

        anchors {
          right: parent.right
          rightMargin: 14
          verticalCenter: parent.verticalCenter
        }
        color: notificationGroup.controller.controlSecondaryText
        height: 16
        source: notificationGroup.controller.icon("chevrons-down-up")
        width: 16
      }
    }

    Column {
      id: cardList

      enabled: !notificationGroup.dismissing
      spacing: 10
      width: parent.width - 12
      x: notificationGroup.grouped ? 12 : 0
      y: notificationGroup.grouped ? groupHeader.height + 8 : 0

      Repeater {
        model: recordModel

        delegate: NotificationCard {
          required property int index
          required property var notification

          controller: notificationGroup.controller
          groupDismissing: notificationGroup.dismissing
          groupDismissDelay: 60 + Math.max(0, index) * 70
          groupDismissOffset: 0
          opacity: !notificationGroup.grouped || notificationGroup.expanded ? 1 : 0
          record: notification
          service: notificationGroup.service
          width: cardList.width

          Behavior on opacity {
            SequentialAnimation {
              PauseAnimation { duration: notificationGroup.expanded ? Math.max(0, index) * 70 : 0 }
              NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
          }

        }
      }
    }

    function dismissGroup() {
      if (notificationGroup.dismissing)
        return
      notificationGroup.dismissing = true
      headerDismissAnimation.start()
      groupDismissTimer.start()
    }

    function toggleExpanded() {
      if (!notificationGroup.grouped)
        return
      popup.expandedGroupKey = notificationGroup.expanded ? "" : notificationGroup.group.key
    }

    function recordsForDismissal() {
      const currentRecords = []
      for (let index = 0; index < recordModel.count; index++)
        currentRecords.push(recordModel.get(index).notification)
      return currentRecords
    }

    Connections {
      target: notificationGroup.service

      function onHistoryRecordDismissed(id) {
        for (let index = 0; index < recordModel.count; index++) {
          if (String(recordModel.get(index).notification.id) === String(id)) {
            recordModel.remove(index)
            return
          }
        }
      }
    }
  }

  property bool closePending: false
  property string expandedGroupKey: ""

  function requestOpen() {
    if (popup.visible && !closeAnim.running)
      return
    popup.visible = true
    popup.closePending = false
    content.opacity = 0
    content.y = 10
    openAnim.start()
  }

  function requestClose() {
    if (!popup.visible || closeAnim.running)
      return
    popup.closePending = true
    openAnim.stop()
    closeAnim.start()
  }

  // Soft rise + fade: content slides up into place on open and down on close.
  ParallelAnimation {
    id: openAnim
    OpacityAnimator {
      target: content
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
    YAnimator {
      target: content
      to: 0
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  ParallelAnimation {
    id: closeAnim
    OpacityAnimator {
      target: content
      to: 0
      duration: 120
      easing.type: Easing.InCubic
    }
    YAnimator {
      target: content
      to: 6
      duration: 120
      easing.type: Easing.InCubic
    }
    onStopped: {
      if (popup.closePending) {
        popup.closePending = false
        popup.visible = false
      }
    }
  }

  onVisibleChanged: {
    if (!popup.visible) {
      openAnim.stop()
      closeAnim.stop()
      popup.closePending = false
      popup.expandedGroupKey = ""
      content.opacity = 1
      content.y = 0
    }
  }

  Item {
    id: content

    width: parent.width
    height: parent.height

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          popup.controller.cancelHoverClose()
        else
          popup.controller.requestHoverClose(1)
      }
    }

    Rectangle {
      anchors.fill: parent
      border.color: popup.controller.darkMode ? "#3A424E" : "#D8DDE4"
      border.width: 1
      color: popup.controller.controlBackground
      radius: 26
    }

    Column {
      anchors {
        fill: parent
        margins: 16
      }
      spacing: 12

      Item {
        height: 32
        width: parent.width

        Text {
          id: titleText

          anchors.verticalCenter: parent.verticalCenter
          color: popup.controller.controlPrimaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 18
          text: "Notifications"
        }

        HeaderIconButton {
          id: dndButton

          active: popup.controller.doNotDisturb
          activeColor: popup.controller.urgent
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          iconName: "bell"
          onClicked: popup.controller.toggleDoNotDisturb()
        }

        HeaderIconButton {
          id: clearButton

          anchors {
            right: dndButton.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
          }
          iconName: "trash"
          onClicked: service.clearHistory()
          visible: service.history.length > 0
        }
      }

      Item {
        height: parent.height - 44
        width: parent.width

        Flickable {
          anchors.fill: parent
          clip: true
          contentHeight: notificationList.height
          contentWidth: width
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: notificationList

            spacing: 10
            width: parent.width

            Repeater {
              model: service.historyGroups

              delegate: NotificationGroup {
                required property var modelData

                controller: popup.controller
                group: modelData
                service: popup.service
                width: notificationList.width
              }
            }
          }
        }

        Column {
          anchors.centerIn: parent
          spacing: 8
          visible: service.history.length === 0

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            color: popup.controller.controlSurface
            height: 48
            radius: 24
            width: 48

            LucideIcon {
              anchors.centerIn: parent
              color: popup.controller.controlSecondaryText
              height: 22
              source: popup.controller.icon("bell")
              width: 22
            }
          }

          Text {
            color: popup.controller.controlPrimaryText
            font.family: popup.controller.fontFamily
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            width: 180
          }

          Text {
            color: popup.controller.controlSecondaryText
            font.family: popup.controller.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            text: "You are all caught up"
            width: 180
          }
        }
      }
    }
  }
}
