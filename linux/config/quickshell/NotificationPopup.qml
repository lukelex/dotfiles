import Quickshell
import QtQuick
import QtQml

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service

  property int wiggleMargin: 6
  property var popupStacks: null

  anchor.window: panel
  anchor.rect.x: parentWindow.width - width - 12 + wiggleMargin
  anchor.rect.y: parentWindow.height + 12
  color: "transparent"
  implicitWidth: 396 + wiggleMargin * 2
  implicitHeight: column.height
  surfaceFormat.opaque: false

  visible: service.popup.length > 0 && !controller.notificationCenterOpen

  ListModel {
    id: popupGroupModel

    dynamicRoles: true
  }

  function addPopupRecord(record) {
    const lastStack = popup.popupStacks ? popup.popupStacks.itemAt(popup.popupStacks.count - 1) : null
    if (lastStack && lastStack.canAddRecord(record)) {
      lastStack.addRecord(record)
      return
    }

    popupGroupModel.append({ popupGroup: { records: [record] } })
  }

  function removePopupRecord(id) {
    if (!popup.popupStacks)
      return

    for (let index = 0; index < popup.popupStacks.count; index++) {
      const stack = popup.popupStacks.itemAt(index)
      if (stack && stack.expireRecord(id))
        return
    }
  }

  function removeStack(stack) {
    for (let index = 0; popup.popupStacks && index < popup.popupStacks.count; index++) {
      if (popup.popupStacks.itemAt(index) === stack) {
        popupGroupModel.remove(index)
        return
      }
    }
  }

  Component.onCompleted: {
    for (const group of service.popupGroups)
      popupGroupModel.append({ popupGroup: group })
  }

  Connections {
    target: popup.service

    function onPopupRecordAdded(record) {
      popup.addPopupRecord(record)
    }

    function onPopupRecordRemoved(id) {
      popup.removePopupRecord(id)
    }
  }

  component NotificationToast: Item {
    id: toast

    required property var controller
    required property var record
    required property var service

    property string countLabel: ""
    property real bellAngle: 0
    property bool dismissing: false
    property bool interactive: true
    property bool animateReflow: false
    property bool urgentAttention: false
    property var dismissHandler: null
    property real reflowOffset: 0
    property bool enterFromRight: false

    readonly property var icon: service.iconFor(toast.record)

    transform: [
      Translate {
        id: dismissTranslate
      },
      Translate {
        id: entryTranslate
      },
      Translate {
        y: toast.reflowOffset
      }
    ]
    width: parent.width

    Behavior on y {
      enabled: toast.animateReflow

      YAnimator {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    function activate() {
      if (toast.dismissing)
        return
      toast.dismissing = true
      toast.service.activateRecord(toast.record.id)
      dismissAnimation.start()
    }

    ParallelAnimation {
      id: dismissAnimation

      NumberAnimation {
        target: dismissTranslate
        property: "x"
        to: popup.width
        duration: 240
        easing.type: Easing.InCubic
      }
      OpacityAnimator {
        target: toast
        to: 0
        duration: 180
        easing.type: Easing.InQuad
      }
      onStopped: {
        if (toast.dismissHandler)
          toast.dismissHandler(toast.record.id, toast.height)
        else
          toast.service.dismissRecord(toast.record.id)
      }
    }

    NumberAnimation {
      id: reflowAnimation

      target: toast
      property: "reflowOffset"
      to: 0
      duration: 180
      easing.type: Easing.OutCubic
    }

    function moveDown(distance) {
      toast.reflowOffset = -distance
      reflowAnimation.start()
    }

    function playEntry() {
      entryTranslate.x = popup.width
      entryAnimation.restart()
    }

    Component.onCompleted: {
      if (toast.enterFromRight)
        toast.playEntry()
    }

    NumberAnimation {
      id: entryAnimation

      target: entryTranslate
      property: "x"
      to: 0
      duration: 280
      easing.type: Easing.OutCubic
    }

    Rectangle {
      id: background

      anchors.fill: parent
      border.color: toast.controller.darkMode ? "#3A4654" : "#D4DAE1"
      border.width: 1
      color: toast.controller.controlSurface
      radius: 18
    }

    Rectangle {
      id: urgentBreath

      anchors.fill: parent
      color: Qt.rgba(toast.controller.urgent.r, toast.controller.urgent.g, toast.controller.urgent.b, toast.urgentAttention ? 0.22 : 0.12)
      opacity: 0.18
      radius: 18
      visible: toast.record.urgency === "critical" || toast.urgentAttention

      SequentialAnimation {
        loops: Animation.Infinite
        running: urgentBreath.visible

        NumberAnimation {
          target: urgentBreath
          property: "opacity"
          from: 0.18
          to: toast.urgentAttention ? 0.95 : 0.85
          duration: 1100
          easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 150 }
        NumberAnimation {
          target: urgentBreath
          property: "opacity"
          from: toast.urgentAttention ? 0.95 : 0.85
          to: 0.18
          duration: 1100
          easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 450 }
      }
    }

    Rectangle {
      anchors {
        left: parent.left
        leftMargin: 12
        top: parent.top
        topMargin: 12
      }
      color: toast.record.urgency === "critical" ? toast.controller.urgent : toast.controller.controlActive
      height: 40
      radius: 12
      width: 40

      Image {
        anchors.fill: parent
        anchors.margins: 8
        fillMode: Image.PreserveAspectFit
        source: toast.icon.kind === "image" ? toast.icon.source : ""
        visible: toast.icon.kind === "image"
      }

      LucideIcon {
        id: notificationIcon

        anchors.centerIn: parent
        color: toast.controller.controlPrimaryText
        height: 20
        source: toast.icon.kind === "lucide" ? toast.controller.icon(toast.icon.source) : ""
        visible: toast.icon.kind === "lucide"
        width: 20

        transform: Rotation {
          id: bellRotation

          angle: toast.icon.kind === "lucide" && toast.icon.source === "bell" ? toast.bellAngle : 0
          origin.x: notificationIcon.width / 2
          origin.y: 0
        }
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
        height: 12
        spacing: 4
        width: parent.width

        Text {
          color: toast.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: toast.controller.fontFamily
          font.pixelSize: 10
          text: toast.record.appName
          width: parent.width - timeLabel.width - countLabelText.width - parent.spacing * 2
        }

        Text {
          id: countLabelText

          color: toast.controller.urgent
          font.family: toast.controller.fontFamily
          font.pixelSize: 10
          text: toast.countLabel
          visible: toast.countLabel.length > 0
          width: visible ? implicitWidth : 0
        }

        Text {
          id: timeLabel

          color: toast.controller.controlSecondaryText
          font.family: toast.controller.fontFamily
          font.pixelSize: 10
          text: service.timeAgo(toast.record)
        }
      }

      Text {
        color: toast.controller.controlPrimaryText
        elide: Text.ElideRight
        font.family: toast.controller.fontFamily
        font.pixelSize: 12
        text: toast.record.summary
        width: parent.width
      }

      Text {
        color: toast.controller.controlSecondaryText
        elide: Text.ElideRight
        font.family: toast.controller.fontFamily
        font.pixelSize: 11
        maximumLineCount: 2
        text: toast.record.body
        visible: toast.record.body.length > 0
        width: parent.width
        wrapMode: Text.Wrap
      }

      Rectangle {
        color: toast.controller.controlSliderFill
        height: 4
        radius: 2
        visible: toast.record.value >= 0
        width: parent.width * Math.min(1, Math.max(0, toast.record.value / 100))
      }

      Row {
        height: 26
        spacing: 8
        visible: toast.record.actions.length > 0
        width: parent.width

        Repeater {
          model: toast.record.actions

          delegate: Item {
            required property var modelData
            required property int index

            height: 26
            width: buttonLabel.implicitWidth + 20

            Rectangle {
              anchors.fill: parent
              color: toast.controller.controlBackground
              radius: 8
            }

            Text {
              id: buttonLabel

              anchors.centerIn: parent
              color: toast.controller.controlPrimaryText
              font.family: toast.controller.fontFamily
              font.pixelSize: 11
              text: modelData.text
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: service.invokeAction(toast.record.id, index)
            }
          }
        }
      }
    }

    height: Math.max(textColumn.height + 24, 64)

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      enabled: toast.interactive
      hoverEnabled: true
      onClicked: toast.activate()
      onEntered: service.setHovered(toast.record.id, true)
      onExited: service.setHovered(toast.record.id, false)
      z: -1
    }
  }

  component PopupStack: Item {
    id: stack

    required property var controller
    required property var popupGroup
    required property var service

    property var records: popupGroup.records
    property var removeHandler: null
    readonly property int layerCount: Math.min(records.length - 1, 2)
    readonly property var latestRecord: records[records.length - 1]
    readonly property bool grouped: records.length > 1
    readonly property bool showingExpanded: expanded && records.length > 0
    readonly property bool hasCritical: records.some(record => record.urgency === "critical")
    property real bellAngle: 0
    property bool expanded: false
    property bool expiring: false
    property real expandedHeight: 0
    property bool reflowing: false

    ListModel {
      id: recordModel

      dynamicRoles: true
    }

    transform: [
      Translate {
        id: entryTranslate
      },
      Translate {
        id: stackTranslate
      },
      Translate {
        id: expiryTranslate
      }
    ]
    clip: !reflowing
    height: records.length === 0 ? 0 : (showingExpanded ? expandedHeight : latestToast.height + layerCount * 6)
    visible: records.length > 0
    width: parent.width

    Behavior on height {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Behavior on y {
      YAnimator {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    Component.onCompleted: {
      for (const record of stack.records.slice().reverse())
        recordModel.append({ notification: record })
      entryAnimation.start()
    }

    NumberAnimation {
      id: entryAnimation

      target: entryTranslate
      property: "x"
      from: popup.width
      to: 0
      duration: 280
      easing.type: Easing.OutCubic
    }

    ParallelAnimation {
      id: expiryAnimation

      NumberAnimation { target: expiryTranslate; property: "x"; to: popup.width; duration: 240; easing.type: Easing.InCubic }
      OpacityAnimator { target: stack; to: 0; duration: 180; easing.type: Easing.InQuad }
      onStopped: {
        if (stack.expiring && stack.removeHandler)
          stack.removeHandler(stack)
      }
    }

    SequentialAnimation {
      loops: Animation.Infinite
      running: stack.hasCritical

      PauseAnimation { duration: 1800 }
      ParallelAnimation {
        NumberAnimation { target: stackTranslate; property: "x"; to: 5; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: stack; property: "bellAngle"; to: -12; duration: 70; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        NumberAnimation { target: stackTranslate; property: "x"; to: -5; duration: 110; easing.type: Easing.InOutSine }
        NumberAnimation { target: stack; property: "bellAngle"; to: 10; duration: 110; easing.type: Easing.InOutSine }
      }
      ParallelAnimation {
        NumberAnimation { target: stackTranslate; property: "x"; to: 3; duration: 90; easing.type: Easing.InOutSine }
        NumberAnimation { target: stack; property: "bellAngle"; to: -6; duration: 90; easing.type: Easing.InOutSine }
      }
      ParallelAnimation {
        NumberAnimation { target: stackTranslate; property: "x"; to: 0; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: stack; property: "bellAngle"; to: 0; duration: 100; easing.type: Easing.OutQuad }
      }

      onStopped: {
        stackTranslate.x = 0
        stack.bellAngle = 0
      }
    }

    Timer {
      id: collapseTimer

      interval: 250
      onTriggered: {
        stack.expanded = false
        stack.expandedHeight = 0
      }
    }

    Timer {
      id: reflowTimer

      interval: 180
      onTriggered: stack.reflowing = false
    }

    HoverHandler {
      enabled: stack.grouped || stack.expanded
      onHoveredChanged: {
        if (hovered) {
          collapseTimer.stop()
          if (!stack.expanded)
            stack.expandedHeight = expandedColumn.contentHeight
          stack.expanded = true
          stack.service.setRecordsHovered(stack.records, true)
        } else {
          stack.service.setRecordsHovered(stack.records, false)
          collapseTimer.restart()
        }
      }
    }

    Repeater {
      model: stack.layerCount

      delegate: Rectangle {
        required property int index

        border.color: stack.controller.darkMode ? "#3A4654" : "#D4DAE1"
        border.width: 1
        color: stack.controller.controlSurface
        height: latestToast.height
        radius: 18
        visible: !stack.expanded
        width: stack.width
        y: index * 6
      }
    }

    NotificationToast {
      id: latestToast

      controller: stack.controller
      bellAngle: stack.bellAngle
      countLabel: stack.records.length > 1 ? "+" + (stack.records.length - 1) : ""
      interactive: !stack.showingExpanded
      record: stack.latestRecord
      service: stack.service
      urgentAttention: stack.hasCritical
      visible: !stack.showingExpanded
      y: stack.layerCount * 6
      z: 3
    }

    Item {
      id: expandedColumn

      property real spacing: 8
      property real contentHeight: {
        let height = 0
        for (let index = 0; index < expandedCards.count; index++) {
          const card = expandedCards.itemAt(index)
          if (card)
            height += card.height
        }
        return height + Math.max(0, expandedCards.count - 1) * expandedColumn.spacing
      }

      function cardY(index, cardHeight) {
        let y = expandedColumn.height - cardHeight
        for (let previousIndex = 0; previousIndex < index; previousIndex++) {
          const previousCard = expandedCards.itemAt(previousIndex)
          if (previousCard)
            y -= previousCard.height + expandedColumn.spacing
        }
        return y
      }

      height: stack.showingExpanded ? stack.expandedHeight : contentHeight
      visible: stack.showingExpanded
      width: parent.width
      z: 4

      Repeater {
        id: expandedCards

        model: recordModel

        delegate: NotificationToast {
          required property int index
          required property var notification

          controller: stack.controller
          bellAngle: stack.bellAngle
          enterFromRight: notification.entering === true
          interactive: stack.showingExpanded
          opacity: stack.showingExpanded ? 1 : 0
          dismissHandler: (id, height) => stack.dismissRecord(id, height)
          record: notification
          service: stack.service
          urgentAttention: notification.urgency === "critical"
          y: expandedColumn.cardY(index, height)

          Behavior on opacity {
            SequentialAnimation {
              PauseAnimation { duration: stack.expanded ? index * 70 : 0 }
              NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }

    function dismissRecord(id, removedHeight) {
      const index = stack.records.findIndex(record => record.id === id)
      if (index < 0)
        return
      const visualIndex = recordModel.count - index - 1
      const reflowDistance = removedHeight + expandedColumn.spacing
      stack.reflowing = true
      reflowTimer.restart()
      for (let cardIndex = visualIndex + 1; cardIndex < expandedCards.count; cardIndex++) {
        const card = expandedCards.itemAt(cardIndex)
        if (card)
          card.moveDown(reflowDistance)
      }
      stack.records = stack.records.filter(record => record.id !== id)
      recordModel.remove(visualIndex)
      stack.service.dismissRecord(id, true)
    }

    function canAddRecord(record) {
      const latestRecord = stack.records[stack.records.length - 1]
      return latestRecord
        && stack.service.appKey(record) === stack.service.appKey(latestRecord)
        && record.time - latestRecord.time <= stack.service.popupGroupWindow
    }

    function addRecord(record) {
      if (!stack.canAddRecord(record))
        return

      stack.records = stack.records.concat([record])
      record.entering = true
      recordModel.append({ notification: record })

      if (stack.showingExpanded) {
        Qt.callLater(() => {
          const card = expandedCards.itemAt(expandedCards.count - 1)
          if (card)
            stack.expandedHeight += card.height + expandedColumn.spacing
        })
      } else {
        Qt.callLater(() => latestToast.playEntry())
      }
    }

    function expireRecord(id) {
      const index = stack.records.findIndex(record => record.id === id)
      if (index < 0)
        return false

      const visualIndex = recordModel.count - index - 1
      const removedCard = expandedCards.itemAt(visualIndex)
      const removedHeight = removedCard ? removedCard.height : latestToast.height

      if (stack.records.length === 1) {
        stack.expiring = true
        expiryAnimation.start()
        return true
      }

      stack.records = stack.records.filter(record => record.id !== id)
      recordModel.remove(visualIndex)

      if (stack.showingExpanded) {
        const reflowDistance = removedHeight + expandedColumn.spacing
        for (let cardIndex = visualIndex + 1; cardIndex < expandedCards.count; cardIndex++) {
          const card = expandedCards.itemAt(cardIndex)
          if (card)
            card.moveDown(reflowDistance)
        }
        Qt.callLater(() => stack.expandedHeight = expandedColumn.contentHeight)
      }

      return true
    }

    Connections {
      target: stack.service

      function onPopupRecordAdded(record) {
        stack.addRecord(record)
      }
    }
  }

  Column {
    id: column

    anchors {
      horizontalCenter: parent.horizontalCenter
      top: parent.top
    }
    spacing: 10
    width: parent.width - popup.wiggleMargin * 2

    Component.onCompleted: popup.popupStacks = stackRepeater

    Repeater {
        id: stackRepeater

        model: popupGroupModel

        delegate: PopupStack {
          controller: popup.controller
          removeHandler: stack => popup.removeStack(stack)
          service: popup.service
        }
      }
  }
}
